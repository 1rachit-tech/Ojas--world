import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any

import azure.functions as func
from azure.storage.blob import BlobSasPermissions, BlobServiceClient, generate_blob_sas
import firebase_admin
from firebase_admin import auth, credentials, firestore

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "")
_ACCOUNT_KEY = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY", "")
_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER", "ojas-media")
_MAX_CHAT_MEDIA_BYTES = 10 * 1024 * 1024
_MAX_CREATION_VIDEO_BYTES = 512 * 1024 * 1024
_MAX_CREATION_AUDIO_BYTES = 10 * 1024 * 1024
_SAS_TTL_MINUTES = 5
_PLAYBACK_SAS_TTL_MINUTES = 15

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SAFE_ID = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
_SAFE_CREATION_PATH = re.compile(r"^creation/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}(?:/[^/]{1,512}){0,5}$")
_SAFE_AUDIO_PATH = re.compile(r"^creation-audio/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}/[^/]{1,128}/[^/]{1,256}$")
_CREATION_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm", "video/x-m4v"}
_CREATION_AUDIO_TYPES = {"audio/mpeg", "audio/mp4", "audio/wav", "audio/aac", "audio/ogg", "audio/opus"}
_FIREBASE_READY = False
_FIREBASE_ERROR = ""

try:
    if not firebase_admin._apps:
        firebase_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if firebase_json:
            firebase_admin.initialize_app(credentials.Certificate(json.loads(firebase_json)))
        else:
            firebase_admin.initialize_app()
    _FIREBASE_READY = True
except Exception as error:
    _FIREBASE_ERROR = str(error)[:300]
    logging.exception("Firebase Admin initialization failed.")


def _json(status: int, body: dict[str, Any]) -> func.HttpResponse:
    return func.HttpResponse(json.dumps(body), status_code=status, mimetype="application/json", headers={"Cache-Control": "no-store"})


def _user_from_request(req: func.HttpRequest) -> dict[str, Any] | None:
    if not _FIREBASE_READY:
        return None
    authorization = req.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        return None
    try:
        return auth.verify_id_token(authorization[7:])
    except Exception:
        return None


def _creation_blob_base(uid: str, project_id: str, asset_id: str) -> str:
    return f"creation/{uid}/{project_id}/{asset_id}"


def _get_blob_client(storage_path: str):
    service = BlobServiceClient(account_url=f"https://{_ACCOUNT_NAME}.blob.core.windows.net", credential=_ACCOUNT_KEY)
    return service.get_blob_client(container=_CONTAINER, blob=storage_path)


def _creation_download_url(storage_path: str) -> str:
    return f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{storage_path}"


def _require_storage() -> bool:
    return bool(_ACCOUNT_NAME and _ACCOUNT_KEY and _CONTAINER)


def _require_id(value: Any) -> bool:
    return isinstance(value, str) and bool(_SAFE_ID.fullmatch(value.strip()))


def _record_creation_media(*, uid: str, project_id: str, asset_id: str, storage_path: str, content_length: int, content_type: str) -> None:
    if not _FIREBASE_READY:
        return
    firestore.client().collection("creationMedia").document(asset_id).set({
        "assetId": asset_id,
        "projectId": project_id,
        "ownerId": uid,
        "storagePath": storage_path,
        "contentLength": content_length,
        "contentType": content_type,
        "status": "uploaded",
        "processingStatus": "queued",
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }, merge=True)


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    del req
    ready = bool(_FIREBASE_READY and _require_storage())
    return _json(200 if ready else 503, {
        "service": "ojas-media-broker",
        "ready": ready,
        "firebaseAdminReady": _FIREBASE_READY,
        "storageConfigured": _require_storage(),
        "containerConfigured": bool(_CONTAINER),
        "mode": "usage-driven",
        "idleNotificationPolling": False,
        "maxChatMediaBytes": _MAX_CHAT_MEDIA_BYTES,
        "maxCreationVideoBytes": _MAX_CREATION_VIDEO_BYTES,
        "maxCreationAudioBytes": _MAX_CREATION_AUDIO_BYTES,
        "playbackSasTtlMinutes": _PLAYBACK_SAS_TTL_MINUTES,
        "error": _FIREBASE_ERROR if not _FIREBASE_READY else "",
    })


@app.route(route="media/upload-target", methods=["POST"])
def upload_target(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage():
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    conversation_id = str(data.get("conversationId", "")).strip()
    blob_name = str(data.get("blobName", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()
    uid = decoded.get("uid", "")
    if not isinstance(uid, str) or not uid or len(uid) > 128:
        return _json(401, {"error": "Authentication required."})
    if not conversation_id or len(conversation_id) > 128 or not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid conversation or file name."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > _MAX_CHAT_MEDIA_BYTES:
        return _json(400, {"error": "Invalid file size."})
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        return _json(400, {"error": "Unsupported media type."})
    conversation = firestore.client().collection("conversations").document(conversation_id).get()
    participants = (conversation.to_dict() or {}).get("participants", []) if conversation.exists else []
    if not isinstance(participants, list) or uid not in participants:
        return _json(403, {"error": "You are not allowed to upload to this conversation."})
    safe_conversation = re.sub(r"[^A-Za-z0-9_-]", "_", conversation_id)
    blob_path = f"chat_media/{safe_conversation}/images/{uid}/{blob_name}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_SAS_TTL_MINUTES)
    sas = generate_blob_sas(account_name=_ACCOUNT_NAME, container_name=_CONTAINER, blob_name=blob_path, account_key=_ACCOUNT_KEY, permission=BlobSasPermissions(create=True, write=True), expiry=expiry)
    base = _creation_download_url(blob_path)
    return _json(200, {"uploadUrl": f"{base}?{sas}", "downloadUrl": base, "storagePath": blob_path, "headers": {"x-ms-version": "2023-11-03"}, "expiresAt": expiry.isoformat(), "maxBytes": _MAX_CHAT_MEDIA_BYTES})


@app.route(route="media/creation-upload-target", methods=["POST"])
def creation_upload_target(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage():
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    uid = decoded.get("uid", "")
    project_id = str(data.get("projectId", "")).strip()
    asset_id = str(data.get("assetId", "")).strip()
    blob_name = str(data.get("blobName", f"{asset_id}.mp4")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()
    if not _require_id(uid) or not _require_id(project_id) or not _require_id(asset_id):
        return _json(400, {"error": "Invalid creation identifiers."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid video file name."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > _MAX_CREATION_VIDEO_BYTES:
        return _json(400, {"error": "Invalid creation video size."})
    if content_type not in _CREATION_VIDEO_TYPES:
        return _json(400, {"error": "Unsupported creation video type."})
    storage_path = f"{_creation_blob_base(uid, project_id, asset_id)}/{blob_name}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_SAS_TTL_MINUTES)
    sas = generate_blob_sas(account_name=_ACCOUNT_NAME, container_name=_CONTAINER, blob_name=storage_path, account_key=_ACCOUNT_KEY, permission=BlobSasPermissions(create=True, write=True), expiry=expiry)
    base = _creation_download_url(storage_path)
    return _json(200, {"uploadUrl": f"{base}?{sas}", "downloadUrl": base, "storagePath": storage_path, "headers": {"x-ms-version": "2023-11-03"}, "expiresAt": expiry.isoformat(), "maxBytes": _MAX_CREATION_VIDEO_BYTES})


@app.route(route="media/creation-upload-complete", methods=["POST"])
def creation_upload_complete(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage():
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    uid = decoded.get("uid", "")
    project_id = str(data.get("projectId", "")).strip()
    asset_id = str(data.get("assetId", "")).strip()
    storage_path = str(data.get("storagePath", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()
    prefix = f"creation/{uid}/{project_id}/{asset_id}/"
    if not _require_id(uid) or not _require_id(project_id) or not _require_id(asset_id):
        return _json(400, {"error": "Invalid creation identifiers."})
    if not storage_path.startswith(prefix) or not _SAFE_CREATION_PATH.fullmatch(storage_path):
        return _json(400, {"error": "Invalid creation storage path."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > _MAX_CREATION_VIDEO_BYTES:
        return _json(400, {"error": "Invalid creation video size."})
    if content_type not in _CREATION_VIDEO_TYPES:
        return _json(400, {"error": "Unsupported creation video type."})
    blob = _get_blob_client(storage_path)
    try:
        props = blob.get_blob_properties()
    except Exception:
        return _json(400, {"error": "Uploaded creation video was not found."})
    actual_size = int(props.size or 0)
    if actual_size != content_length:
        return _json(400, {"error": "Uploaded creation video size does not match the request."})
    _record_creation_media(uid=uid, project_id=project_id, asset_id=asset_id, storage_path=storage_path, content_length=actual_size, content_type=content_type)
    return _json(200, {"downloadUrl": _creation_download_url(storage_path), "storagePath": storage_path, "contentLength": actual_size, "contentType": content_type, "processingStatus": "queued"})


@app.route(route="media/creation-audio-upload-target", methods=["POST"])
def creation_audio_upload_target(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage():
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    uid = decoded.get("uid", "")
    project_id = str(data.get("projectId", "")).strip()
    layer_id = str(data.get("layerId", "")).strip()
    blob_name = str(data.get("blobName", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()
    if not _require_id(uid) or not _require_id(project_id) or not _require_id(layer_id):
        return _json(400, {"error": "Invalid audio identifiers."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid audio file name."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > _MAX_CREATION_AUDIO_BYTES:
        return _json(400, {"error": "Invalid audio size."})
    if content_type not in _CREATION_AUDIO_TYPES:
        return _json(400, {"error": "Unsupported audio type."})
    storage_path = f"creation-audio/{uid}/{project_id}/{layer_id}/{blob_name}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_SAS_TTL_MINUTES)
    sas = generate_blob_sas(account_name=_ACCOUNT_NAME, container_name=_CONTAINER, blob_name=storage_path, account_key=_ACCOUNT_KEY, permission=BlobSasPermissions(create=True, write=True), expiry=expiry)
    base = _creation_download_url(storage_path)
    return _json(200, {"uploadUrl": f"{base}?{sas}", "downloadUrl": base, "storagePath": storage_path, "expiresAt": expiry.isoformat(), "maxBytes": _MAX_CREATION_AUDIO_BYTES})


@app.route(route="media/creation-audio-upload-complete", methods=["POST"])
def creation_audio_upload_complete(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage():
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    uid = decoded.get("uid", "")
    project_id = str(data.get("projectId", "")).strip()
    layer_id = str(data.get("layerId", "")).strip()
    storage_path = str(data.get("storagePath", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()
    prefix = f"creation-audio/{uid}/{project_id}/{layer_id}/"
    if not _require_id(uid) or not _require_id(project_id) or not _require_id(layer_id):
        return _json(400, {"error": "Invalid audio identifiers."})
    if not storage_path.startswith(prefix) or not _SAFE_AUDIO_PATH.fullmatch(storage_path):
        return _json(400, {"error": "Invalid audio storage path."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > _MAX_CREATION_AUDIO_BYTES:
        return _json(400, {"error": "Invalid audio size."})
    if content_type not in _CREATION_AUDIO_TYPES:
        return _json(400, {"error": "Unsupported audio type."})
    blob = _get_blob_client(storage_path)
    try:
        props = blob.get_blob_properties()
    except Exception:
        return _json(400, {"error": "Uploaded audio was not found."})
    actual_size = int(props.size or 0)
    if actual_size != content_length:
        return _json(400, {"error": "Uploaded audio size does not match the request."})
    return _json(200, {"storagePath": storage_path, "contentLength": actual_size, "contentType": content_type, "downloadUrl": _creation_download_url(storage_path)})


@app.route(route="media/creation-playback-urls", methods=["POST"])
def creation_playback_urls(req: func.HttpRequest) -> func.HttpResponse:
    if not _require_storage() or not _FIREBASE_READY:
        return _json(503, {"error": "Media service is unavailable."})
    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})
    uid = decoded.get("uid", "")
    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})
    raw_ids = data.get("reelIds") if isinstance(data, dict) else None
    if not isinstance(raw_ids, list):
        return _json(400, {"error": "reelIds must be a list."})

    result: dict[str, dict[str, str]] = {}
    db = firestore.client()
    for raw_id in raw_ids[:10]:
        if not isinstance(raw_id, str) or not _SAFE_ID.fullmatch(raw_id.strip()):
            continue
        reel_id = raw_id.strip()
        snapshot = db.collection("reels").document(reel_id).get()
        if not snapshot.exists:
            continue
        reel_data = snapshot.to_dict() or {}
        creator_id = reel_data.get("creatorId") if isinstance(reel_data.get("creatorId"), str) else ""
        if not creator_id:
            continue
        visibility = str(reel_data.get("visibility", "public")).strip().lower()
        deleted = reel_data.get("deletedAt") is not None or str(reel_data.get("moderationStatus", "")).lower() == "deleted"
        if deleted:
            continue
        if visibility == "public":
            authorized = True
        elif creator_id == uid:
            authorized = True
        elif visibility == "followers":
            profile = db.collection("publicProfiles").document(creator_id).get()
            profile_data = profile.to_dict() or {} if profile.exists else {}
            followers = profile_data.get("followers", [])
            authorized = isinstance(followers, list) and uid in followers
        else:
            authorized = False
        if not authorized:
            continue
        if str(reel_data.get("mediaProvider", "")).lower() != "azure":
            continue
        if str(reel_data.get("mediaProcessingStatus", "")).lower() not in {"ready", "published"}:
            continue

        primary_path = str(reel_data.get("hlsStoragePath") or reel_data.get("processedVideoStoragePath") or "").strip()
        thumbnail_path = str(reel_data.get("thumbnailStoragePath") or "").strip()
        allowed_prefix = f"creation/{creator_id}/{reel_id}/"
        if not primary_path or not primary_path.startswith(allowed_prefix) or not _SAFE_CREATION_PATH.fullmatch(primary_path):
            continue
        if not thumbnail_path.startswith(allowed_prefix) or not _SAFE_CREATION_PATH.fullmatch(thumbnail_path):
            thumbnail_path = ""
        try:
            primary_blob = _get_blob_client(primary_path)
            primary_blob.get_blob_properties()
            expiry = datetime.now(timezone.utc) + timedelta(minutes=_PLAYBACK_SAS_TTL_MINUTES)
            primary_sas = generate_blob_sas(account_name=_ACCOUNT_NAME, container_name=_CONTAINER, blob_name=primary_path, account_key=_ACCOUNT_KEY, permission=BlobSasPermissions(read=True), expiry=expiry)
            payload = {"playbackUrl": f"{_creation_download_url(primary_path)}?{primary_sas}"}
            if thumbnail_path:
                thumbnail_blob = _get_blob_client(thumbnail_path)
                thumbnail_blob.get_blob_properties()
                thumb_sas = generate_blob_sas(account_name=_ACCOUNT_NAME, container_name=_CONTAINER, blob_name=thumbnail_path, account_key=_ACCOUNT_KEY, permission=BlobSasPermissions(read=True), expiry=expiry)
                payload["thumbnailUrl"] = f"{_creation_download_url(thumbnail_path)}?{thumb_sas}"
            result[reel_id] = payload
        except Exception:
            continue

    return _json(200, {"urls": result})
