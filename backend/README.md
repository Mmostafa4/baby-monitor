# Experimental cry-analysis preview

This service runs a real open-source audio classifier for a closed test. It is not a medical device, has not been validated on new babies or home recordings, and is not ready for public release. The repository does not contain a deployed service URL or Firebase project configuration; without those build values, the app keeps analysis disabled.

## Model and result meaning

The service downloads the pinned AmeerHesham/distilhubert-finetuned-baby_cry model from Hugging Face when it starts. Its top-ranked output is returned without a numeric confidence score. The score is not calibrated, and the result is only a best-effort guess among the model's labels.

The model labels are hunger, belly pain, burping, general discomfort, and tiredness. They do not include a dedicated class for needing affection or for distress. Belly pain is not a diagnosis of colic, burping is not a diagnosis of gas, and tiredness is not a measure of distress. Unknown labels return unclear.

The model card describes training on the user-tagged Donate-a-Cry dataset, synthetic minority oversampling before a random 80/20 train/test split, and limitations across microphones and acoustic environments. This evaluation does not establish generalization to a new child. The audio labels may not reflect a medically confirmed cause.

See [MODEL_NOTICE.md](MODEL_NOTICE.md) for model and training-data notices. The service downloads the weights at startup from the pinned repository revision; it does not copy the training recordings into this repository.

## Privacy and API behavior

- Recording stays on the device unless the caregiver chooses Analyze and approves that specific upload.
- The app sends only the selected 10-second WAV over HTTPS. It does not send the local child profile.
- The service buffers at most 400 KB of uploaded audio (plus bounded multipart overhead) in memory and accepts no more than two concurrent analysis requests. It runs inference without writing submitted audio to a database, file, or request-body log. Audio is not used for training.
- Authentication uses a Firebase anonymous account and a short-lived Firebase ID token. The server validates the token; the app contains no Firebase service-account key or model secret.
- The container has no persistent volume. Its /tmp is a memory-backed filesystem for temporary model downloads. A hosting provider or TLS proxy may still retain ordinary connection metadata; review its terms before sending real recordings.
- The app erases its in-memory recording after an analysis attempt. The server returns urgent=false; it does not detect emergencies.
- In-memory limits are 20 requests per Firebase user and 100 requests total per hour per service process. These reset when the process restarts and are not production-grade billing protection.
- There is no subscription or trial entitlement check. Do not expose this preview publicly or use it for paid access.

## Run the service locally

Requirements: Docker with Compose, an internet connection for the initial model download, a Firebase project, and a Firebase Admin service-account key. Do not commit the key.

1. In Firebase Console, enable Authentication → Anonymous and register the Android and iOS app identifiers.
2. Copy .env.example to .env and set FIREBASE_PROJECT_ID.
3. For local Docker Compose, place the Firebase Admin JSON key at backend/secrets/firebase-service-account.json. For Railway, set the full Admin JSON in the FIREBASE_SERVICE_ACCOUNT_JSON service variable and mark it as a secret. Never commit or send the key.
4. From backend/, run docker compose up --build. Model loading may take several minutes. The container listens only on 127.0.0.1:8000.
5. Check http://127.0.0.1:8000/v1/health. A local HTTP endpoint is for health inspection only; the mobile app refuses to upload to anything except HTTPS.

The container needs enough memory for PyTorch and the model; allow at least 2 GB RAM for a CPU preview. For phone testing, deploy it behind an HTTPS reverse proxy and review the hosting provider's data-retention settings first. No backend has been deployed for this repository yet.

## Configure an app build

Use the public Firebase app values from the Firebase project and the HTTPS URL of the deployed endpoint. Each platform needs its own Firebase app ID. These values identify the Firebase app and are not the Firebase Admin service-account key. For GitHub Actions phone builds, add the variables listed in [preview setup](../docs/preview-setup.md).

    flutter build apk --release --dart-define=BABY_MONITOR_API_ENDPOINT=https://YOUR-HOST/v1/cry-analysis --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_ANDROID_FIREBASE_APP_ID --dart-define=FIREBASE_IOS_APP_ID=YOUR_IOS_FIREBASE_APP_ID --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_SENDER_ID --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID

Use the same defines with flutter build ios --release. The app asks for consent separately before each upload. With any required configuration missing, recording/playback/deletion still work and analysis stays disabled.

## Endpoints

- GET /v1/health: model readiness only; contains no account or audio data.
- POST /v1/cry-analysis: authenticated multipart upload using field audio, mono 16 kHz 16-bit PCM WAV, 9.5–10.5 seconds, maximum 400 KB.

Run format checks with python -m unittest discover -s tests -v from this directory. GitHub Actions also builds the CPU container image. A successful image build does not prove model accuracy or a deployed service.
