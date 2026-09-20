# Baby Monitor

Flutter MVP with a public iPhone Safari web app. This release is not an App Store or TestFlight app.

## Current implementation
- One-time medical disclaimer and required consent.
- Child, caregiver, country, language, and birth-date onboarding. The profile is saved on the device.
- Arabic user interface. The selected language is saved, but translations for other languages are not implemented yet.
- Ten-second local microphone recording. The temporary audio file is deleted when capture ends or is cancelled; it is not uploaded.
- The cry screen says “Analysis is currently unavailable.” No cry interpretation is generated.
- Reassurance fields are temporary and are not saved yet.
- Vaccination screen contains placeholders only; official schedules and reminders are not connected.
- Static emergency guidance. Nearby hospital search is not implemented.
- A subscription offer screen exists as a mockup, but purchases and the offer are not connected to the app flow.

## Important production boundaries
The audio classifier, official vaccination schedules, subscriptions, authentication, and remote pricing must be connected to a secure backend before release. The app must not claim to diagnose illness from crying. Vaccination content must be reviewed and sourced from each country's official health authority.

## Running

### iPhone

The iPhone-ready version is a web app served over HTTPS. Open its published address in Safari, choose **Share → Add to Home Screen**, then tap **Add**. Allow microphone access when starting a recording. The app records for up to 10 seconds, discards the temporary audio, and does not send audio to a server.

The repository also has a native iOS project with microphone permission. App Store/TestFlight distribution still needs Apple signing, a registered bundle ID, and a real-iPhone build check.

### Development

Install Flutter, run `flutter create --platforms=web .` and `flutter pub get`, then `flutter run -d chrome` for web. Native Android/iOS builds use the platform folders in the repository; see `docs/native-audio-permissions.md` for microphone permission entries.

The child profile is stored on the device using local preferences. The prototype does not upload profile data or audio, and its local preferences are not encrypted.

## Security plan
- Never ship API secrets, payment secrets, or admin credentials in the app.
- Use a backend to verify Google Play/App Store receipts and entitlements.
- Store only short-lived signed upload URLs for audio; delete raw recordings by default.
- Enforce authentication, authorization, rate limits, TLS, encrypted storage, audit logs, and server-side validation.
- Make price and vaccination data server-controlled with versioning and an admin review workflow.
- Publish a privacy policy and obtain the required parental/child-data consent before collecting audio or health-related data.
