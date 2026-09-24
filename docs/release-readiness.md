# Release readiness

## MVP status

The repository contains an Arabic-only Flutter MVP with Android/iOS scaffolding, editable local onboarding, optional foreground GPS, short local audio capture, a date-based local care log, a weekly newborn-development guide, emergency guidance, vaccine reminders, and an offline-by-default newborn Q&A screen. Native date pickers and system controls are localized in Arabic. Parents can export a single day's summary by copying it and can erase the local profile and logs in Settings.

The private Safari beta has an HTTPS Railway service with an experimental cry model. It requires an invite code and asks for separate approval before each audio upload; audio remains local until that approval. Default native builds do not connect to the service because Firebase is not configured, and newborn Q&A has no text-model provider. The cry model is not clinically validated; its 0–100 score is an uncalibrated model output, not a probability that a suggested cause is correct. Subscription purchase and trial entitlement are not connected. A manual TestFlight workflow is prepared, but it requires the app owner's Apple signing material and App Store Connect credentials.

## Required before store distribution

- Provision Firebase app registrations, connect native builds to the existing HTTPS beta host, and configure the app without exposing the Firebase Admin key.
- Configure the optional text-model provider on the HTTPS host, keep its API key server-side, and validate Arabic answers and emergency interception with medical/privacy review.
- Add the public app configuration as GitHub Actions variables and Apple signing values as secrets, then start the TestFlight beta workflow manually. The required names are listed in [private preview setup](preview-setup.md).
- Validate the model across children excluded from training and in home recordings; get medical and privacy review before wider testing.
- Replace the template Android package and iOS bundle identifiers.
- Configure Android/iOS signing and produce device builds.
- Check microphone and location permission flows on physical devices.
- Review vaccine schedules and emergency guidance with the relevant health authorities or qualified clinicians.
- Complete privacy, parental-consent, support-contact, and legal review.

The existing iPhone Safari web app remains published. This branch does not change its deployment workflow; merging to `main` triggers the existing GitHub Pages deployment. Keep this branch unmerged until publication is approved.
