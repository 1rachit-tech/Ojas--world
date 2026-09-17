# OJAS low-cost FFmpeg media worker

This worker is the server-side processing stage for OJAS creation videos.

## Default cost-saving mode

The default mode is `OJAS_ENABLE_HLS=false`.

For every queued creation video the worker:

1. downloads the private source Blob to ephemeral job storage;
2. validates the media with `ffprobe`;
3. applies the bounded edit graph (trim/split order, speed, rotation, text/captions and lightweight effects);
4. optionally mixes creator-selected audio tracks temporarily staged in Azure Blob Storage;
5. transcodes one 720p-max H.264/AAC MP4 with `ffmpeg`;
6. creates one JPEG thumbnail;
7. writes authoritative processing metadata to Firestore;
8. removes temporary Azure audio assets after successful processing;
9. removes the queue message only after successful processing.

This deliberately avoids multiple renditions, always-on servers, and mandatory HLS segment storage during the low-traffic launch stage.

Set `OJAS_ENABLE_HLS=true` later when HLS delivery is worth the extra CPU/storage cost. The code already contains the HLS generation path, but HLS is **not active by default**.

## Audio staging contract

The Flutter editor uses the native audio picker and keeps the selected file local during editing. At publish time, each audio layer is copied through the existing authenticated Azure media broker to:

`creation-audio/{uid}/{projectId}/{layerId}/{fileName}`

The Firestore edit graph stores the Azure `storagePath`, never the device's local filesystem path. The worker retrieves that temporary Azure Blob with server-side storage credentials, mixes it into the render, then deletes the temporary audio asset after successful processing.

Audio limits:

- Maximum audio layers per edit graph: `32`
- Maximum size per audio asset: `10 MiB`
- Supported audio types: MP3, M4A/MP4 audio, WAV, AAC, OGG, OPUS
- Storage path is owner/project scoped
- Audio is temporary and is deleted after successful rendering or post deletion

This creation-audio path intentionally does **not** use Firebase Storage, so the feature does not introduce a new Firebase Storage/Blaze dependency. Existing Firebase Storage usage elsewhere in the app is a separate concern.

## Runtime contract

The worker is designed for an Azure Container Apps **Event Job** using the `ojas-media-processing` Azure Storage Queue. Container Apps Jobs are finite executions and can remain at zero executions between jobs. Microsoft documents Event jobs specifically for queue-driven processing workloads. citehttps://learn.microsoft.com/en-us/azure/container-apps/jobs

Required secrets/environment variables:

- `AZURE_STORAGE_ACCOUNT_NAME`
- `AZURE_STORAGE_CONTAINER` (default `ojas-media`)
- `AZURE_STORAGE_CONNECTION_STRING`
- `AZURE_STORAGE_QUEUE_CONNECTION_STRING`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `OJAS_ENABLE_HLS=false`

Keep all secrets in Azure/Firebase configuration only. Never commit them.

## Firebase trigger

The `enqueueCreationMediaProcessing` Firebase function watches `creationMedia/{assetId}` and puts a small JSON job on the Azure Storage Queue. The Firebase secret name is:

`AZURE_STORAGE_QUEUE_CONNECTION_STRING`

Configure it before deploying Functions:

```bash
firebase functions:secrets:set AZURE_STORAGE_QUEUE_CONNECTION_STRING --project ojas-e8161
```

## Post deletion cleanup

A Firestore lifecycle trigger queues `creation-media-cleanup` when an Azure-backed Show is deleted. The same Event Job removes the processed source/output tree and the temporary `creation-audio/{uid}/{projectId}/...` tree. Cleanup runs on demand; there is no always-on janitor service.

## Low-cost Container Apps job

Use an Event job with:

- CPU: `1`
- Memory: `2Gi`
- Parallelism: `1`
- Minimum executions: `0`
- Maximum executions: `1` initially
- Replica timeout: `1800` seconds
- Retry limit: `1`
- HLS: disabled

The queue scaler should use the `ojas-media-processing` queue and a queue length of `1` as the activation threshold.

The Container Apps consumption model includes a monthly free grant and charges active compute by usage; jobs have no usage charge while no execution is running. Azure Storage Blob/Queue storage, operations, and data transfer are separate meters, so storage size and playback bandwidth should still be watched. citehttps://azure.microsoft.com/en-us/pricing/details/container-apps/ citehttps://azure.microsoft.com/en-us/pricing/details/storage/queues/ citehttps://azure.microsoft.com/en-ca/pricing/details/storage/blobs/

## Build locally

```bash
docker build -t ghcr.io/1rachit-tech/ojas-media-worker:latest azure_media_worker
```

The container contains FFmpeg, DejaVu fonts and the Python worker only. No long-running HTTP server is required.
