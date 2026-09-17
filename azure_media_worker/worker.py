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
QUEUE_VISIBILITY_SECONDS = 3600

STORAGE_ACCOUNT = os.environ.get('AZURE_STORAGE_ACCOUNT_NAME', '').strip()
CONTAINER = os.environ.get('AZURE_STORAGE_CONTAINER', 'ojas-media').strip()
STORAGE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_CONNECTION_STRING', '').strip()
QUEUE_CONNECTION_STRING = os.environ.get('AZURE_STORAGE_QUEUE_CONNECTION_STRING', '').strip()
QUEUE_NAME = os.environ.get('AZURE_STORAGE_PROCESSING_QUEUE', 'ojas-media-processing').strip().lower()
ENABLE_HLS = os.environ.get('OJAS_ENABLE_HLS', 'false').strip().lower() == 'true'


def _firebase() -> firestore.Client:
    if not firebase_admin._apps:
        service_account = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON', '').strip()
        if service_account:
            firebase_admin.initialize_app(
                credentials.Certificate(json.loads(service_account)),
            )
        else:
            firebase_admin.initialize_app()
    return firestore.client()


def _blob_service() -> BlobServiceClient:
    if STORAGE_CONNECTION_STRING:
        return BlobServiceClient.from_connection_string(STORAGE_CONNECTION_STRING)
    if not STORAGE_ACCOUNT:
        raise RuntimeError('AZURE_STORAGE_ACCOUNT_NAME is required.')
    return BlobServiceClient(
        account_url=f'https://{STORAGE_ACCOUNT}.blob.core.windows.net',
        credential=DefaultAzureCredential(),
    )


def _queue() -> QueueClient:
    if not QUEUE_CONNECTION_STRING:
        raise RuntimeError('AZURE_STORAGE_QUEUE_CONNECTION_STRING is required.')
    return QueueClient.from_connection_string(QUEUE_CONNECTION_STRING, QUEUE_NAME)


def _safe_creation_path(path: str) -> bool:
    parts = path.split('/')
    return (
        len(parts) == 4
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
    video_stream = next((s for s in streams if s.get('codec_type') == 'video'), {})
    return {
        'durationMs': int(duration * 1000),
        'sizeBytes': size,
        'width': int(video_stream.get('width') or 0),
        'height': int(video_stream.get('height') or 0),
        'codec': str(video_stream.get('codec_name') or ''),
    }


def _upload_blob(service: BlobServiceClient, local_path: Path, storage_path: str, content_type: str) -> None:
    blob = service.get_blob_client(container=CONTAINER, blob=storage_path)
    with local_path.open('rb') as handle:
        blob.upload_blob(
            handle,
            overwrite=True,
            content_settings=ContentSettings(content_type=content_type),
        )


def _mark_failed(db: firestore.Client, asset_id: str, project_id: str, message: str) -> None:
    update = {
        'processingStatus': 'failed',
        'processingError': message[:1000],
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }
    db.collection('creationMedia').document(asset_id).set(update, merge=True)
    db.collection('reels').document(project_id).set(
        {
            'mediaProcessingStatus': 'failed',
            'mediaProcessingError': message[:1000],
        },
        merge=True,
    )


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
        if status == 'ready':
            return False
        if status == 'processing':
            return False
        txn.update(ref, {
            'processingStatus': 'processing',
            'processingJobId': job_id,
            'processingStartedAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        })
        return True

    return apply_claim(transaction)


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

        _run([
            'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
            '-i', str(source),
            '-vf', "scale='min(720,iw)':-2:force_original_aspect_ratio=decrease",
            '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
            '-maxrate', '2M', '-bufsize', '4M', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart',
            str(processed),
        ])

        _run([
            'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
            '-ss', '0', '-i', str(source),
            '-frames:v', '1', '-q:v', '2',
            '-vf', "scale='min(720,iw)':-2:force_original_aspect_ratio=decrease",
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
                'ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
                '-i', str(processed),
                '-c', 'copy', '-hls_time', '4', '-hls_playlist_type', 'vod',
                '-hls_segment_filename', str(hls_dir / 'segment%05d.ts'),
                str(hls_manifest),
            ])
            hls_base = f'creation/{owner_id}/{project_id}/{asset_id}/hls'
            for item in sorted(hls_dir.iterdir()):
                if item.is_file():
                    suffix = 'application/vnd.apple.mpegurl' if item.suffix == '.m3u8' else 'video/mp2t'
                    _upload_blob(service, item, f'{hls_base}/{item.name}', suffix)
            hls_path = f'{hls_base}/index.m3u8'

        processed_size = processed.stat().st_size
        processed_base = f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{processed_path}'
        thumb_base = f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{thumb_path}'
        hls_base_url = (
            f'https://{STORAGE_ACCOUNT}.blob.core.windows.net/{CONTAINER}/{hls_path}'
            if hls_path else ''
        )

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
            'workerMode': 'ffmpeg-720p-mp4' if not ENABLE_HLS else 'ffmpeg-720p-mp4-hls',
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
            'mediaProcessingMode': 'ffmpeg-720p-mp4' if not ENABLE_HLS else 'ffmpeg-720p-mp4-hls',
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
            _mark_failed(
                db,
                str(job.get('assetId', '')),
                str(job.get('projectId', '')),
                str(error),
            )
        finally:
            raise
    else:
        queue.delete_message(message.id, message.pop_receipt)
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
