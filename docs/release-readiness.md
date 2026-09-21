# Release readiness

## MVP status

The repository contains an Arabic-only Flutter MVP with Android/iOS scaffolding, editable local onboarding, optional foreground GPS, short local audio capture, a date-based local care log, emergency guidance, vaccine reminders, and an offline-by-default newborn Q&A screen. Native date pickers and system controls are localized in Arabic. Parents can export a single day's summary by copying it and can erase the local profile and logs in Settings.

An experimental model service and client integration are in the repository, but no Firebase project or HTTPS service is connected. Audio remains local unless the preview is configured and a caregiver separately approves the upload. The model is not clinically validated; the preview must not be described as an accurate classifier or a diagnostic feature. Subscription purchase and trial entitlement are also not connected. A manual TestFlight workflow is prepared, but it requires the app owner's Apple signing material and App Store Connect credentials.

## Required before store distribution

- Provision Firebase app registrations and an HTTPS host, then configure the app without exposing the Firebase Admin key.
- Add the public app configuration as GitHub Actions variables and Apple signing values as secrets, then start the TestFlight beta workflow manually. The required names are listed in [private preview setup](preview-setup.md).
- Validate the model across children excluded from training and in home recordings; get medical and privacy review before wider testing.
- Replace the template Android package and iOS bundle identifiers.
- Configure Android/iOS signing and produce device builds.
- Check microphone and location permission flows on physical devices.
- Review vaccine schedules and emergency guidance with the relevant health authorities or qualified clinicians.
- Complete privacy, parental-consent, support-contact, and legal review.

The existing iPhone Safari web app remains published. This branch does not change its deployment workflow; merging to `main` triggers the existing GitHub Pages deployment. Keep this branch unmerged until publication is approved.
