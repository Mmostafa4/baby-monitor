# Platform scaffolding note

The repository contains Flutter-generated Android and iOS project scaffolding, including the Gradle wrapper required for a clean Android checkout. CocoaPods-generated `Pods/`, local SDK paths, and Flutter build artifacts are not committed.

From the project root, run `flutter pub get`. On macOS, run `pod install` from `ios/` before an iOS build. After upgrading Flutter, regenerate platform files with `flutter create --template=app --platforms=android,ios --no-pub .`.

No backend, AI, payments, or tests were added. The app requires final store identifiers, device signing, and physical-device release checks before distribution.
