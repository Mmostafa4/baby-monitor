# Baby Monitor

Arabic-only Flutter MVP for Android, iOS, and the web. The profile screen states that Arabic is the language available in this build; other translations are not selectable yet.

The current published iPhone Safari version is at [mmostafa4.github.io/baby-monitor](https://mmostafa4.github.io/baby-monitor/). This branch is not live. Merging to `main` triggers the repository's existing GitHub Pages deployment.

## MVP features

- Local child profile and medical-notice consent.
- Editable child profile, a daily care log with date navigation and local history, copyable summaries for a caregiver or clinician, and a control to erase local data.
- Optional GPS consent during setup. Location is requested only after consent, and the Emergency screen shows a check when a location fix succeeds before opening a Google Maps search. Coordinates are not saved by the app.
- Up to 10 seconds of microphone capture, an in-memory audio preview, and a delete action. The app does not save or upload audio.
- Cry analysis remains unavailable and the screen says **Analysis is currently unavailable.**
- Draft age-based vaccination reminders for the countries listed in onboarding, with local completion marks and links to source schedules. These are reminders, not a clinical catch-up plan.
- A newborn Q&A screen that is disconnected by default. No question is sent in this MVP.
- Subscription UI is a mockup; no purchase is connected.

## Device permissions

Android declares microphone and foreground location permissions. iOS includes microphone and when-in-use location purpose strings. The app asks only after a user chooses the relevant feature; it does not request background location.

## Development

Install Flutter and run `flutter pub get` from the project root. On macOS, run `pod install` from `ios/` before building for iOS. Use `flutter run -d chrome` for a browser preview or `flutter run` with a connected device for a native run. See [the platform setup note](docs/platform-scaffolding.md) if regenerating native files after a Flutter SDK upgrade.

The native project identifiers are still Flutter template identifiers. Android/iOS signing, store submission, legal review, medical review of schedule rows, and real-device release checks are not part of this MVP branch.

Profile data, daily care logs, and vaccine checkmarks are stored locally with SharedPreferences. The app does not diagnose illness, interpret crying, or connect to a backend by default.
