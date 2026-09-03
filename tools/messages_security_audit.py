from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle}")


def main() -> None:
    rules = read("firestore.rules")
    functions = read("functions/src/index.ts")
    azure = read("azure_media_broker/function_app.py")
    azure_deploy = read(".github/workflows/deploy-azure-media-broker.yml")
    chat = read("lib/screens/chat_room_screen.dart")
    video = read("lib/services/video_engine_service.dart")
    notifications = read("lib/services/notification_service.dart")
    database = read("database.rules.json")

    require(rules, "allow read, write: if false;", "Firestore default deny")
    require(rules, "data.fcmTokens is map", "FCM token map validation")
    require(rules, "data.fcmTokens.size() <= 10", "FCM token cap")
    require(rules, "request.resource.data.text.size() <= 2000", "message size limit")
    require(rules, "request.resource.data.mediaBytes <= 10485760", "media size limit")
    require(rules, "request.resource.data.createdAt == request.time", "server timestamp validation")
    require(rules, "allow delete: if false;", "hard-delete protection")
    require(rules, "request.auth.uid in get(", "participant authorization")

    require(functions, "minInstances: 0", "function scale-to-zero")
    require(functions, "maxInstances: 3", "function max instance cap")
    require(functions, "MAX_MESSAGES_PER_INSTANCE_PER_MINUTE = 30", "push abuse guard")
    require(functions, "sendEachForMulticast", "FCM delivery")

    require(azure, "auth.verify_id_token", "Azure Firebase identity verification")
    require(azure, "maxUploadBytes", "Azure upload limit")
    require(azure, "idleNotificationPolling", "idle polling guard")
    if "timer_trigger" in azure:
        raise AssertionError("Azure media broker must not contain a timer trigger")

    require(azure_deploy, "FIREBASE_SERVICE_ACCOUNT_JSON", "Azure Firebase credential sync")
    require(azure_deploy, '"https://$HOST/api/health"', "live Azure health check")
    require(azure_deploy, "instanceMemoryMB=512", "Azure memory cap")
    require(azure_deploy, "maximumInstanceCount=5", "Azure instance cap")
    require(azure_deploy, "alwaysReady=[]", "Azure no always-ready instances")

    require(chat, "_maxInMemoryMessages = 400", "bounded chat memory")
    require(chat, "MessageMemoryWindow.takeNewest", "central memory window")
    require(chat, "memCacheWidth: 900", "chat image memory cache bound")
    require(chat, "maxWidthDiskCache: 1200", "chat image disk cache bound")

    if "downloadFile(url)" in video and "cacheVideoForOfflineUse" not in video:
        raise AssertionError("Video cache download must remain explicit, never automatic")
    require(video, "Prefetch disabled", "video prefetch disablement")

    require(notifications, "fcmTokens", "FCM token registration")
    if "arrayUnion" in notifications or "arrayRemove" in notifications:
        raise AssertionError("FCM tokens must remain a bounded map, not a growing array")

    require(database, '".read": false', "Realtime Database default read deny")
    require(database, '".write": false', "Realtime Database default write deny")

    print("OJAS Messages 2.3 security/cost static audit: PASS")


if __name__ == "__main__":
    main()
