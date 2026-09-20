# Native permissions for real audio capture

## iPhone Safari

Serve the web build over HTTPS. The browser requests microphone permission only when the user starts a recording.

## Native builds

After running `flutter pub get`, configure the platform permissions:

- Android: add `<uses-permission android:name="android.permission.RECORD_AUDIO" />` to `android/app/src/main/AndroidManifest.xml`.
- iOS: add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.

`CryRecordingService` captures mono audio for up to 10 seconds and discards the temporary output when recording ends or is cancelled. No audio is uploaded and the MVP does not produce an analysis result. Before connecting `CryAnalysisClient`, add sign-in and ensure the backend enforces authentication, entitlement/trial status, file validation, rate limits, TLS, deletion of raw audio, and probabilistic results only.

Do not use a placeholder endpoint in production and do not commit tokens or secrets.
