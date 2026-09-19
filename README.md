# Baby Monitor

Cross-platform Flutter MVP for Android and iOS.

## Current implementation
- One-time medical disclaimer and required consent.
- Child, parent, country, language, and birth-date onboarding.
- Arabic-first navigation with support for the planned language list.
- Ten-second recording flow UI for the primary crying-analysis feature.
- Reassurance tracking fields.
- Vaccination section prepared for server-managed, country-specific schedules.
- Emergency guidance and optional nearby children's-hospital search using the device location.
- Annual offer price has a safe local fallback of **100 EGP**.

## Important production boundaries
The audio classifier, official vaccination schedules, subscriptions, authentication, and remote pricing must be connected to a secure backend before release. The app must not claim to diagnose illness from crying. Vaccination content must be reviewed and sourced from each country's official health authority.

## Running
```bash
flutter pub get
flutter run
```

Add the standard Flutter Android/iOS platform folders with `flutter create .` if they are not present. Configure location permissions in AndroidManifest.xml and Info.plist before using nearby search.

## Security plan
- Never ship API secrets, payment secrets, or admin credentials in the app.
- Use a backend to verify Google Play/App Store receipts and entitlements.
- Store only short-lived signed upload URLs for audio; delete raw recordings by default.
- Enforce authentication, authorization, rate limits, TLS, encrypted storage, audit logs, and server-side validation.
- Make price and vaccination data server-controlled with versioning and an admin review workflow.
- Publish a privacy policy and obtain the required parental/child-data consent before collecting audio or health-related data.
