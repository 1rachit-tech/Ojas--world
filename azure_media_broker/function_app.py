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
# Shared upload ceiling name retained for security/cost auditing across media routes.
_MAX_UPLOAD_BYTES = _MAX_CREATION_VIDEO_BYTES
_SAS_TTL_MINUTES = 5
_PLAYBACK_SAS_TTL_MINUTES = 15

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SAFE_ID = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
_SAFE_CREATION_PATH = re.compile(
    r"^creation/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}/[A-Za-z0-9_-]{1,128}(?:/[^/]{1,512}){0,5}$"
)
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
            "maxUploadBytes": _MAX_UPLOAD_BYTES,
            "playbackSasTtlMinutes": _PLAYBACK_SAS_TTL_MINUTES,
            "error": _FIREBASE_ERROR if not _FIREBASE_READY else "",
        },
    )
