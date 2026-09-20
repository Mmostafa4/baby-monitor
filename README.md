# Baby Monitor

Arabic-first Flutter MVP for Android, iOS, and the web.

The current published iPhone Safari version is at [mmostafa4.github.io/baby-monitor](https://mmostafa4.github.io/baby-monitor/). Changes on this branch are not published automatically.

## MVP features

- Local child profile and medical-notice consent.
- Optional GPS consent during setup. Location is requested only after consent, and the Emergency screen shows a check when a location fix succeeds before opening Apple Maps. Coordinates are not saved.
- Up to 10 seconds of microphone capture, an in-memory audio preview, and a delete action. The app does not save or upload audio.
- Cry analysis remains unavailable and the screen says **Analysis is currently unavailable.**
- Draft age-based vaccination reminders for the countries listed in onboarding, with local completion marks and links to source schedules. These are reminders, not a clinical catch-up plan.
- A newborn Q&A screen that is disconnected by default. No question is sent in this MVP.
- Subscription UI is a mockup; no purchase is connected.

## Device permissions

Android declares microphone and foreground location permissions. iOS includes microphone and when-in-use location purpose strings. The app asks only after a user chooses the relevant feature; it does not request background location.

## Development

Install Flutter, then run `flutter pub get`. Use `flutter run -d chrome` for a browser preview or `flutter run` with a connected device for a native run.

The native project identifiers are still Flutter template identifiers. Android/iOS signing, store submission, legal review, medical review of schedule rows, and real-device release checks are not part of this MVP branch.

Profile data and vaccine checkmarks are stored locally with SharedPreferences. The app does not diagnose illness, interpret crying, or connect to a backend by default.