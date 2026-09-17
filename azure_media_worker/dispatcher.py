import json
import logging
from pathlib import Path
from typing import Any

import worker

MAX_CLEANUP_PREFIX_LENGTH = 256
MAX_AUDIO_BYTES = 10 * 1024 * 1024


def _safe_cleanup_prefix(prefix: str, owner_id: str, reel_id: str) -> bool:
    expected = f'creation/{owner_id}/{reel_id}/'
    return prefix == expected and len(prefix) <= MAX_CLEANUP_PREFIX_LENGTH and '..' not in prefix


def _safe_audio_prefix(prefix: str, owner_id: str, reel_id: str) -> bool:
    expected = f'creation-audio/{owner_id}/{reel_id}/'
    return prefix == expected and len(prefix) <= MAX_CLEANUP_PREFIX_LENGTH and '..' not in prefix


def _safe_audio_path(path: str, owner_id: str, project_id: str) -> bool:
    prefix = f'creation-audio/{owner_id}/{project_id}/'
    parts = path.split('/')
    return (
        path.startswith(prefix)
        and '..' not in path
        and len(parts) == 5
        and all(part for part in parts)
        and len(path) <= 512
    )


def _download_audio_layers_azure(
    edit_graph: dict[str, Any],
    owner_id: str,
    project_id: str,
    root: Path,
):
    raw_audio = edit_graph.get('audio')
    if not isinstance(raw_audio, list) or not raw_audio:
        return [], None, []

    service = worker._blob_service()
    container_client = service.get_container_client(worker.CONTAINER)
    files: list[tuple[dict[str, Any], Path]] = []

    for index, raw in enumerate(raw_audio[:worker.MAX_AUDIO_LAYERS]):
        if not isinstance(raw, dict) or raw.get('muted') is True:
            continue
        storage_path = raw.get('storagePath')
        if not isinstance(storage_path, str) or not _safe_audio_path(storage_path, owner_id, project_id):
            raise ValueError('Creation audio asset path is invalid.')
        blob = container_client.get_blob_client(storage_path)
        props = blob.get_blob_properties()
        size = int(props.size or 0)
        if size <= 0 or size > MAX_AUDIO_BYTES:
            raise ValueError('Creation audio asset exceeds the 10 MB limit.')
        target = root / f'audio_{index}'
        downloader = blob.download_blob(max_concurrency=2)
        with target.open('wb') as handle:
            for chunk in downloader.chunks():
                handle.write(chunk)
        if target.stat().st_size != size:
            raise RuntimeError('Creation audio asset changed during download.')
        files.append((raw, target))

    return files, None, []


def _delete_project_audio(edit_graph: dict[str, Any], owner_id: str, project_id: str) -> int:
    raw_audio = edit_graph.get('audio')
    if not isinstance(raw_audio, list) or not raw_audio:
        return 0
    service = worker._blob_service()
    container_client = service.get_container_client(worker.CONTAINER)
    deleted = 0
    for raw in raw_audio[:worker.MAX_AUDIO_LAYERS]:
        if not isinstance(raw, dict):
            continue
        storage_path = raw.get('storagePath')
        if not isinstance(storage_path, str) or not _safe_audio_path(storage_path, owner_id, project_id):
            continue
        try:
            container_client.delete_blob(storage_path, delete_snapshots='include')
            deleted += 1
        except Exception:
            logging.warning('Could not delete temporary creation audio %s.', storage_path)
    return deleted


def _cleanup_job(job: dict[str, Any]) -> None:
    reel_id = str(job.get('reelId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    asset_id = str(job.get('assetId', '')).strip()
    cleanup_prefix = str(job.get('cleanupPrefix', '')).strip()
    audio_prefix = str(job.get('audioCleanupPrefix') or job.get('firebaseAudioPrefix') or '').strip()
    if not reel_id or not owner_id or not asset_id:
        raise ValueError('Invalid cleanup job identity.')
    if not _safe_cleanup_prefix(cleanup_prefix, owner_id, reel_id):
        raise ValueError('Invalid Azure cleanup prefix.')
    if not _safe_audio_prefix(audio_prefix, owner_id, reel_id):
        raise ValueError('Invalid Azure audio cleanup prefix.')

    service = worker._blob_service()
    container_client = service.get_container_client(worker.CONTAINER)
    deleted_azure = 0
    for blob in container_client.list_blobs(name_starts_with=cleanup_prefix):
        container_client.delete_blob(blob.name, delete_snapshots='include')
        deleted_azure += 1
    deleted_audio = 0
    for blob in container_client.list_blobs(name_starts_with=audio_prefix):
        container_client.delete_blob(blob.name, delete_snapshots='include')
        deleted_audio += 1

    db = worker._firebase()
    db.collection('creationMedia').document(asset_id).set({
        'processingStatus': 'cancelled',
        'mediaCleanupStatus': 'completed',
        'mediaCleanupDeletedAzureBlobs': deleted_azure,
        'mediaCleanupDeletedAudioBlobs': deleted_audio,
        'mediaCleanupAt': worker.firestore.SERVER_TIMESTAMP,
        'updatedAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    db.collection('reels').document(reel_id).set({
        'mediaCleanupStatus': 'completed',
        'mediaCleanupDeletedAzureBlobs': deleted_azure,
        'mediaCleanupDeletedAudioBlobs': deleted_audio,
        'mediaCleanupAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    logging.info('Cleanup complete for %s: %s media blobs, %s audio blobs.', reel_id, deleted_azure, deleted_audio)


def _transcode_job(job: dict[str, Any]) -> None:
    project_id = str(job.get('projectId', '')).strip()
    asset_id = str(job.get('assetId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    if not project_id or not asset_id or not owner_id:
        raise ValueError('Invalid transcode job identity.')

    db = worker._firebase()
    reel_snapshot = db.collection('reels').document(project_id).get()
    if reel_snapshot.exists:
        reel = reel_snapshot.to_dict() or {}
        if reel.get('deletedAt') is not None or str(reel.get('moderationStatus', '')).lower() == 'deleted':
            db.collection('creationMedia').document(asset_id).set({'processingStatus': 'cancelled', 'processingError': 'Post was deleted before media processing started.', 'updatedAt': worker.firestore.SERVER_TIMESTAMP}, merge=True)
            logging.info('Skipping transcode for deleted reel %s.', project_id)
            return

    previous_downloader = worker._download_audio_layers
    worker._download_audio_layers = _download_audio_layers_azure
    try:
        worker.process_job(job)
    except Exception:
        raise
    else:
        final_snapshot = db.collection('reels').document(project_id).get()
        final_data = final_snapshot.to_dict() if final_snapshot.exists else {}
        edit_graph = final_data.get('editGraph') if isinstance(final_data.get('editGraph'), dict) else {}
        deleted_audio = _delete_project_audio(edit_graph, owner_id, project_id)
        if deleted_audio:
            db.collection('reels').document(project_id).set({'audioCleanupStatus': 'completed', 'audioCleanupDeletedBlobs': deleted_audio, 'audioCleanupAt': worker.firestore.SERVER_TIMESTAMP}, merge=True)
    finally:
        worker._download_audio_layers = previous_downloader


def main() -> int:
    queue = worker._queue()
    messages = list(queue.receive_messages(messages_per_page=1, visibility_timeout=worker.QUEUE_VISIBILITY_SECONDS))
    if not messages:
        logging.info('No media processing job available.')
        return 0

    message = messages[0]
    try:
        job = json.loads(message.content)
        kind = str(job.get('kind', 'creation-video-transcode')).strip()
        if kind == 'creation-media-cleanup':
            _cleanup_job(job)
        elif kind == 'creation-video-transcode':
            _transcode_job(job)
        else:
            raise ValueError(f'Unsupported media queue job kind: {kind}')
    except Exception as error:
        logging.exception('Media queue job failed.')
        try:
            job = json.loads(message.content)
            asset_id = str(job.get('assetId', '')).strip()
            project_id = str(job.get('reelId') or job.get('projectId') or '').strip()
            db = worker._firebase()
            if asset_id:
                db.collection('creationMedia').document(asset_id).set({'processingStatus': 'failed', 'processingError': str(error)[:1000], 'updatedAt': worker.firestore.SERVER_TIMESTAMP}, merge=True)
            if project_id:
                db.collection('reels').document(project_id).set({'mediaCleanupStatus': 'failed' if job.get('kind') == 'creation-media-cleanup' else 'processing_failed', 'mediaProcessingError': str(error)[:1000]}, merge=True)
        finally:
            raise
    else:
        queue.delete_message(message.id, message.pop_receipt)
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
