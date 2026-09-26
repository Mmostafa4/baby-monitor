# Implementation checkpoint

## Included in the MVP

- Arabic-only onboarding, a local child profile, and an explicit medical notice. Native date pickers and system controls are localized in Arabic.
- Editable child profile, date-based daily care logs, and local history for crying, feeds, wet diapers, sleep, temperature, and notes.
- Settings that explain local data handling and let the parent erase the local profile, care logs, and vaccine marks.
- Optional GPS consent in setup and foreground-only location lookup from Emergency. Successful location lookup is shown with a check mark; the caregiver can choose a nearby children's hospital, pediatric clinic, or pediatric doctor search. Coordinates are passed to Google Maps and are not saved by the app; results are not a curated medical directory.
- Ten-second microphone capture with a captured-byte check and short-lived in-memory playback. The parent can delete it without uploading.
- An optional experimental cry-analysis client and CPU backend. A separate confirmation is required for each upload; the backend does not persist the audio. The private Safari beta displays a 0–100 uncalibrated model score, not a measured probability or medical accuracy.
- Five caregiver guide buttons for hunger, colic/gas, discomfort, comfort, and overstimulation, with descriptions and external Minnesota WIC educational videos. The videos are examples of infant behavior, not acoustic proof of any cause.
- Age-based vaccine reminder tables for the countries in onboarding, local completion checkboxes, and source links. Egypt now includes birth-dose timing windows, date calculation from the entered DOB, the 2/4/6-month IPV rows, vitamin-A supplement rows at 6/12/18 months, side-effect details, and a separate clinician-discussion list for additional vaccines.
- A local weekly newborn-development guide selected from the child's date of birth, with CDC links and no milestone diagnosis.
- Emergency guidance and a newborn Q&A screen that checks `/v1/health` and shows whether the server-side text-model provider is configured.
- Android/iOS scaffold with microphone and foreground location declarations.
- GitHub Actions build paths for a sideloadable Android test APK and unsigned iOS simulator app; a manually started, signed TestFlight beta path is prepared for accounts that have Apple signing and App Store Connect credentials.

## Deliberately unavailable

- A live cry-analysis result is disabled in default native builds until Firebase and the HTTPS endpoint are configured. The private Safari beta uses a deployed experimental model; it is not clinically validated and cannot recognize a need for comfort or distress as its own categories.
- Newborn Q&A: the protected endpoint and provider adapter are implemented, but no provider key or endpoint is configured in the repository, so questions remain blocked by default.
- Payments, trials, subscription entitlement checks, and public release of the private backend.
- Push notifications for vaccine due dates and additional UI translations.

## Remaining before a store release

- Configure Firebase for native model testing; validate the experimental model before any wider use. See [private preview setup](preview-setup.md).
- Replace template bundle/package identifiers, configure signing, and build on Android and iOS devices.
- Confirm microphone and location prompts on real devices.
- Have the vaccine reminder rows and emergency guidance reviewed by the relevant medical authority.
- Complete privacy, consent, and legal review for the intended launch countries.
