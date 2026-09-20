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

## Newborn question-and-answer service

The public app includes a question screen and this Worker scaffold. The screen remains visibly disconnected until a Worker URL is supplied at build time; it does not call a model directly from the browser.

### Deploy the Worker

The Worker is in `backend/newborn-assistant`. It sends only the typed question to the Responses API, requests `store: false`, returns only answer text, and never receives the local child profile, birth date, microphone audio, or GPS coordinates. It includes a six-question-per-hour Durable Object limit per client IP and accepts browser requests only from `https://mmostafa4.github.io`.

Deployment requires a Cloudflare account and an OpenAI API key. The ChatGPT subscription is not an API credential. From a machine with Node.js and Wrangler installed:

1. Sign in with `npx wrangler login`.
2. From `backend/newborn-assistant`, add the API key with `npx wrangler secret put OPENAI_API_KEY`. Never put it in the Flutter app, GitHub source, or chat.
3. Deploy with `npx wrangler deploy`. Wrangler prints the Worker URL.
4. Set the GitHub Actions repository variable `BABY_MONITOR_AI_ENDPOINT` to `https://<worker-host>/v1/newborn-qa`, then rerun **Build and deploy iPhone web app**.

Until those account-specific settings exist, the app intentionally says the assistant is disconnected. The Worker prompt gives emergency escalation guidance and prohibits diagnosis and medication dosing; it does not replace pediatric review or clinical safety validation.
