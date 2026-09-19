# Platform scaffolding note

The repository now contains the text-based Android Gradle wrapper configuration and iOS Xcode/ CocoaPods project scaffolding. `gradle-wrapper.jar`, CocoaPods-generated `Pods/`, and Flutter-generated build artifacts are intentionally not committed.

Run `flutter create .` locally in the project root to regenerate the exact Flutter toolchain files and wrapper binary for the installed Flutter SDK, then run `flutter pub get` and `pod install` on macOS before attempting an iOS build.

No backend, AI, payments, or tests were added. The MVP and microphone permission declarations remain unchanged.
