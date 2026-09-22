# Implementation checkpoint

## Included in the MVP

- Arabic-only onboarding, a local child profile, and an explicit medical notice. Native date pickers and system controls are localized in Arabic.
- Editable child profile, date-based daily care logs, and local history for crying, feeds, wet diapers, sleep, temperature, and notes.
- Settings that explain local data handling and let the parent erase the local profile, care logs, and vaccine marks.
- Optional GPS consent in setup and foreground-only location lookup from Emergency. Successful location lookup is shown with a check mark; coordinates are passed to a Google Maps search and are not saved by the app.
- Ten-second microphone capture with a captured-byte check and short-lived in-memory playback. The parent can delete it without uploading.
- An optional experimental cry-analysis client and CPU backend. A separate confirmation is required for each upload; the backend does not persist the audio and does not return a numeric confidence.
- Age-based vaccine reminder tables for the countries in onboarding, local completion checkboxes, and source links. Egypt now includes birth-dose timing windows, date calculation from the entered DOB, the 2/4/6-month IPV rows, vitamin-A supplement rows at 6/12/18 months, side-effect details, and a separate clinician-discussion list for additional vaccines.
- A local weekly newborn-development guide selected from the child's date of birth, with CDC links and no milestone diagnosis.
- Emergency guidance and an optional newborn Q&A screen that shows whether its protected service is configured.
- Android/iOS scaffold with microphone and foreground location declarations.
- GitHub Actions build paths for a sideloadable Android test APK and unsigned iOS simulator app; a manually started, signed TestFlight beta path is prepared for accounts that have Apple signing and App Store Connect credentials.

## Deliberately unavailable

- A live cry-analysis result is disabled until Firebase and an HTTPS backend are configured at build time. The repository contains a real, runnable experimental model service, but it is not deployed or clinically validated. The preview does not recognize a need for comfort or distress.
- Newborn Q&A: the protected endpoint and provider adapter are implemented, but no provider key or endpoint is configured in the repository, so questions remain blocked by default.
- Payments, trials, subscription entitlement checks, and public backend hosting.
- Push notifications for vaccine due dates and additional UI translations.

## Remaining before a store release

- Configure Firebase and deploy the experimental endpoint before a private model preview; validate the model before any wider use. See [private preview setup](preview-setup.md).
- Replace template bundle/package identifiers, configure signing, and build on Android and iOS devices.
- Confirm microphone and location prompts on real devices.
- Have the vaccine reminder rows and emergency guidance reviewed by the relevant medical authority.
- Complete privacy, consent, and legal review for the intended launch countries.
