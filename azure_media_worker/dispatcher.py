import hashlib
import json
import logging
from pathlib import Path
from typing import Any

import worker

MAX_CLEANUP_PREFIX_LENGTH = 256
MAX_AUDIO_BYTES = 10 * 1024 * 1024
MAX_HASH_CHUNK_BYTES = 8 * 1024 * 1024


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
        and all(len(part) <= 256 for part in parts[4:])
    )


def _safe_asset_prefix(owner_id: str, project_id: str, asset_id: str) -> str:
    if not owner_id or not project_id or not asset_id:
        raise ValueError('Invalid media replacement identity.')
    if any('/' in value or '..' in value for value in (owner_id, project_id, asset_id)):
        raise ValueError('Invalid media replacement identity.')
    return f'creation/{owner_id}/{project_id}/{asset_id}/'


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
            logging.warning('Could not delete creation audio %s.', storage_path)
    return deleted


def _current_audio_paths(edit_graph: Any, owner_id: str, project_id: str) -> set[str]:
    if not isinstance(edit_graph, dict):
        return set()
    raw_audio = edit_graph.get('audio')
    if not isinstance(raw_audio, list):
        return set()
    paths: set[str] = set()
    for raw in raw_audio[:worker.MAX_AUDIO_LAYERS]:
        if not isinstance(raw, dict):
            continue
        value = raw.get('storagePath')
        if isinstance(value, str):
            path = value.strip()
            if _safe_audio_path(path, owner_id, project_id):
                paths.add(path)
    return paths


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


def _server_hash_job(job: dict[str, Any]) -> None:
    asset_id = str(job.get('assetId', '')).strip()
    project_id = str(job.get('projectId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    processed_path = str(job.get('processedVideoStoragePath', '')).strip()
    prefix = _safe_asset_prefix(owner_id, project_id, asset_id)
    if not processed_path.startswith(prefix) or '..' in processed_path or len(processed_path) > 512:
        raise ValueError('Invalid processed media storage path.')

    db = worker._firebase()
    media_ref = db.collection('creationMedia').document(asset_id)
    reel_ref = db.collection('reels').document(project_id)
    media_snapshot = media_ref.get()
    reel_snapshot = reel_ref.get()
    media_data = media_snapshot.to_dict() if media_snapshot.exists else {}
    reel_data = reel_snapshot.to_dict() if reel_snapshot.exists else {}
    existing_hash = str(media_data.get('serverMediaHash') or reel_data.get('serverMediaHash') or '').strip()
    if len(existing_hash) == 64:
        if str(reel_data.get('serverMediaHash') or '').strip() != existing_hash:
            reel_ref.set({'serverMediaHash': existing_hash, 'serverMediaHashAt': worker.firestore.SERVER_TIMESTAMP}, merge=True)
        return

    service = worker._blob_service()
    blob = service.get_blob_client(container=worker.CONTAINER, blob=processed_path)
    props = blob.get_blob_properties()
    size = int(props.size or 0)
    if size <= 0 or size > worker.MAX_VIDEO_BYTES:
        raise ValueError('Processed media size is outside the allowed range.')

    digest = hashlib.sha256()
    downloader = blob.download_blob(max_concurrency=2)
    total = 0
    for chunk in downloader.chunks():
        if not chunk:
            continue
        total += len(chunk)
        if total > worker.MAX_VIDEO_BYTES:
            raise ValueError('Processed media exceeded the maximum allowed size while hashing.')
        digest.update(chunk)
    if total != size:
        raise RuntimeError('Processed media changed during server hash calculation.')
    server_hash = digest.hexdigest()

    media_ref.set({
        'serverMediaHash': server_hash,
        'serverMediaHashAlgorithm': 'sha256',
        'serverMediaHashAt': worker.firestore.SERVER_TIMESTAMP,
        'serverMediaBytes': total,
        'updatedAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    reel_ref.set({
        'serverMediaHash': server_hash,
        'serverMediaHashAlgorithm': 'sha256',
        'serverMediaHashAt': worker.firestore.SERVER_TIMESTAMP,
        'serverMediaBytes': total,
        'updatedAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    logging.info('Server SHA-256 generated for %s: %s bytes.', project_id, total)


def _replacement_cleanup_job(job: dict[str, Any]) -> None:
    reel_id = str(job.get('reelId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    old_asset_id = str(job.get('oldAssetId', '')).strip()
    raw_audio = job.get('oldAudioPaths')
    if not reel_id or not owner_id or not old_asset_id or not isinstance(raw_audio, list):
        raise ValueError('Invalid media replacement cleanup job.')

    db = worker._firebase()
    reel_ref = db.collection('reels').document(reel_id)
    snapshot = reel_ref.get()
    if not snapshot.exists:
        logging.info('Skipping replacement cleanup for missing reel %s.', reel_id)
        return
    reel = snapshot.to_dict() or {}
    current_asset_id = str(reel.get('mediaAssetId') or '').strip()
    if old_asset_id == current_asset_id:
        logging.warning('Refusing to delete current media asset %s for reel %s', old_asset_id, reel_id)
        return

    retained_audio_paths = _current_audio_paths(reel.get('editGraph'), owner_id, reel_id)
    service = worker._blob_service()
    container_client = service.get_container_client(worker.CONTAINER)
    old_prefix = _safe_asset_prefix(owner_id, reel_id, old_asset_id)
    deleted_media = 0
    for blob in container_client.list_blobs(name_starts_with=old_prefix):
        container_client.delete_blob(blob.name, delete_snapshots='include')
        deleted_media += 1

    deleted_audio = 0
    retained_audio = 0
    for raw_path in raw_audio[:worker.MAX_AUDIO_LAYERS]:
        if not isinstance(raw_path, str):
            continue
        path = raw_path.strip()
        if not _safe_audio_path(path, owner_id, reel_id):
            logging.warning('Skipping unsafe replacement audio path %s.', path)
            continue
        if path in retained_audio_paths:
            retained_audio += 1
            logging.info('Keeping audio asset retained by current edit graph: %s', path)
            continue
        try:
            container_client.delete_blob(path, delete_snapshots='include')
            deleted_audio += 1
        except Exception:
            logging.warning('Replacement audio blob already missing or could not be deleted: %s', path)

    reel_ref.set({
        'mediaReplacementCleanupStatus': 'completed',
        'mediaReplacementCleanupDeletedMediaBlobs': deleted_media,
        'mediaReplacementCleanupDeletedAudioBlobs': deleted_audio,
        'mediaReplacementCleanupRetainedAudioBlobs': retained_audio,
        'mediaReplacementCleanupAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    logging.info('Replacement cleanup complete for %s: %s media, %s audio blobs, %s retained.', reel_id, deleted_media, deleted_audio, retained_audio)


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
        elif kind == 'creation-media-server-hash':
            _server_hash_job(job)
        elif kind == 'creation-media-replacement-cleanup':
            _replacement_cleanup_job(job)
        else:
            raise ValueError(f'Unsupported media queue job kind: {kind}')
    except Exception as error:
        logging.exception('Media queue job failed.')
        try:
            job = json.loads(message.content)
            asset_id = str(job.get('assetId') or job.get('oldAssetId') or '').strip()
            project_id = str(job.get('reelId') or job.get('projectId') or '').strip()
            db = worker._firebase()
            if asset_id:
                db.collection('creationMedia').document(asset_id).set({'processingStatus': 'failed', 'processingError': str(error)[:1000], 'updatedAt': worker.firestore.SERVER_TIMESTAMP}, merge=True)
            if project_id:
                db.collection('reels').document(project_id).set({'mediaCleanupStatus': 'failed' if job.get('kind') in {'creation-media-cleanup', 'creation-media-replacement-cleanup'} else 'processing_failed', 'mediaProcessingError': str(error)[:1000]}, merge=True)
        finally:
            raise
    else:
        queue.delete_message(message.id, message.pop_receipt)
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
