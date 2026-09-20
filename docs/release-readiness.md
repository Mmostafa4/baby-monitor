# Release readiness

## MVP status

The repository contains a Flutter MVP with Android/iOS scaffolding, local onboarding, optional foreground GPS, short local audio capture, emergency guidance, vaccine reminders, and an offline-by-default newborn Q&A screen.

Cry analysis is unavailable. No model, backend, authentication, subscription purchase, or trial entitlement is connected. Audio is held in memory for preview and is not uploaded.

## Required before store distribution

- Replace the template Android package and iOS bundle identifiers.
- Configure Android/iOS signing and produce device builds.
- Check microphone and location permission flows on physical devices.
- Review vaccine schedules and emergency guidance with the relevant health authorities or qualified clinicians.
- Complete privacy, parental-consent, support-contact, and legal review.

The existing iPhone Safari web app remains separately published. This branch does not add a deployment workflow or publish changes.