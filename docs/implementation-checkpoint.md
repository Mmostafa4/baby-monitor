# Implementation checkpoint

## Included in the MVP

- Arabic-only onboarding, a local child profile, and an explicit medical notice. Native date pickers and system controls are localized in Arabic.
- Editable child profile, date-based daily care logs, and local history for crying, feeds, wet diapers, sleep, temperature, and notes.
- Settings that explain local data handling and let the parent erase the local profile, care logs, and vaccine marks.
- Optional GPS consent in setup and foreground-only location lookup from Emergency. Successful location lookup is shown with a check mark; coordinates are passed to a Google Maps search and are not saved by the app.
- Ten-second microphone capture with a captured-byte check and short-lived in-memory playback. The parent can delete it; no persistent audio file or upload is created.
- Age-based vaccine reminder tables for the countries in onboarding, local completion checkboxes, and source links.
- Emergency guidance and a newborn Q&A screen that clearly reports it is not connected.
- Android/iOS scaffold with microphone and foreground location declarations.

## Deliberately unavailable

- Cry analysis: the app displays “Analysis is currently unavailable.” No cry label or diagnosis is generated.
- Newborn Q&A: no endpoint is configured, so questions are not sent.
- Payments, trials, subscription entitlement checks, authentication, and backend services.
- Push notifications for vaccine due dates and additional UI translations.

## Remaining before a store release

- Replace template bundle/package identifiers, configure signing, and build on Android and iOS devices.
- Confirm microphone and location prompts on real devices.
- Have the vaccine reminder rows and emergency guidance reviewed by the relevant medical authority.
- Complete privacy, consent, and legal review for the intended launch countries.
