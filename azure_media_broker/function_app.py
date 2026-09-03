import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any

import azure.functions as func
from azure.storage.blob import BlobSasPermissions, generate_blob_sas
import firebase_admin
from firebase_admin import auth, credentials, firestore, messaging

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME", "")
_ACCOUNT_KEY = os.environ.get("AZURE_STORAGE_ACCOUNT_KEY", "")
_CONTAINER = os.environ.get("AZURE_STORAGE_CONTAINER", "ojas-media")
_PUSH_LOOKBACK_MINUTES = 2
_PUSH_BATCH_LIMIT = 100
_PUSH_CLAIM_TTL_MINUTES = 2

if not firebase_admin._apps:
    firebase_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if firebase_json:
        firebase_admin.initialize_app(credentials.Certificate(json.loads(firebase_json)))
    else:
        firebase_admin.initialize_app()

_SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_INVALID_FCM_CODES = {
    "UNREGISTERED",
    "SENDER_ID_MISMATCH",
}


def _json(status: int, body: dict[str, Any]) -> func.HttpResponse:
    return func.HttpResponse(
        json.dumps(body),
        status_code=status,
        mimetype="application/json",
        headers={"Cache-Control": "no-store"},
    )


def _user_from_request(req: func.HttpRequest) -> dict[str, Any] | None:
    authorization = req.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        return None
    try:
        return auth.verify_id_token(authorization[7:])
    except Exception:
        return None


def _is_participant(uid: str, conversation_id: str) -> bool:
    db = firestore.client()
    snapshot = db.collection("conversations").document(conversation_id).get()
    if not snapshot.exists:
        return False
    data = snapshot.to_dict() or {}
    participants = data.get("participants", [])
    return isinstance(participants, list) and uid in participants


def _claim_message(message_ref: Any) -> bool:
    db = firestore.client()
    transaction = db.transaction()
    now = datetime.now(timezone.utc)
    stale_before = now - timedelta(minutes=_PUSH_CLAIM_TTL_MINUTES)

    @firestore.transactional
    def claim(tx: Any) -> bool:
        snapshot = tx.get(message_ref)
        if not snapshot.exists:
            return False

        data = snapshot.to_dict() or {}
        if data.get("pushSentAt") is not None:
            return False

        claimed_at = data.get("pushClaimedAt")
        if claimed_at is not None:
            try:
                claimed_datetime = claimed_at.replace(tzinfo=timezone.utc) if claimed_at.tzinfo is None else claimed_at
                if claimed_datetime > stale_before:
                    return False
            except Exception:
                pass

        tx.update(
            message_ref,
            {
                "pushClaimedAt": now,
            },
        )
        return True

    try:
        return claim(transaction)
    except Exception:
        logging.exception("Failed to claim message notification.")
        return False


def _clear_claim(message_ref: Any) -> None:
    try:
        message_ref.update(
            {
                "pushClaimedAt": firestore.DELETE_FIELD,
            },
        )
    except Exception:
        logging.exception("Failed to clear message notification claim.")


def _send_fcm_for_message(message_ref: Any, message_data: dict[str, Any]) -> bool:
    db = firestore.client()
    conversation_ref = message_ref.parent.parent
    if conversation_ref is None:
        return False

    conversation_snapshot = conversation_ref.get()
    if not conversation_snapshot.exists:
        return False

    conversation = conversation_snapshot.to_dict() or {}
    participants = conversation.get("participants", [])
    sender_id = message_data.get("senderId")
    if not isinstance(participants, list) or len(participants) != 2:
        return False
    if not isinstance(sender_id, str) or sender_id not in participants:
        return False

    receiver_id = next((uid for uid in participants if uid != sender_id), None)
    if not isinstance(receiver_id, str) or not receiver_id:
        return False

    user_snapshot = db.collection("users").document(receiver_id).get()
    if not user_snapshot.exists:
        return True

    user_data = user_snapshot.to_dict() or {}
    raw_tokens = user_data.get("fcmTokens", {})
    if not isinstance(raw_tokens, dict):
        return True

    tokens = [
        token
        for token in raw_tokens.keys()
        if isinstance(token, str) and token.strip()
    ]
    if not tokens:
        return True

    profiles = conversation.get("participantProfiles", {})
    sender_profile = profiles.get(sender_id, {}) if isinstance(profiles, dict) else {}
    sender_name = "OJAS"
    if isinstance(sender_profile, dict):
        candidate = str(sender_profile.get("displayName", "")).strip()
        if candidate:
            sender_name = candidate[:80]

    message_type = str(message_data.get("type", "text"))
    text = str(message_data.get("text", "")).strip()
    body = text if text else ("📷 Photo" if message_type == "image" else "New message")
    body = body[:300]

    fcm_message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(
            title=sender_name,
            body=body,
        ),
        data={
            "type": "message",
            "conversationId": conversation_ref.id,
            "messageId": message_ref.id,
            "senderId": sender_id,
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound="default",
                    badge=1,
                ),
            ),
        ),
    )

    try:
        response = messaging.send_each_for_multicast(fcm_message)
    except Exception:
        logging.exception("FCM send failed for message %s.", message_ref.id)
        return False

    invalid_tokens: list[str] = []
    success_count = 0
    for token, send_response in zip(tokens, response.responses):
        if send_response.success:
            success_count += 1
            continue
        exception = send_response.exception
        code = getattr(exception, "code", "")
        if isinstance(code, str) and code.upper() in _INVALID_FCM_CODES:
            invalid_tokens.append(token)
        else:
            logging.warning(
                "FCM delivery failed for %s: %s",
                token[-8:],
                exception,
            )

    if invalid_tokens:
        cleanup: dict[str, Any] = {}
        for token in invalid_tokens:
            cleanup[f"fcmTokens.{token}"] = firestore.DELETE_FIELD
        try:
            db.collection("users").document(receiver_id).update(cleanup)
        except Exception:
            logging.exception("Failed to clean invalid FCM tokens for %s.", receiver_id)

    # We consider the notification handled when FCM accepted at least one
    # target, or when the recipient has no usable tokens. A transient failure
    # with every target remains retryable on the next timer tick.
    if success_count > 0 or not tokens:
        message_ref.update(
            {
                "pushSentAt": firestore.SERVER_TIMESTAMP,
                "pushClaimedAt": firestore.DELETE_FIELD,
            },
        )
        return True

    return False


def _process_pending_message_notifications() -> None:
    db = firestore.client()
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=_PUSH_LOOKBACK_MINUTES)

    query = (
        db.collection_group("messages")
        .where("createdAt", ">=", cutoff)
        .order_by("createdAt", direction=firestore.Query.ASCENDING)
        .limit(_PUSH_BATCH_LIMIT)
    )

    processed = 0
    for snapshot in query.stream():
        data = snapshot.to_dict() or {}
        if data.get("pushSentAt") is not None:
            continue
        created_at = data.get("createdAt")
        if created_at is None:
            continue
        if not _claim_message(snapshot.reference):
            continue
        try:
            if _send_fcm_for_message(snapshot.reference, data):
                processed += 1
            else:
                _clear_claim(snapshot.reference)
        except Exception:
            logging.exception("Unhandled notification error for message %s.", snapshot.id)
            _clear_claim(snapshot.reference)

    logging.info("Azure notification relay processed %s message(s).", processed)


@app.timer_trigger(
    schedule="0 * * * * *",
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
def relay_pending_message_notifications(timer: func.TimerRequest) -> None:
    if timer.past_due:
        logging.warning("Message notification relay timer is running late.")
    _process_pending_message_notifications()


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

    if not conversation_id or len(conversation_id) > 128:
        return _json(400, {"error": "Invalid conversation."})
    if not _SAFE_NAME.fullmatch(blob_name):
        return _json(400, {"error": "Invalid file name."})
    if not isinstance(content_length, int) or content_length <= 0 or content_length > 10 * 1024 * 1024:
        return _json(400, {"error": "Invalid file size."})
    if content_type not in {"image/jpeg", "image/png", "image/webp"}:
        return _json(400, {"error": "Unsupported media type."})

    uid = decoded["uid"]
    if not _is_participant(uid, conversation_id):
        return _json(403, {"error": "You are not allowed to upload to this conversation."})

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
    )

    base = f"https://{_ACCOUNT_NAME}.blob.core.windows.net/{_CONTAINER}/{blob_path}"
    return _json(200, {
        "uploadUrl": f"{base}?{sas}",
        "downloadUrl": base,
        "storagePath": blob_path,
        "headers": {"x-ms-version": "2023-11-03"},
        "expiresAt": expiry.isoformat(),
    })
