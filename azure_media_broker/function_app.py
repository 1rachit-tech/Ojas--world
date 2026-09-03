import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone

import azure.functions as func
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
import firebase_admin
from firebase_admin import auth, credentials

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "")
_ACCOUNT_KEY = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY", "")
_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER", "ojas-media")

if not firebase_admin._apps:
    firebase_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if firebase_json:
        firebase_admin.initialize_app(
            credentials.Certificate(json.loads(firebase_json))
        )
    else:
        firebase_admin.initialize_app()

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


def _json(status, body):
    return func.HttpResponse(
        json.dumps(body),
        status_code=status,
        mimetype="application/json",
        headers={"Cache-Control": "no-store"},
    )


@app.route(route="media/upload-target", methods=["POST"])
def upload_target(req: func.HttpRequest) -> func.HttpResponse:
    if not _ACCOUNT_NAME or not _ACCOUNT_KEY:
        logging.error("Azure storage credentials are not configured.")
        return _json(503, {"error": "Media service is unavailable."})

    authorization = req.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        return _json(401, {"error": "Authentication required."})

    try:
        decoded = auth.verify_id_token(authorization[7:])
    except Exception:
        return _json(401, {"error": "Invalid authentication token."})

    try:
        data = req.get_json()
    except ValueError:
        return _json(400, {"error": "Invalid JSON."})

    conversation_id = str(data.get("conversationId", "")).strip()
    blob_name = str(data.get("blobName", "")).strip()
    content_length = data.get("contentLength")
    content_type = str(data.get("contentType", "")).strip().lower()

    if not conversation_id or len(conversation_id) > 128:
        return _json(400, {"error": "Invalid conversation."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid file name."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > 10 * 1024 * 1024:
        return _json(400, {"error": "Invalid file size."})
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        return _json(400, {"error": "Unsupported media type."})

    uid = decoded["uid"]
    safe_conversation = re.sub(r"[^A-Za-z0-9_-]", "_", conversation_id)
    blob_path = f"chat_media/{safe_conversation}/images/{uid}/{blob_name}"

    expiry = datetime.now(timezone.utc) + timedelta(minutes=5)
    sas = generate_blob_sas(
        account_name=_ACCOUNT_NAME,
        container_name=_CONTAINER,
        blob_name=blob_path,
        account_key=_ACCOUNT_KEY,
        permission=BlobSasPermissions(create=True, write=True),
        expiry=expiry,
        content_type=content_type,
    )

    base = f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{blob_path}"
    return _json(200, {
        "uploadUrl": f"{base}?{sas}",
        "downloadUrl": base,
        "storagePath": blob_path,
        "headers": {"x-ms-version": "2023-11-03"},
        "expiresAt": expiry.isoformat(),
    })
