# Secure cry-analysis integration

The app must not contain an AI secret, model key, or medical decision logic. The intended flow is:

1. The app records exactly 10 seconds of mono 16 kHz AAC audio.
2. The app sends the file over TLS to an authenticated backend using a short-lived upload token.
3. The backend validates file type, duration, size, user entitlement, and rate limits.
4. The backend runs a validated model and returns only a probabilistic result:

```json
{
  "category": "sleepiness",
  "confidence": 0.68,
  "advice": "Try calming the baby and reducing stimulation.",
  "urgent": false
}
```

5. Raw recordings should be deleted by default. Do not use the result to diagnose illness or delay emergency care.

The `CryRecordingService` is the mobile capture layer. A production backend still requires consent, privacy controls, signed requests, monitoring, model validation, clinical review, and testing across languages, ages, environments, and devices.
