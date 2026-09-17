# OJAS Azure Media + Notification Broker

This Azure Functions app provides authenticated media-broker capabilities for OJAS while keeping Azure storage credentials server-side.

## Existing chat image path

`POST media/upload-target` verifies the Firebase ID token, checks conversation membership, and returns a short-lived Azure Blob SAS URL for chat images. This contract remains backward-compatible.

## Creation video path

`POST media/creation-upload-target` authenticates the Firebase user and issues a short-lived block-blob SAS for one creation video. The client uploads independently in resumable 8 MiB blocks, so a weak connection can retry only the failed block.

`POST media/creation-upload-complete` validates ownership/path, verifies the final blob size, records a `creationMedia/{assetId}` processing record, and returns the canonical media URL. The processing record begins with `processingStatus: queued` and is the hand-off point for the future transcoding/moderation worker.

The current broker intentionally does **not** claim that it has transcoded to HLS/DASH or performed server-side moderation yet. Those require the processing worker contract and media-processing infrastructure to be deployed and verified first.

## Limits

- Chat image upload: 10 MB.
- Creation video upload: 512 MB.
- Creation upload SAS lifetime: 5 minutes.
- Creation chunk size: 8 MiB.

## Required Azure application settings

- `AZURE_STORAGE_ACCOUNT_NAME`
- `AZURE_STORAGE_ACCOUNT_KEY`
- `AZURE_STORAGE_CONTAINER`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

The Firebase service-account JSON must be stored as an Azure Function application setting or secret-backed configuration. Never commit it to GitHub or ship it inside the Flutter app.

The Flutter creation client is configured with:

```text
flutter build apk --dart-define=OJAS_AZURE_MEDIA_BROKER_URL=<endpoint>
```

When the broker URL is not configured, the existing Firebase Storage creation-video fallback remains available so the client does not break during staged rollout.
