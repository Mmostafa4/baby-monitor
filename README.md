# Baby Monitor

Arabic-only Flutter MVP for Android, iOS, and the web. The profile screen states that Arabic is the language available in this build; other translations are not selectable yet.

The public GitHub Pages preview remains on `main`. This branch adds a separate password-protected Safari web-app beta at Railway; it does not change `main` or publish to either app store. On iPhone, open the private beta URL in Safari, enter the invite code, then choose **Share → Add to Home Screen**. This is an installable web app, not a TestFlight IPA.

## MVP features

- Local child profile and medical-notice consent.
- Editable child profile, a daily care log with date navigation and local history, copyable summaries for a caregiver or clinician, and a control to erase local data.
- Optional GPS consent during setup. The Emergency screen shows a check when a location fix succeeds and offers separate Google Maps searches for nearby children's hospitals, pediatric clinics, or pediatric doctors. Coordinates are not saved by the app; map results still need caregiver verification.
- Up to 10 seconds of microphone capture, in-memory playback, and deletion. Silent or very faint recordings ask for a new recording instead of showing an analysis result; this audio-level check does not detect whether a baby is crying.
- Optional experimental cry classification: a configured build asks for separate consent before sending audio to an HTTPS backend. It shows the top-ranked category and a 0–100 raw model score. The score is uncalibrated, not an accuracy percentage or medical probability. The model cannot identify a need for comfort or distress. The Safari beta signs in with a private invite code and same-origin session; native builds still need Firebase settings. See [the research and evidence review](docs/cry-analysis-evidence.md), [preview service setup](backend/README.md), and [phone test setup](docs/preview-setup.md).
- Age-based vaccination reminders for the countries listed in onboarding, with the Egypt routine table checked against Egyptian Health Council/Ministry/UNICEF sources, date calculation from the entered birth date, vitamin-A supplement entries, side-effect guidance, local completion marks, and source links. Additional vaccines are clearly separated as clinician-discussion items; these reminders are not a clinical catch-up plan.
- A weekly newborn-development guide based on the child's local date of birth, with CDC source links. It is an age-based educational prompt, not a milestone test.
- A newborn Q&A screen with a protected HTTPS backend adapter for an OpenAI-compatible text-model provider. The screen checks `/v1/health` and stays blocked until the server-side provider URL, key, and model are configured; no provider key is shipped in Flutter.
- A free, payment-free two-device doctor-call technology demo at `/call-demo`: one browser can act as the patient and another as a demo doctor. It uses browser WebRTC audio and an in-memory WebSocket signaling room; it is not a real medical service, has no card collection, and does not record calls.
- Subscription UI is a mockup; no purchase is connected.

## Device permissions

Android declares microphone and foreground location permissions. iOS includes microphone and when-in-use location purpose strings. The app asks only after a user chooses the relevant feature; it does not request background location.

## Development

Install Flutter and run `flutter pub get` from the project root. Before a local iOS build, run `python3 scripts/configure_ios.py` from the project root, then run `pod install` from `ios/`. Use `flutter run -d chrome` for a browser preview or `flutter run` with a connected device for a native run. See [the platform setup note](docs/platform-scaffolding.md) if regenerating native files after a Flutter SDK upgrade.

The native project identifiers are still Flutter template identifiers until configured for your accounts. GitHub Actions can build an Android test APK and an unsigned iOS simulator app. A separate manual workflow prepares a signed iPhone IPA and uploads a beta to TestFlight after Apple signing and backend/Firebase settings are configured. The private Railway Safari beta has a deployed HTTPS experimental backend; default native builds do not connect to it and keep analysis unavailable until their authentication and endpoint are configured.

Profile data, daily care logs, and vaccine checkmarks are stored locally with SharedPreferences. The app does not upload audio by default. The optional model covers hunger, belly pain, burping, general discomfort, and tiredness; it does not classify a need for affection or measure distress, and it is not validated for real-world accuracy.
