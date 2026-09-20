# Release readiness

## MVP status

The repository contains a Flutter MVP with Android/iOS scaffolding, editable local onboarding, optional foreground GPS, short local audio capture, a date-based local care log, emergency guidance, vaccine reminders, and an offline-by-default newborn Q&A screen. Parents can export a single day's summary by copying it and can erase the local profile and logs in Settings.

Cry analysis is unavailable. No model, backend, authentication, subscription purchase, or trial entitlement is connected. Audio is held in memory for preview and is not uploaded.

## Required before store distribution

- Replace the template Android package and iOS bundle identifiers.
- Configure Android/iOS signing and produce device builds.
- Check microphone and location permission flows on physical devices.
- Review vaccine schedules and emergency guidance with the relevant health authorities or qualified clinicians.
- Complete privacy, parental-consent, support-contact, and legal review.

The existing iPhone Safari web app remains published. This branch does not change its deployment workflow; merging to `main` triggers the existing GitHub Pages deployment. Keep this branch unmerged until publication is approved.
