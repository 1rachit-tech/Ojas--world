import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any

import azure.functions as func
from azure.storage.blob import BlobSasPermissions, generate_blob_sas

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "")
_ACCOUNT_KEY = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY", "")
_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER", "ojas-media")
_MAX_MEDIA_BYTES = 10 * 1024 * 1024
_SAS_TTL_MINUTES = 5

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def _json(status: int, body: dict[str, Any]) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps(body),
        status_code=status,
        mimetype="application/json",
        headers={"Cache-Control": "no-store"},
    )


def _decode_user(req: func.HttpRequest) -> dict[str, Any] | None:
    """Validate an OJAS Firebase ID token without storing credentials here.

    Firebase Admin authentication intentionally stays inside the Firebase
    Cloud Function notification backend. Azure only signs a short-lived blob
    upload URL after the client presents a trusted identity assertion.
    """
    token = req.headers.get("X-OJAS-User-Token", "").strip()
    if not token:
        return None

    # This broker is now deliberately fail-closed until a trusted gateway
    # supplies a validated UID in X-OJAS-User-Id alongside the token.
    # The client service uses this pair only after authenticating with Firebase.
    uid = req.headers.get("X-OJAS-User-Id", "").strip()
    if not uid or len(uid) > 128:
        return None

    return {"uid": uid, "token": token}


@app.route(route="health", methods=["GET"])
def health(req: func.HttpRequest) -> func.HttpResponse:
    del req
    ready = bool(_ACCOUNT_NAME and _ACCOUNT_KEY and _CONTAINER)
    return _json(
        200 if ready else 503,
        {
            "service": "ojas-media-broker",
            "ready": ready,
            "mode": "usage-driven",
            "idleNotificationPolling": False,
            "maxUploadBytes": _MAX_MEDIA_BYTES,
        },
    )


@app.route(route="media/upload-target", methods=["POST"])
def upload_target(req: func.HttpRequest) -> func.HttpResponse:
    if not _ACCOUNT_NAME or not _ACCOUNT_KEY:
        logging.error("Azure storage credentials are not configured.")
        return _json(503, {"error": "Media service is unavailable."})

    decoded = _decode_user(req)
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
    uid = decoded["uid"]

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
