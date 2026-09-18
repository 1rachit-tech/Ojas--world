import { DefaultAzureCredential } from "@azure/identity";
import { app, type InvocationContext } from "@azure/functions";
import { BlobServiceClient } from "@azure/storage-blob";
import { config } from "./config";

let credential: DefaultAzureCredential | null = null;
let blobService: BlobServiceClient | null = null;

function blobClient(): BlobServiceClient {
  if (blobService) return blobService;

  if (!config.eventArchiveStorageAccountUrl) {
    throw new Error("SEARCH_EVENT_ARCHIVE_STORAGE_URL is not configured.");
  }

  credential ??= new DefaultAzureCredential();
  blobService = new BlobServiceClient(
    config.eventArchiveStorageAccountUrl,
    credential,
  );
  return blobService;
}

function safeFilePart(value: string): string {
  return value.replace(/[^a-zA-Z0-9._-]/g, "_");
}

export async function archiveSearchEvent(
  message: unknown,
  context: InvocationContext,
): Promise<void> {
  if (!config.eventArchiveStorageAccountUrl) {
    context.info("Search event archive is disabled.");
    return;
  }

  const now = new Date();
  const payload = {
    receivedAt: now.toISOString(),
    event: message,
  };

  const container = blobClient().getContainerClient(
    config.eventArchiveContainer,
  );

  await container.createIfNotExists();

  const day = now.toISOString().slice(0, 10);
  const id =
    context.invocationId + "-" + safeFilePart(String(Math.random()));
  const blob = container.getBlockBlobClient(
    day + "/" + id + ".json",
  );

  const body = Buffer.from(
    JSON.stringify(payload),
    "utf8",
  );

  await blob.uploadData(body, {
    blobHTTPHeaders: {
      blobContentType: "application/json",
    },
  });
}

app.serviceBusQueue("searchAnalyticsArchive", {
  connection: "SEARCH_SERVICE_BUS_CONNECTION",
  queueName: config.analyticsQueue,
  handler: archiveSearchEvent,
});
