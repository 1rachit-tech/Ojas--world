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
_SAS_TTL_MINUTES = 5

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SAFE_ID = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
_CREATION_VIDEO_TYPES = {
    "video/mp4",
    "video/quicktime",
    "video/webm",
    "video/x-m4v",
}
_CREATION_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
_FIREBASE_READY = False
_FIREBASE_ERROR = ""

try:
    if not firebase_admin._apps:
        firebase_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
        if firebase_json:
            firebase_admin.initialize_app(
                credentials.Certificate(json.loads(firebase_json)),
            )
        else:
            firebase_admin.initialize_app()
    _FIREBASE_READY = True
except Exception as error:
    _FIREBASE_ERROR = str(error)[:300]
    logging.exception("Firebase Admin initialization failed.")


def _json(status: int, body: dict[str, Any]) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps(body),
        status_code=status,
        mimetype="application/json",
        headers={"Cache-Control": "no-store"},
    )


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
    service = BlobServiceClient(
        account_url=f"https://{_ACCOUNT_NAME}.blob.core.windows.net",
        credential=_ACCOUNT_KEY,
    )
    return service.get_blob_client(container=_CONTAINER, blob=storage_path)


def _record_creation_media(
    *,
    uid: str,
    project_id: str,
    asset_id: str,
    storage_path: str,
    content_length: int,
    content_type: str,
) -> None:
    if not _FIREBASE_READY:
        return
    firestore.client().collection("creationMedia").document(asset_id).set(
        {
            "assetId": asset_id,
            "projectId": project_id,
            "ownerId": uid,
            "storagePath": storage_path,
            "contentLength": content_length,
            "contentType": content_type,
            "status": "uploaded",
            "processingStatus": "queued",
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    del req
    ready = bool(
        _FIREBASE_READY
        and _ACCOUNT_NAME
        and _ACCOUNT_KEY
        and _CONTAINER
    )
    return _json(
        200 if ready else 503,
        {
            "service": "ojas-media-broker",
            "ready": ready,
            "firebaseAdminReady": _FIREBASE_READY,
            "storageConfigured": bool(_ACCOUNT_NAME and _ACCOUNT_KEY),
            "containerConfigured": bool(_CONTAINER),
            "mode": "usage-driven",
            "idleNotificationPolling": False,
            "maxChatMediaBytes": _MAX_CHAT_MEDIA_BYTES,
            "maxCreationVideoBytes": _MAX_CREATION_VIDEO_BYTES,
            "error": _FIREBASE_ERROR if not _FIREBASE_READY else "",
        },
    )


@app.route(route="media/upload-target", methods=["POST"])
def upload_target(req: func.HttpRequest) -> func.HttpResponse:
    """Backward-compatible chat image upload target."""
    if not _ACCOUNT_NAME or not _ACCOUNT_KEY:
        logging.error("Azure storage credentials are not configured.")
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
    if not conversation_id or len(conversation_id) > 128:
        return _json(400, {"error": "Invalid conversation."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid file name."})
    if (
        not isinstance(content_length, int)
        or content_length <= 0
        or content_length > _MAX_CHAT_MEDIA_BYTES
    ):
        return _json(400, {"error": "Invalid file size."})
    if content_type not in _CREATION_IMAGE_TYPES:
        return _json(400, {"error": "Unsupported media type."})

    if not _FIREBASE_READY:
        return _json(503, {"error": "Media service is unavailable."})
    snapshot = (
        firestore.client()
        .collection("conversations")
        .document(conversation_id)
        .get()
    )
    if not snapshot.exists:
        return _json(404, {"error": "Conversation not found."})
    participants = (snapshot.to_dict() or {}).get("participants", [])
    if not isinstance(participants, list) or uid not in participants:
        return _json(403, {"error": "You are not allowed to upload to this conversation."})

    safe_conversation = re.sub(r"[^A-Za-z0-9_-]", "_", conversation_id)
    blob_path = f"chat_media/{safe_conversation}/images/{uid}/{blob_name}"
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_SAS_TTL_MINUTES)

    sas = generate_blob_sas(
        account_name=_ACCOUNT_NAME,
        container_name=_CONTAINER,
        blob_name=blob_path,
        account_key=_ACCOUNT_KEY,
        permission=BlobSasPermissions(create=True, write=True),
        expiry=expiry,
    )

    base = f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{blob_path}"
    return _json(
        200,
        {
            "uploadUrl": f"{base}?{sas}",
            "downloadUrl": base,
            "storagePath": blob_path,
            "headers": {"x-ms-version": "2023-11-03"},
            "expiresAt": expiry.isoformat(),
            "maxBytes": _MAX_CHAT_MEDIA_BYTES,
        },
    )


@app.route(route="media/creation-upload-target", methods=["POST"])
def creation_upload_target(req: func.HttpRequest) -> func.HttpResponse:
    """Issue a short-lived block-blob SAS for authenticated creation uploads."""
    if not _ACCOUNT_NAME or not _ACCOUNT_KEY:
        return _json(503, {"error": "Media service is unavailable."})

    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})

    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})

    uid = str(decoded.get("uid", "")).strip()
    project_id = str(data.get("projectId", "")).strip()
    asset_id = str(data.get("assetId", "")).strip()
    blob_name = str(data.get("blobName", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()

    if not uid or not _SAFE_ID.fullmatch(uid):
        return _json(401, {"error": "Authentication required."})
    if not _SAFE_ID.fullmatch(project_id) or not _SAFE_ID.fullmatch(asset_id):
        return _json(400, {"error": "Invalid creation identifiers."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid file name."})
    if not isinstance(content_length, int) or content_length <= 0:
        return _json(400, {"error": "Invalid file size."})
    if content_length > _MAX_CREATION_VIDEO_BYTES:
        return _json(413, {"error": "Creation video exceeds the 512 MB upload limit."})
    if content_type not in _CREATION_VIDEO_TYPES:
        return _json(400, {"error": "Unsupported creation video type."})

    storage_path = _creation_blob_base(uid, project_id, asset_id)
    expiry = datetime.now(timezone.utc) + timedelta(minutes=_SAS_TTL_MINUTES)
    sas = generate_blob_sas(
        account_name=_ACCOUNT_NAME,
        container_name=_CONTAINER,
        blob_name=storage_path,
        account_key=_ACCOUNT_KEY,
        permission=BlobSasPermissions(create=True, write=True, read=False),
        expiry=expiry,
    )
    base = f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{storage_path}"
    return _json(
        200,
        {
            "uploadUrl": f"{base}?{sas}",
            "downloadUrl": base,
            "storagePath": storage_path,
            "expiresAt": expiry.isoformat(),
            "maxBytes": _MAX_CREATION_VIDEO_BYTES,
            "chunkSize": 8 * 1024 * 1024,
        },
    )


@app.route(route="media/creation-upload-complete", methods=["POST"])
def creation_upload_complete(req: func.HttpRequest) -> func.HttpResponse:
    """Validate and finalize a creation blob, then enqueue processing metadata."""
    if not _ACCOUNT_NAME or not _ACCOUNT_KEY:
        return _json(503, {"error": "Media service is unavailable."})

    decoded = _user_from_request(req)
    if decoded is None:
        return _json(401, {"error": "Authentication required."})

    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})

    uid = str(decoded.get("uid", "")).strip()
    project_id = str(data.get("projectId", "")).strip()
    asset_id = str(data.get("assetId", "")).strip()
    storage_path = str(data.get("storagePath", "")).strip()
    expected_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()

    expected_prefix = f"creation/{uid}/{project_id}/{asset_id}"
    if not _SAFE_ID.fullmatch(uid) or not _SAFE_ID.fullmatch(project_id) or not _SAFE_ID.fullmatch(asset_id):
        return _json(400, {"error": "Invalid creation identifiers."})
    if storage_path != expected_prefix or not isinstance(expected_length, int) or expected_length <= 0:
        return _json(400, {"error": "Invalid upload completion metadata."})
    if content_type not in _CREATION_VIDEO_TYPES:
        return _json(400, {"error": "Unsupported creation video type."})

    try:
        blob = _get_blob_client(storage_path)
        properties = blob.get_blob_properties()
        actual_length = int(properties.size)
        if actual_length != expected_length:
            return _json(409, {"error": "Uploaded video size does not match the creation manifest."})
        if actual_length <= 0 or actual_length > _MAX_CREATION_VIDEO_BYTES:
            return _json(413, {"error": "Uploaded video exceeds the allowed size."})
    except Exception:
        logging.exception("Creation upload finalization failed for %s", storage_path)
        return _json(409, {"error": "Uploaded video is not ready for finalization."})

    _record_creation_media(
        uid=uid,
        project_id=project_id,
        asset_id=asset_id,
        storage_path=storage_path,
        content_length=actual_length,
        content_type=content_type,
    )

    return _json(
        200,
        {
            "assetId": asset_id,
            "projectId": project_id,
            "storagePath": storage_path,
            "downloadUrl": f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{storage_path}",
            "processingStatus": "queued",
            "publishReady": False,
        },
    )
