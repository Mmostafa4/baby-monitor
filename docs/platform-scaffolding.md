# Platform scaffolding note

The repository contains Flutter-generated Android and iOS project scaffolding, including the Gradle wrapper required for a clean Android checkout. CocoaPods-generated `Pods/`, local SDK paths, and Flutter build artifacts are not committed.

From the project root, run `flutter pub get`. Before an iOS build, run `python3 scripts/configure_ios.py`, then run `pod install` from `ios/`. After upgrading Flutter, regenerate platform files with `flutter create --template=app --platforms=android,ios --no-pub .` and reapply the iOS permission and deployment settings.

An experimental model backend is included for a private preview, but no service has been deployed or configured. Payments are not connected. The app still requires final store identifiers, Apple signing, and physical-device checks before an iPhone beta or store distribution.
