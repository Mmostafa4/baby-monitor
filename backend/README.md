# Baby Monitor backend

This directory defines the production boundary for the app. It intentionally does **not** include a fake medical model or API secrets.

## Required endpoint

`POST /v1/cry-analysis`

- Authentication: `Authorization: Bearer <short-lived access token>`
- Multipart field: `audio`
- Server checks: authenticated user, active trial/subscription, MIME type, max size, mono/16 kHz audio, and duration of exactly 10 seconds (with a small tolerance).
- Response is probabilistic and non-diagnostic:

```json
{
  "category": "sleepiness",
  "confidence": 0.68,
  "advice": "Try calming the baby and reducing stimulation.",
  "urgent": false
}
```

## Production requirements

- Use HTTPS only and reject cleartext traffic.
- Store raw audio temporarily, encrypt it, and delete it after inference.
- Rate-limit analysis requests per account/device/IP.
- Verify the 7-day trial and store subscriptions on the server; never trust a client flag.
- Verify Google Play/App Store purchase tokens on the server.
- Keep model credentials and payment credentials in secret storage.
- Log request IDs and security events, not raw audio or child data.
- Have a medical/safety review before enabling any user-facing classifier.

Until a validated model is deployed, the mobile app must show an unavailable state rather than inventing a result.
