import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any

import azure.functions as func
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
import firebase_admin
from firebase_admin import auth, credentials, firestore

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "")
_ACCOUNT_KEY = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY", "")
_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER", "ojas-media")
_MAX_MEDIA_BYTES = 10 * 1024 * 1024
_SAS_TTL_MINUTES = 5

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
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


def _is_participant(uid: str, conversation_id: str) -> bool:
    if not _FIREBASE_READY:
        return False

    snapshot = (
        firestore.client()
        .collection("conversations")
        .document(conversation_id)
        .get()
    )
    if not snapshot.exists:
        return False

    data = snapshot.to_dict() or {}
    participants = data.get("participants", [])
    return isinstance(participants, list) and uid in participants


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
            "maxUploadBytes": _MAX_MEDIA_BYTES,
            "error": _FIREBASE_ERROR if not _FIREBASE_READY else "",
        },
    )


@app.route(route="media/upload-target", methods=["POST"])
def upload_target(req: func.HttpRequest) -> func.HttpResponse:
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
        or content_length > _MAX_MEDIA_BYTES
    ):
        return _json(400, {"error": "Invalid file size."})
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        return _json(400, {"error": "Unsupported media type."})
    if not _is_participant(uid, conversation_id):
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
            "maxBytes": _MAX_MEDIA_BYTES,
        },
    )
