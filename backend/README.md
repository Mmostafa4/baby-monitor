# Experimental cry-analysis preview

This service runs a real open-source audio classifier for a closed test and can optionally proxy a protected Arabic newborn Q&A request to an OpenAI-compatible text-model endpoint. It is not a medical device, has not been validated on new babies or home recordings, and is not ready for public release. The repository does not contain a deployed service URL, Firebase project configuration, or text-model credentials; without those build values, the app keeps the relevant feature disabled.

## Model and result meaning

The service downloads the pinned AmeerHesham/distilhubert-finetuned-baby_cry model from Hugging Face when it starts. It returns the top-ranked category and the corresponding softmax output as `score_percent` (0–100). That number is an uncalibrated model score, not the probability that the baby is hungry, in pain, or has any medical condition. It is not a measured accuracy percentage. The result is a best-effort guess among the model's labels.

The model labels are hunger, belly pain, burping, general discomfort, and tiredness. They do not include a dedicated class for needing affection or for distress. Belly pain is not a diagnosis of colic, burping is not a diagnosis of gas, and tiredness is not a measure of distress. Unknown labels return unclear.

The model card describes training on the user-tagged Donate-a-Cry dataset, synthetic minority oversampling before a random 80/20 train/test split, and limitations across microphones and acoustic environments. This evaluation does not establish generalization to a new child. The audio labels may not reflect a medically confirmed cause.

See [MODEL_NOTICE.md](MODEL_NOTICE.md) for model and training-data notices. The service downloads the weights at startup from the pinned repository revision; it does not copy the training recordings into this repository.

## Privacy and API behavior

- Recording stays on the device unless the caregiver chooses Analyze and approves that specific upload.
- The app sends only the selected 10-second WAV over HTTPS. It does not send the local child profile.
- The service buffers at most 400 KB of uploaded audio (plus bounded multipart overhead) in memory and accepts no more than two concurrent analysis requests. It runs inference without writing submitted audio to a database, file, or request-body log. Audio is not used for training.
- The API rejects empty, silent, or near-silent PCM audio before model inference and asks the caregiver to record again. This is only a microphone signal-quality gate; it is not a cry detector and it does not measure vital signs.
- Authentication uses a Firebase anonymous account and a short-lived Firebase ID token. The server validates the token; the app contains no Firebase service-account key or model secret.
- The container has no persistent volume. Its /tmp is a memory-backed filesystem for temporary model downloads. A hosting provider or TLS proxy may still retain ordinary connection metadata; review its terms before sending real recordings.
- The app erases its in-memory recording after an analysis attempt. The server returns urgent=false; it does not detect emergencies.
- In-memory limits are 20 requests per Firebase user and 100 requests total per hour per service process. These reset when the process restarts and are not production-grade billing protection.
- Newborn Q&A accepts at most 900 characters, does not persist the question or answer, and uses a server-side provider key. Obvious emergency and medication-dose questions are answered by a fixed safety response before any provider call. The endpoint is still educational and requires medical/privacy review.
- There is no subscription or trial entitlement check. Do not expose this preview publicly or use it for paid access.

## Private iPhone Safari beta

The root Railway image also builds and serves the Flutter web app at `/app/`. Open the service root in Safari, enter the closed-beta invite code, then use Share → Add to Home Screen. The login endpoint sets a secure, HTTP-only, same-origin cookie; `BETA_ACCESS_KEY` must be configured as a Railway service secret. The API accepts that cookie only for this private preview, rate-limits the shared tester, and also supports Firebase ID tokens for native builds. Do not put the invite code in the repository or a Flutter build define.

The web app derives its API endpoint from its HTTPS origin. It uses the login cookie for analysis, so no Firebase web app registration is required. Location, profile, daily logs, and vaccine checkmarks remain in the browser's local storage.

## Run the service locally

Requirements: Docker with Compose and an internet connection for the initial model download. Firebase is required only for native Android/iOS authentication; the Railway Safari beta uses `BETA_ACCESS_KEY`.

1. Copy .env.example to .env. Set `BETA_ACCESS_KEY` to a long random invite code for a private web test. Keep the real value out of Git.
2. If testing native builds, also set `FIREBASE_PROJECT_ID` and configure Firebase anonymous sign-in. Store the Firebase Admin JSON key at `backend/secrets/firebase-service-account.json` locally, or as a Railway secret named `FIREBASE_SERVICE_ACCOUNT_JSON`. Never commit or send the key.
3. To enable newborn Q&A, set `BABY_MONITOR_AI_API_URL`, `BABY_MONITOR_AI_API_KEY`, and `BABY_MONITOR_AI_MODEL` in the host secret manager. The URL must be HTTPS and accept an OpenAI-compatible chat-completions JSON request.
4. From backend/, run `docker compose up --build`. Model loading may take several minutes.
5. Check `http://127.0.0.1:8000/v1/health`. The private app requires HTTPS because microphone recording and location access are browser secure-context features.

The container needs enough memory for PyTorch and the model; allow at least 2 GB RAM for a CPU preview. For phone testing, deploy it behind an HTTPS reverse proxy and review the hosting provider's data-retention settings first. No backend has been deployed for this repository yet.

## Configure an app build

Use the public Firebase app values from the Firebase project and the HTTPS URL of the deployed endpoint. Each platform needs its own Firebase app ID. These values identify the Firebase app and are not the Firebase Admin service-account key. For GitHub Actions phone builds, add the variables listed in [preview setup](../docs/preview-setup.md).

    flutter build apk --release --dart-define=BABY_MONITOR_API_ENDPOINT=https://YOUR-HOST/v1/cry-analysis --dart-define=BABY_MONITOR_AI_ENDPOINT=https://YOUR-HOST/v1/newborn-assistant --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY --dart-define=FIREBASE_ANDROID_APP_ID=YOUR_ANDROID_FIREBASE_APP_ID --dart-define=FIREBASE_IOS_APP_ID=YOUR_IOS_FIREBASE_APP_ID --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_FIREBASE_SENDER_ID --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID

Use the same defines with flutter build ios --release. The app asks for consent separately before each upload. With any required configuration missing, recording/playback/deletion still work and analysis stays disabled.

## Endpoints

- GET /v1/health: returns `model_ready` for the cry model, `assistant_configured` for the optional text-model provider, and `assistant_available`/`assistant_mode` for the newborn assistant. When the provider secret is absent, or the provider is temporarily unavailable/quota-limited, the beta uses a conservative local guidance fallback instead of dropping every question.
- POST /v1/cry-analysis: authenticated multipart upload using field audio, mono 16 kHz 16-bit PCM WAV, 9.5–10.5 seconds, maximum 400 KB. Silent or near-silent audio is rejected before inference. Returns `category`, `advice`, `score_percent`, and `experimental`.
- POST /v1/newborn-assistant: authenticated JSON with a `question` of 3–900 characters. Returns a general Arabic `answer`; it does not receive the local child profile or audio.
- GET `/call-demo` and WebSocket `/v1/demo-call/ws`: authenticated, in-memory two-device WebRTC audio prototype for testing the future doctor-call flow. The doctor must enter a two-part/display name, choose `أخصائي` or `استشاري`, and accept the no-contact-exchange policy before going online. The page has a session report action that immediately ends the demo session and suspends the current doctor session. It does not collect payments, persist doctor profiles, record calls, or provide a real medical consultation. The prototype cannot know whether phone numbers were spoken aloud because audio is not recorded or transcribed.

Run format checks with python -m unittest discover -s tests -v from this directory. GitHub Actions also builds the CPU container image. A successful image build does not prove model accuracy or a deployed service.
