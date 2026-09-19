# Release readiness

The repository now has a coherent Flutter MVP with real 10-second microphone capture, onboarding, branding, and safety messaging.

## Remaining required work before a public release

1. Run `flutter pub get` and `flutter analyze` on a machine with Flutter installed.
2. Add Android `RECORD_AUDIO` permission and iOS `NSMicrophoneUsageDescription`.
3. Run `flutter create .` if platform folders are not present.
4. Connect a real HTTPS backend to `CryAnalysisClient`; the app deliberately refuses to invent a crying interpretation without one.
5. Add authentication, server-side 7-day trial/entitlement validation, Google Play Billing, and App Store subscriptions.
6. Source and medically review each country's vaccination schedule; do not ship placeholder schedules.
7. Add privacy policy, parental consent, data deletion, rate limits, logging, and security review.

The 100 EGP amount is a launch-price fallback only; production pricing must be controlled and validated server-side and configured in both stores.
