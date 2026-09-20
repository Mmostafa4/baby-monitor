# Audio capture

## iPhone Safari

Serve the web app over HTTPS. Safari requests microphone permission when the user starts a recording.

The app captures mono audio for up to 10 seconds as an in-memory stream. It discards each audio chunk immediately, creates no audio file, and sends nothing to a server. The MVP does not produce an analysis result.

## Native iOS scaffold

The repository includes `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`. The iOS project is still an early scaffold and has not been validated as an App Store/TestFlight build.

Before connecting the cry-analysis client, add sign-in and ensure the backend enforces authentication, entitlement status, file validation, rate limits, TLS, deletion of raw audio, and appropriately qualified results. Do not use a placeholder endpoint in production or commit tokens and secrets.
