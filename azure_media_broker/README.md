# OJAS Azure Media Broker

This function verifies the caller's Firebase ID token and creates a short-lived,
single-blob Azure SAS upload URL. Never put the Azure connection string in the
Flutter app.

Required application settings:

- AZURE_STORAGE_ACCOUNT_NAME
- AZURE_STORAGE_ACCOUNT_KEY
- AZURE_STORAGE_CONTAINER
- FIREBASE_SERVICE_ACCOUNT_JSON

The public function endpoint is the value passed to Flutter with:

flutter build apk --dart-define=OJAS_AZURE_MEDIA_BROKER_URL=<endpoint>
