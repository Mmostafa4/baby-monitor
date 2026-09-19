# Platform setup

Android and iOS platform scaffolding has been added for the MVP. Microphone permission is declared in:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

The app still records locally for the MVP and keeps the “analysis unavailable” message. No backend, AI model, payments, or tests were added.

Run `flutter pub get` and then `flutter run` from a machine with Flutter and the Android/iOS toolchains installed. Xcode may update the generated iOS project settings on first open.
