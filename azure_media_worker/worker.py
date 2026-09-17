import json
import logging
import os
import subprocess
import tempfile
import uuid
from pathlib import Path
from typing import Any

import firebase_admin
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.storage.queue import QueueClient
from firebase_admin import credentials, firestore

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

MAX_VIDEO_BYTES = 512 * 1024 * 1024
MAX_SOURCE_SECONDS = 15 * 60
MAX_OUTPUT_WIDTH = 720
MAX_TEXT_CHARS = 120
MAX_TEXT_LAYERS = 64
MAX_EFFECT_LAYERS = 32
QUEUE_VISIBILITY_SECONDS = 3600

STORAGE_ACCOUNT = os.environ.get('AZURE_STORAGE_ACCOUNT_NAME', '').strip()
CONTAINER = os.environ.get('AZURE_STORAGE_CONTAINER', 'ojas-media').strip()
STORAGE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_CONNECTION_STRING', '').strip()
QUEUE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_QUEUE_CONNECTION_STRING', '').strip()
QUEUE_NAME = os.environ.get('AZURE_STORAGE_PROCESSING_QUEUE', 'ojas-media-processing').strip().lower()
ENABLE_HLS = os.environ.get('OJAS_ENABLE_HLS', 'false').strip().lower() == 'true'
FONT_FILE = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'


def _firebase() -> firestore.Client:
    if not firebase_admin._apps:
        service_account = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON', '').strip()
        if service_account:
            firebase_admin.initialize_app(credentials.Certificate(json.loads(service_account)))
        else:
            firebase_admin.initialize_app()
    return firestore.client()


def _blob_service() -> BlobServiceClient:
    if STORAGE_CONNECTION_STRING:
        return BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
    if not STORAGE_ACCOUNT:
        raise RuntimeError('AZURE_STORAGE_ACCOUNT_NAME is required.')
    return BlobServiceClient(account_url=f'https://{STORAGE_ACCOUNT}.blob.core.windows.net', credential=DefaultAzureCredential())


def _queue() -> QueueClient:
    if not QUEUE_CONNECTION_STRING:
        raise RuntimeError('AZURE_STORAGE_QUEUE_CONNECTION_STRING is required.')
    return QueueClient.from_connection_string(QUEUE_CONNECTION_STRING, QUEUE_NAME)


def _safe_creation_path(path: str) -> bool:
    parts = path.split('/')
    return (
        len(parts) >= 4
        and parts[0] == 'creation'
        and all(part and part not in {'.', '..'} for part in parts[1:])
        and all(all(c.isalnum() or c in '_-' for c in part) for part in parts[1:3])
        and len(parts[3]) <= 512
    )


def _run(command: list[str]) -> None:
    logging.info('Running: %s', ' '.join(command))
    subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def _probe(source: str) -> dict[str, Any]:
    completed = subprocess.run(
        [
            'ffprobe', '-v', 'error', '-print_format', 'json',
            '-show_entries', 'format=duration,size:stream=index,codec_type,width,height,codec_name',
            source,
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    data = json.loads(completed.stdout or '{}')
    duration = float((data.get('format') or {}).get('duration') or 0.0)
    size = int(float((data.get('format') or {}).get('size') or 0.0))
    streams = data.get('streams') or []
    video_stream = next((stream for stream in streams if stream.get('codec_type') == 'video'), {})
    has_audio = any(stream.get('codec_type') == 'audio' for stream in streams)
    return {
        'durationMs': int(duration * 1000),
        'sizeBytes': size,
        'width': int(video_stream.get('width') or 0),
        'height': int(video_stream.get('height') or 0),
        'codec': str(video_stream.get('codec_name') or ''),
        'hasAudio': has_audio,
    }


def _upload_blob(service: BlobServiceClient, local_path: Path, storage_path: str, content_type: str) -> None:
    blob = service.get_blob_client(container=CONTAINER, blob=storage_path)
    with local_path.open('rb') as handle:
        blob.upload_blob(handle, overwrite=True, content_settings=ContentSettings(content_type=content_type))


def _mark_failed(db: firestore.Client, asset_id: str, project_id: str, message: str) -> None:
    update = {'processingStatus': 'failed', 'processingError': message[:1000], 'updatedAt': firestore.SERVER_TIMESTAMP}
    db.collection('creationMedia').document(asset_id).set(update, merge=True)
    db.collection('reels').document(project_id).set({'mediaProcessingStatus': 'failed', 'mediaProcessingError': message[:1000]}, merge=True)


def _claim(db: firestore.Client, asset_id: str, job_id: str) -> bool:
    ref = db.collection('creationMedia').document(asset_id)
    transaction = db.transaction()

    @firestore.transactional
    def apply_claim(txn: Any) -> bool:
        snapshot = ref.get(transaction=txn)
        if not snapshot.exists:
            return False
        data = snapshot.to_dict() or {}
        status = str(data.get('processingStatus', '')).lower()
        if status in {'ready', 'processing'}:
            return False
        txn.update(ref, {
            'processingStatus': 'processing',
            'processingJobId': job_id,
            'processingStartedAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })
        return True

    return apply_claim(transaction)


def _bounded_clip(clip: dict[str, Any], source_duration_ms: int) -> tuple[int, int, float, int]:
    trim_in = max(0, int(clip.get('trimInMs') or 0))
    trim_out_raw = clip.get('trimOutMs')
    trim_out = int(trim_out_raw) if isinstance(trim_out_raw, (int, float)) else source_duration_ms
    trim_in = min(trim_in, source_duration_ms - 1)
    trim_out = min(source_duration_ms, trim_out)
    if trim_out <= trim_in:
        raise ValueError('Edit graph contains an invalid trim range.')
    speed = float(clip.get('speed') or 1.0)
    if speed < 0.25 or speed > 4.0:
        raise ValueError('Edit graph contains an invalid speed value.')
    rotation = int(round(float(clip.get('rotation') or 0))) % 360
    nearest = min((0, 90, 180, 270), key=lambda angle: abs(angle - rotation))
    if abs(nearest - rotation) > 3:
        raise ValueError('Edit graph rotation must be close to a 90 degree increment.')
    return trim_in, trim_out, speed, nearest


def _atempo_chain(speed: float) -> str:
    filters: list[str] = []
    remaining = speed
    while remaining < 0.5:
        filters.append('atempo=0.5')
        remaining /= 0.5
    while remaining > 2.0:
        filters.append('atempo=2.0')
        remaining /= 2.0
    filters.append(f'atempo={remaining:.5f}')
    return ','.join(filters)


def _escape_drawtext_text(value: str) -> str:
    compact = ' '.join(value.replace('\n', ' ').split())[:MAX_TEXT_CHARS]
    return compact.replace('\\', '\\\\').replace(':', '\\:').replace("'", "\\'").replace('%', '\\%')


def _safe_layer_time(layer: dict[str, Any], duration_ms: int) -> tuple[float, float] | None:
    start_raw = layer.get('startMs', 0)
    end_raw = layer.get('endMs', duration_ms)
    if not isinstance(start_raw, (int, float)) or not isinstance(end_raw, (int, float)):
        return None
    start = max(0, min(duration_ms, int(start_raw)))
    end = max(start + 1, min(duration_ms, int(end_raw)))
    if end <= start:
        return None
    return start / 1000.0, end / 1000.0


def _effect_expression(effect: dict[str, Any]) -> str | None:
    effect_id = str(effect.get('effectId') or '').strip().lower()
    try:
        intensity = float(effect.get('intensity') or 1.0)
    except (TypeError, ValueError):
        intensity = 1.0
    intensity = max(0.0, min(1.0, intensity))
    if effect_id == 'mono':
        return f'hue=s={1.0 - intensity:.3f}'
    if effect_id == 'warm':
        return f'eq=saturation={1.0 + 0.15 * intensity:.3f}:gamma={1.0 + 0.04 * intensity:.3f}:brightness={0.025 * intensity:.3f}'
    if effect_id == 'cool':
        return f'hue=h={-10.0 * intensity:.3f}:s={1.0 + 0.05 * intensity:.3f}'
    if effect_id == 'vivid':
        return f'eq=contrast={1.0 + 0.10 * intensity:.3f}:saturation={1.0 + 0.25 * intensity:.3f}'
    return None


def _append_visual_layers(filter_parts: list[str], input_label: str, edit_graph: dict[str, Any], duration_ms: int) -> str:
    current = input_label
    effects = edit_graph.get('effectLayers')
    if isinstance(effects, list):
        for index, raw in enumerate(effects[:MAX_EFFECT_LAYERS]):
            if not isinstance(raw, dict):
                continue
            expression = _effect_expression(raw)
            if not expression:
                continue
            output_label = f'fx{index}'
            filter_parts.append(f'[{current}]{expression}[{output_label}]')
            current = output_label

    text_layers = edit_graph.get('textLayers')
    if isinstance(text_layers, list):
        for index, raw in enumerate(text_layers[:MAX_TEXT_LAYERS]):
            if not isinstance(raw, dict):
                continue
            text = str(raw.get('text') or '').strip()
            timing = _safe_layer_time(raw, duration_ms)
            if not text or timing is None:
                continue
            start, end = timing
            try:
                x = max(-0.4, min(1.4, float(raw.get('x') or 0.0)))
                y = max(-0.2, min(1.2, float(raw.get('y') or 0.0)))
                font_size = max(8, min(120, int(float(raw.get('fontSize') or 28))))
            except (TypeError, ValueError):
                continue
            output_label = f'txt{index}'
            escaped = _escape_drawtext_text(text)
            drawtext = (
                f"drawtext=fontfile='{FONT_FILE}':text='{escaped}':"
                f'fontcolor=white:fontsize={font_size}:borderw=2:bordercolor=black@0.85:'
                f'box=1:boxcolor=black@0.30:boxborderw=10:'
                f"x='(w-text_w)/2+({x:.4f}*w)':y='({y:.4f}*h)':"
                f"enable='between(t,{start:.3f},{end:.3f})'"
            )
            filter_parts.append(f'[{current}]{drawtext}[{output_label}]')
            current = output_label
    return current


def _render_edit_graph(source: str, output: str, metadata: dict[str, Any], edit_graph: dict[str, Any]) -> str:
    raw_timeline = edit_graph.get('timeline')
    if not isinstance(raw_timeline, list) or not raw_timeline:
        raw_timeline = [{'trimInMs': 0, 'trimOutMs': metadata['durationMs'], 'speed': 1.0, 'rotation': 0}]

    clips = [item for item in raw_timeline[:32] if isinstance(item, dict)]
    if not clips:
        clips = [{'trimInMs': 0, 'trimOutMs': metadata['durationMs'], 'speed': 1.0, 'rotation': 0}]

    filter_parts: list[str] = []
    concat_inputs: list[str] = []
    has_audio = bool(metadata.get('hasAudio'))
    rendered_duration_ms = 0

    for index, clip in enumerate(clips):
        trim_in, trim_out, speed, rotation = _bounded_clip(clip, metadata['durationMs'])
        rendered_duration_ms += round((trim_out - trim_in) / speed)
        video_label = f'v{index}'
        video_filters = [
            f'trim=start={trim_in / 1000:.3f}:end={trim_out / 1000:.3f}',
            'setpts=PTS-STARTPTS',
            f'setpts=PTS/{speed:.5f}',
        ]
        if rotation == 90:
            video_filters.append('transpose=1')
        elif rotation == 180:
            video_filters.extend(['hflip', 'vflip'])
        elif rotation == 270:
            video_filters.append('transpose=2')
        video_filters.append("scale='min(720,iw)':-2:force_original_aspect_ratio=decrease")
        video_filters.append('setsar=1')
        filter_parts.append(f'[0:v]{",".join(video_filters)}[{video_label}]')
        if has_audio:
            audio_label = f'a{index}'
            filter_parts.append(
                f'[0:a]atrim=start={trim_in / 1000:.3f}:end={trim_out / 1000:.3f},'
                f'asetpts=PTS-STARTPTS,{_atempo_chain(speed)}[{audio_label}]'
            )
            concat_inputs.append(f'[{video_label}][{audio_label}]')
        else:
            concat_inputs.append(f'[{video_label}]')

    if len(clips) == 1:
        filter_parts.append('[v0]null[preout]')
        final_video_input = 'preout'
        final_audio = 'a0' if has_audio else None
    else:
        if has_audio:
            filter_parts.append(''.join(concat_inputs) + f'concat=n={len(clips)}:v=1:a=1[basev][basea]')
            final_video_input = 'basev'
            final_audio = 'basea'
        else:
            filter_parts.append(''.join(concat_inputs) + f'concat=n={len(clips)}:v=1:a=0[basev]')
            final_video_input = 'basev'
            final_audio = None

    final_video = _append_visual_layers(filter_parts, final_video_input, edit_graph, rendered_duration_ms)

    command = [
        'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', source,
        '-filter_complex', ';'.join(filter_parts),
        '-map', f'[{final_video}]',
    ]
    if final_audio:
        command.extend(['-map', f'[{final_audio}]', '-c:a', 'aac', '-b:a', '96k'])
    command.extend([
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
        '-maxrate', '2M', '-bufsize', '4M', '-pix_fmt', 'yuv420p',
        '-movflags', '+faststart', output,
    ])
    _run(command)
    return 'edit-graph-v2-render'


def process_job(job: dict[str, Any]) -> None:
    asset_id = str(job.get('assetId', '')).strip()
    project_id = str(job.get('projectId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    source_path = str(job.get('storagePath', '')).strip()
    content_type = str(job.get('contentType', '')).strip().lower()
    content_length = int(job.get('contentLength') or 0)

    if not asset_id or not project_id or not owner_id or not _safe_creation_path(source_path):
        raise ValueError('Invalid creation processing job.')
    if content_length <= 0 or content_length > MAX_VIDEO_BYTES:
        raise ValueError('Creation source exceeds the configured size limit.')
    if not content_type.startswith('video/'):
        raise ValueError('Creation processing job is not a video.')

    db = _firebase()
    job_id = uuid.uuid4().hex
    if not _claim(db, asset_id, job_id):
        logging.info('Skipping already-claimed or completed media job %s.', asset_id)
        return

    reel_snapshot = db.collection('reels').document(project_id).get()
    reel_data = reel_snapshot.to_dict() if reel_snapshot.exists else {}
    edit_graph = reel_data.get('editGraph') if isinstance(reel_data.get('editGraph'), dict) else {}

    service = _blob_service()
    container_client = service.get_container_client(CONTAINER)

    with tempfile.TemporaryDirectory(prefix='ojas-media-') as tmp:
        root = Path(tmp)
        source = root / 'source.bin'
        processed = root / 'processed.mp4'
        thumb = root / 'thumbnail.jpg'
        hls_dir = root / 'hls'
        hls_dir.mkdir()

        logging.info('Downloading source %s', source_path)
        downloader = container_client.get_blob_client(source_path).download_blob(max_concurrency=2)
        with source.open('wb') as handle:
            for chunk in downloader.chunks():
                handle.write(chunk)

        if source.stat().st_size != content_length:
            raise RuntimeError('Source length changed during processing.')

        metadata = _probe(str(source))
        if metadata['durationMs'] <= 0 or metadata['durationMs'] > MAX_SOURCE_SECONDS * 1000:
            raise ValueError('Video duration exceeds the 15 minute creation limit.')
        if metadata['width'] <= 0 or metadata['height'] <= 0:
            raise ValueError('Unable to read video dimensions.')

        worker_mode = _render_edit_graph(str(source), str(processed), metadata, edit_graph)

        _run([
            'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-ss', '0', '-i', str(processed),
            '-frames:v', '1', '-q:v', '2', '-vf', "scale='min(720,iw)':-2:force_original_aspect_ratio=decrease",
            str(thumb),
        ])

        processed_path = f'creation/{owner_id}/{project_id}/{asset_id}/processed.mp4'
        thumb_path = f'creation/{owner_id}/{project_id}/{asset_id}/thumbnail.jpg'
        _upload_blob(service, processed, processed_path, 'video/mp4')
        _upload_blob(service, thumb, thumb_path, 'image/jpeg')

        hls_path = ''
        if ENABLE_HLS:
            hls_manifest = hls_dir / 'index.m3u8'
            _run([
                'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', str(processed),
                '-c', 'copy', '-hls_time', '4', '-hls_playlist_type', 'vod',
                '-hls_segment_filename', str(hls_dir / 'segment%05d.ts'), str(hls_manifest),
            ])
            hls_base = f'creation/{owner_id}/{project_id}/{asset_id}/hls'
            for item in sorted(hls_dir.iterdir()):
                if item.is_file():
                    mime = 'application/vnd.apple.mpegurl' if item.suffix == '.m3u8' else 'video/mp2t'
                    _upload_blob(service, item, f'{hls_base}/{item.name}', mime)
            hls_path = f'{hls_base}/index.m3u8'

        processed_size = processed.stat().st_size
        processed_base = f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{processed_path}'
        thumb_base = f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{thumb_path}'
        hls_base_url = f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{hls_path}' if hls_path else ''

        db.collection('creationMedia').document(asset_id).set({
            'processingStatus': 'ready',
            'processedVideoStoragePath': processed_path,
            'thumbnailStoragePath': thumb_path,
            'hlsStoragePath': hls_path,
            'processedVideoBytes': processed_size,
            'durationMs': metadata['durationMs'],
            'width': metadata['width'],
            'height': metadata['height'],
            'codec': metadata['codec'],
            'workerMode': worker_mode if not ENABLE_HLS else f'{worker_mode}-hls',
            'editGraphAppliedVersion': 2,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }, merge=True)

        db.collection('reels').document(project_id).set({
            'mediaProvider': 'azure',
            'mediaProcessingStatus': 'ready',
            'processedVideoStoragePath': processed_path,
            'thumbnailStoragePath': thumb_path,
            'hlsStoragePath': hls_path,
            'hlsUrl': hls_base_url or processed_base,
            'videoUrl': processed_base,
            'thumbnailUrl': thumb_base,
            'mediaDurationMs': metadata['durationMs'],
            'mediaWidth': metadata['width'],
            'mediaHeight': metadata['height'],
            'mediaCodec': metadata['codec'],
            'mediaProcessingMode': worker_mode if not ENABLE_HLS else f'{worker_mode}-hls',
            'editGraphAppliedVersion': 2,
            'mediaProcessedAt': firestore.SERVER_TIMESTAMP,
        }, merge=True)

        logging.info('Creation media %s processed successfully.', asset_id)


def main() -> int:
    queue = _queue()
    messages = list(queue.receive_messages(messages_per_page=1, visibility_timeout=QUEUE_VISIBILITY_SECONDS))
    if not messages:
        logging.info('No media processing job available.')
        return 0

    message = messages[0]
    try:
        job = json.loads(message.content)
        process_job(job)
    except Exception as error:
        logging.exception('Creation media processing failed.')
        try:
            job = json.loads(message.content)
            db = _firebase()
            _mark_failed(db, str(job.get('assetId', '')), str(job.get('projectId', '')), str(error))
        finally:
            raise
    else:
        queue.delete_message(message.id, message.pop_receipt)
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
