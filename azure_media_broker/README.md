# OJAS Azure Media + Notification Broker

This Azure Functions app provides authenticated media-broker capabilities for OJAS while keeping Azure storage credentials server-side.

## Existing chat image path

`POST media/upload-target` verifies the Firebase ID token, checks conversation membership, and returns a short-lived Azure Blob SAS URL for chat images. This contract remains backward-compatible.

## Creation video path

`POST media/creation-upload-target` authenticates the Firebase user and issues a short-lived block-blob SAS for one creation video. The client uploads independently in resumable 8 MiB blocks, so a weak connection can retry only the failed block.

`POST media/creation-upload-complete` validates ownership/path, verifies the final blob size, records a `creationMedia/{assetId}` processing record, and returns the canonical media URL. The processing record begins with `processingStatus: queued` and is the hand-off point for the transcoding worker.

The broker itself does not transcode media. FFmpeg processing is performed by the separate low-cost queue worker.

## Creation audio path

Audio selected in the editor is uploaded through the authenticated Azure broker at publish time:

- `POST media/creation-audio-upload-target`
- `POST media/creation-audio-upload-complete`

The broker limits each audio asset to `10 MiB`, restricts supported audio MIME types, and scopes the blob to:

`creation-audio/{uid}/{projectId}/{layerId}/{fileName}`

The client stores only the Azure `storagePath` in the edit graph; the device's local filesystem path is never written to Firestore. The FFmpeg worker downloads the temporary audio from Azure, renders it into the output, and deletes the temporary audio asset after successful processing.

This creation-audio path intentionally does not use Firebase Storage, so it does not introduce a new Firebase Storage/Blaze dependency for the creation pipeline.

## Secure playback

`POST media/creation-playback-urls` returns short-lived read SAS URLs only after verifying:

- Firebase authentication;
- post existence and creator ownership;
- visibility (`public` or owner access);
- deletion state;
- Azure media provider and processing readiness;
- the processed/HLS storage path is inside the creator/project namespace;
- the target Blob exists.

The endpoint never returns the raw private source upload URL as the playback asset.

Current default playback is a processed progressive MP4. HLS generation exists in the worker but is disabled unless `OJAS_ENABLE_HLS=true` is explicitly enabled.

## Limits

- Chat image upload: 10 MB.
- Creation video upload: 512 MB.
- Creation audio asset: 10 MiB.
- Creation upload SAS lifetime: 5 minutes.
- Creation playback SAS lifetime: 15 minutes.
- Creation video chunk size: 8 MiB.

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

When the broker URL is not configured, the existing Firebase Storage creation-video fallback remains available for staged rollout. Creation audio editing requires the Azure broker because the audio path deliberately avoids Firebase Storage.
