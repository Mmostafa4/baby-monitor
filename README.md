# Baby Monitor

Flutter MVP prepared as an installable iPhone Safari web app. This is not an App Store or TestFlight app.

## What is included

- Consent and child profile setup. The profile stays in local browser storage.
- Arabic interface. The selected language is saved, but translations are not implemented yet.
- Up to 10 seconds of microphone capture through an in-memory stream. Audio chunks are discarded as they arrive; no audio file is kept or uploaded.
- The cry screen says “Analysis is currently unavailable.” The app does not interpret crying.
- Reassurance fields are temporary and are not saved.
- Vaccination entries are placeholders; official schedules and reminders are not connected.
- Emergency guidance is static; nearby hospital search is not implemented.
- The subscription screen is a mockup; purchases are not connected.

## Use it on iPhone

Open the [Baby Monitor web app](https://mmostafa4.github.io/baby-monitor/) in Safari. Tap **Share → Add to Home Screen → Add**, then open Baby Monitor from the Home Screen. Allow microphone access when you start a recording.

The app records for up to 10 seconds, immediately discards the audio stream, and does not send it to a server. It currently shows that cry analysis is unavailable.

## Native app status

The repository contains an early iOS project scaffold, but it is not a release-ready native app. App Store or TestFlight distribution needs a complete Xcode project, Apple signing, a registered bundle ID, and a real-iPhone build and microphone check.

## Production requirements

Before presenting this as a complete baby-monitoring product, add a validated cry-analysis model and secure backend. Do not claim to diagnose illness from crying. Vaccination content must come from and be reviewed against each country's official health authority. Add authentication, privacy protections, parental consent, a privacy policy, and proper data-deletion controls before collecting audio or health-related data.

Never ship API keys, payment secrets, or admin credentials in the app. Verify subscription entitlements on the server and keep prices and vaccination data under a reviewed update process.

## Development

Install Flutter, run `flutter create --platforms=web .` and `flutter pub get`, then `flutter run -d chrome`. The public iPhone release is served over HTTPS through GitHub Pages.

The prototype stores the child profile in browser storage, which is not encrypted. Audio is not retained.
