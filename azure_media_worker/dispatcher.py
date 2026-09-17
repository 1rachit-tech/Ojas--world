import json
import logging
import os
import uuid

import worker

MAX_CLEANUP_PREFIX_LENGTH = 256


def _safe_cleanup_prefix(prefix: str, owner_id: str, reel_id: str) -> bool:
    expected = f'creation/{owner_id}/{reel_id}/'
    return (
        prefix == expected
        and len(prefix) <= MAX_CLEANUP_PREFIX_LENGTH
        and owner_id.replace('_', '').replace('-', '').isalnum()
        and reel_id.replace('_', '').replace('-', '').isalnum()
        and '..' not in prefix
    )


def _safe_audio_prefix(prefix: str, owner_id: str, reel_id: str) -> bool:
    expected = f'creation_audio/{owner_id}/{reel_id}/'
    return prefix == expected and len(prefix) <= MAX_CLEANUP_PREFIX_LENGTH and '..' not in prefix


def _cleanup_job(job: dict) -> None:
    reel_id = str(job.get('reelId', '')).strip()
    owner_id = str(job.get('ownerId', '')).strip()
    asset_id = str(job.get('assetId', '')).strip()
    cleanup_prefix = str(job.get('cleanupPrefix', '')).strip()
    audio_prefix = str(job.get('firebaseAudioPrefix', '')).strip()
    audio_bucket_name = str(job.get('firebaseAudioBucket', '')).strip()

    if not reel_id or not owner_id or not asset_id:
        raise ValueError('Invalid cleanup job identity.')
    if not _safe_cleanup_prefix(cleanup_prefix, owner_id, reel_id):
        raise ValueError('Invalid Azure cleanup prefix.')
    if not _safe_audio_prefix(audio_prefix, owner_id, reel_id):
        raise ValueError('Invalid Firebase audio cleanup prefix.')

    service = worker._blob_service()
    container_client = service.get_container_client(worker.CONTAINER)
    deleted_azure = 0
    for blob in container_client.list_blobs(name_starts_with=cleanup_prefix):
        container_client.delete_blob(blob.name, delete_snapshots='include')
        deleted_azure += 1

    deleted_audio = 0
    if audio_bucket_name:
        bucket = worker._firebase_bucket(audio_bucket_name)
        for blob in bucket.list_blobs(prefix=audio_prefix):
            blob.delete()
            deleted_audio += 1

    db = worker._firebase()
    db.collection('creationMedia').document(asset_id).set({
        'processingStatus': 'cancelled',
        'mediaCleanupStatus': 'completed',
        'mediaCleanupDeletedAzureBlobs': deleted_azure,
        'mediaCleanupDeletedFirebaseAudio': deleted_audio,
        'mediaCleanupAt': worker.firestore.SERVER_TIMESTAMP,
        'updatedAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    db.collection('reels').document(reel_id).set({
        'mediaCleanupStatus': 'completed',
        'mediaCleanupDeletedAzureBlobs': deleted_azure,
        'mediaCleanupDeletedFirebaseAudio': deleted_audio,
        'mediaCleanupAt': worker.firestore.SERVER_TIMESTAMP,
    }, merge=True)
    logging.info('Cleanup complete for %s: %s Azure blobs, %s Firebase audio assets.', reel_id, deleted_azure, deleted_audio)


def _transcode_job(job: dict) -> None:
    project_id = str(job.get('projectId', '')).strip()
    asset_id = str(job.get('assetId', '')).strip()
    if not project_id or not asset_id:
        raise ValueError('Invalid transcode job identity.')

    db = worker._firebase()
    reel_snapshot = db.collection('reels').document(project_id).get()
    if reel_snapshot.exists:
        reel = reel_snapshot.to_dict() or {}
        if reel.get('deletedAt') is not None or str(reel.get('moderationStatus', '')).lower() == 'deleted':
            db.collection('creationMedia').document(asset_id).set({
                'processingStatus': 'cancelled',
                'processingError': 'Post was deleted before media processing started.',
                'updatedAt': worker.firestore.SERVER_TIMESTAMP,
            }, merge=True)
            logging.info('Skipping transcode for deleted reel %s.', project_id)
            return
    worker.process_job(job)


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
                db.collection('creationMedia').document(asset_id).set({
                    'processingStatus': 'failed',
                    'processingError': str(error)[:1000],
                    'updatedAt': worker.firestore.SERVER_TIMESTAMP,
                }, merge=True)
            if project_id:
                db.collection('reels').document(project_id).set({
                    'mediaCleanupStatus': 'failed' if job.get('kind') == 'creation-media-cleanup' else 'processing_failed',
                    'mediaProcessingError': str(error)[:1000],
                }, merge=True)
        finally:
            raise
    else:
        queue.delete_message(message.id, message.pop_receipt)
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
