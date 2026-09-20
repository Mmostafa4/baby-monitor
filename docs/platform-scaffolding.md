# Platform scaffolding note

The repository contains Flutter-generated Android and iOS project scaffolding. `gradle-wrapper.jar`, CocoaPods-generated `Pods/`, and Flutter-generated build artifacts are intentionally not committed.

From the project root, run `flutter create --template=app --platforms=android,ios --no-pub .` to regenerate the native project files for the installed Flutter SDK. Then run `flutter pub get`; on macOS, run `pod install` from `ios/` before an iOS build. The generated local wrapper binary, SDK paths, and build artifacts stay out of version control.

No backend, AI, payments, or tests were added. The MVP and microphone permission declarations remain unchanged.
