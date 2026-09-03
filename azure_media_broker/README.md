# OJAS Azure Media + Notification Broker

This Azure Functions app hosts two server-side paths:

1. `media/upload-target` verifies the caller's Firebase ID token and creates a short-lived Azure Blob SAS upload URL. Never put Azure storage credentials in the Flutter app.
2. `relay_pending_message_notifications` runs every minute and checks the recent Firestore `messages` collection group for messages that have not yet been handled for push delivery. It sends the notification through Firebase Cloud Messaging using the Firebase Admin SDK, then records `pushSentAt` on the message. Azure is the execution environment; Firebase is used only for Auth, Firestore, and FCM.

Required Azure application settings:

- `AZURE_STORAGE_ACCOUNT_NAME`
- `AZURE_STORAGE_ACCOUNT_KEY`
- `AZURE_STORAGE_CONTAINER`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

The Firebase service-account JSON must be stored as an Azure Function application setting or secret-backed configuration. Never commit it to GitHub or ship it inside the Flutter app.

The existing media endpoint is passed to Flutter with:

```text
flutter build apk --dart-define=OJAS_AZURE_MEDIA_BROKER_URL=<endpoint>
```

Notification behavior:

- The relay intentionally uses a two-minute lookback to tolerate timer delays and restarts.
- Each message is transactionally claimed before sending to avoid concurrent duplicate processing.
- Invalid/unregistered FCM registration tokens are removed from `users/{uid}.fcmTokens`.
- The current client stores FCM registration tokens; Firebase's current Admin SDK documentation recommends migrating toward Firebase Installation IDs (FIDs) over time. Existing tokens continue to be supported during the migration period.
- The timer does not run at application startup, so deployments/restarts do not immediately send a second push.

The relay is server-side and does not change the existing Firestore message write path, so normal text, image, unread, delivery, seen, reply, reaction, and pagination behavior remains unchanged.
