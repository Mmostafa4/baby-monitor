# Experimental cry-analysis integration

The app now has a closed-preview inference path. It uses a pinned open-source DistilHuBERT classifier through the API described in backend/README.md; it does not claim that the classifier identifies a baby's actual need.

## Flow

1. The app records 10 seconds of mono, 16 kHz, signed 16-bit PCM and keeps it in memory.
2. The caregiver may listen or delete it locally. Pressing Analyze opens a one-time disclosure and consent choice.
3. Only after consent does the app obtain a temporary Firebase anonymous ID token and send the selected WAV to a configured HTTPS endpoint. No child profile fields are uploaded.
4. The backend verifies the Firebase token, validates the file format/duration/size, applies preview rate limits, and runs the pinned model on CPU.
5. The API returns the model's top-ranked known category with cautious Arabic guidance. It does not return a numeric score, diagnose an illness, or detect emergencies.
6. The app clears the recording from its memory after the request attempt. The backend does not persist the submitted audio.

The model supports hunger, belly pain, burping, discomfort, and tiredness. It has no dedicated output for a need for affection or a level of distress. The in-app result explains this limitation and keeps the caregiver checklist visible.

## What remains unavailable

This branch has no Firebase project, public HTTPS service, service-account secret, subscription verification, medical validation, or real-device test. The experimental button remains disabled until an HTTPS service address and public Firebase app values are supplied at build time. Firebase anonymous sign-in must be enabled in the project's Authentication settings.

The in-memory rate limiter is suitable only for a controlled preview. Before any broader trial, use server-side quotas, platform-level request limits, review provider retention, monitor cost, and test model performance on recordings from babies excluded from training. Do not use the result to diagnose illness or delay emergency care.
