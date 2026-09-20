# Release readiness

The MVP captures up to 10 seconds of audio locally, deletes the temporary file when capture ends, and displays “Analysis is currently unavailable.” It does not send audio to a server or produce a cry interpretation.

## iPhone web app

The public web build is intended to open in iPhone Safari and can be added to the Home Screen. Microphone recording requires HTTPS and user permission. Profile data stays in browser storage; audio is captured for up to 10 seconds and discarded without upload.

## Native App Store/TestFlight release

- The repository includes an iOS project, but the public release is a web app. Native distribution needs Apple signing, a registered bundle ID, an App Store Connect account, and a real-iPhone build and microphone check.
- Add Android `RECORD_AUDIO` permission before making an Android build.

## Future production features

- A validated model and secure HTTPS backend are required before showing any cry interpretation.
- Authentication, server-side entitlement verification, Google Play Billing, and App Store subscriptions are not part of this MVP.
- Source and medically review each country's vaccination schedule before displaying real dates or recommendations.
- Add a privacy policy and complete parental-consent, data-deletion, security, and store-review work before publishing.
