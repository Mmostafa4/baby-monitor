# Baby Monitor

Arabic-only Flutter MVP for Android, iOS, and the web. The profile screen states that Arabic is the language available in this build; other translations are not selectable yet.

The public GitHub Pages preview remains on `main`. This branch adds a separate password-protected Safari web-app beta at Railway; it does not change `main` or publish to either app store. On iPhone, open the private beta URL in Safari, enter the invite code, then choose **Share → Add to Home Screen**. This is an installable web app, not a TestFlight IPA.

## MVP features

- Local child profile and medical-notice consent.
- Editable child profile, a daily care log with date navigation and local history, copyable summaries for a caregiver or clinician, and a control to erase local data.
- Optional GPS consent during setup. Location is requested only after consent, and the Emergency screen shows a check when a location fix succeeds before opening a Google Maps search. Coordinates are not saved by the app.
- Up to 10 seconds of microphone capture, in-memory playback, and deletion.
- Optional experimental cry classification: a configured build asks for separate consent before sending audio to an HTTPS backend. It shows the top-ranked category and a 0–100 raw model score. The score is uncalibrated, not an accuracy percentage or medical probability. The model cannot identify a need for comfort or distress. The Safari beta signs in with a private invite code and same-origin session; native builds still need Firebase settings. See [the research and evidence review](docs/cry-analysis-evidence.md), [preview service setup](backend/README.md), and [phone test setup](docs/preview-setup.md).
- Draft age-based vaccination reminders for the countries listed in onboarding, with local completion marks and links to source schedules. These are reminders, not a clinical catch-up plan.
- A newborn Q&A screen that is disconnected by default. No question is sent in this MVP.
- Subscription UI is a mockup; no purchase is connected.

## Device permissions

Android declares microphone and foreground location permissions. iOS includes microphone and when-in-use location purpose strings. The app asks only after a user chooses the relevant feature; it does not request background location.

## Development

Install Flutter and run `flutter pub get` from the project root. Before a local iOS build, run `python3 scripts/configure_ios.py` from the project root, then run `pod install` from `ios/`. Use `flutter run -d chrome` for a browser preview or `flutter run` with a connected device for a native run. See [the platform setup note](docs/platform-scaffolding.md) if regenerating native files after a Flutter SDK upgrade.

The native project identifiers are still Flutter template identifiers until configured for your accounts. GitHub Actions can build an Android test APK and an unsigned iOS simulator app. A separate manual workflow prepares a signed iPhone IPA and uploads a beta to TestFlight after Apple signing and backend/Firebase settings are configured; the current branch has no such credentials or deployed backend, so analysis is disabled in its default build.

Profile data, daily care logs, and vaccine checkmarks are stored locally with SharedPreferences. The app does not upload audio by default. The optional model covers hunger, belly pain, burping, general discomfort, and tiredness; it does not classify a need for affection or measure distress, and it is not validated for real-world accuracy.
