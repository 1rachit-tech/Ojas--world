#!/usr/bin/env bash
set -euo pipefail

: "${AZURE_RG:?Set AZURE_RG}"
: "${AZURE_LOCATION:?Set AZURE_LOCATION, e.g. centralindia}"
: "${AZURE_STORAGE_ACCOUNT_NAME:?Set AZURE_STORAGE_ACCOUNT_NAME}"
: "${AZURE_STORAGE_CONNECTION_STRING:?Set AZURE_STORAGE_CONNECTION_STRING}"
: "${AZURE_STORAGE_QUEUE_CONNECTION_STRING:?Set AZURE_STORAGE_QUEUE_CONNECTION_STRING}"
: "${FIREBASE_SERVICE_ACCOUNT_JSON:?Set FIREBASE_SERVICE_ACCOUNT_JSON}"
: "${OJAS_WORKER_IMAGE:?Set OJAS_WORKER_IMAGE to a published worker image}"

ENV_NAME="${AZURE_CONTAINER_ENV_NAME:-ojas-media-env}"
JOB_NAME="${AZURE_MEDIA_JOB_NAME:-ojas-media-worker}"
QUEUE_NAME="ojas-media-processing"
CONTAINER_NAME="worker"

az containerapp env create \
  --name "$ENV_NAME" \
  --resource-group "$AZURE_RG" \
  --location "$AZURE_LOCATION"

az containerapp job create \
  --name "$JOB_NAME" \
  --resource-group "$AZURE_RG" \
  --environment "$ENV_NAME" \
  --trigger-type Event \
  --replica-timeout 1800 \
  --replica-retry-limit 1 \
  --replica-completion-count 1 \
  --parallelism 1 \
  --min-executions 0 \
  --max-executions 1 \
  --polling-interval 30 \
  --image "$OJAS_WORKER_IMAGE" \
  --cpu 1 \
  --memory 2Gi \
  --secrets \
    queue-connection="$AZURE_STORAGE_QUEUE_CONNECTION_STRING" \
    storage-connection="$AZURE_STORAGE_CONNECTION_STRING" \
    firebase-service-account="$FIREBASE_SERVICE_ACCOUNT_JSON" \
  --env-vars \
    AZURE_STORAGE_ACCOUNT_NAME="$AZURE_STORAGE_ACCOUNT_NAME" \
    AZURE_STORAGE_CONTAINER=ojas-media \
    AZURE_STORAGE_CONNECTION_STRING=secretref:storage-connection \
    AZURE_STORAGE_QUEUE_CONNECTION_STRING=secretref:queue-connection \
    FIREBASE_SERVICE_ACCOUNT_JSON=secretref:firebase-service-account \
    OJAS_ENABLE_HLS=false \
  --scale-rule-name media-queue \
  --scale-rule-type azure-queue \
  --scale-rule-metadata accountName="$AZURE_STORAGE_ACCOUNT_NAME" queueName="$QUEUE_NAME" queueLength=1 \
  --scale-rule-auth connection=queue-connection

echo "Created low-cost OJAS media worker job: $JOB_NAME"
echo "HLS is disabled by default. Set OJAS_ENABLE_HLS=true on the job later when needed."
