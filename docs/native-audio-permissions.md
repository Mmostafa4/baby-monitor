# Native permissions for real audio capture

After running `flutter pub get`, configure the platform permissions:

- Android: add `<uses-permission android:name="android.permission.RECORD_AUDIO" />` to `android/app/src/main/AndroidManifest.xml`.
- iOS: add `NSMicrophoneUsageDescription` to `ios/Runner/Info.plist`.

The existing `CryRecordingService` captures a 10-second mono 16 kHz file. Connect it to `CryAnalysisClient` from a signed-in screen only. The backend must enforce authentication, entitlement/trial status, file validation, rate limits, TLS, deletion of raw audio, and return probabilistic results only.

Do not use a placeholder endpoint in production and do not commit tokens or secrets.
