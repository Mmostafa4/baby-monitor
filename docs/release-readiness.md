# Release readiness

This MVP captures up to 10 seconds of audio as a temporary stream, discards chunks immediately, and displays “Analysis is currently unavailable.” It does not store audio, upload audio, or interpret crying.

## iPhone Safari web app

- Served over HTTPS so Safari can request microphone permission.
- Can be added to the Home Screen from Safari using **Share → Add to Home Screen**.
- Profile data stays in browser storage and is not encrypted.
- The web app is the current public release path; the recording stream is discarded locally.

## Native App Store/TestFlight app

The repository's iOS folder is an early scaffold, not a ready-to-ship native app. Before native distribution:

- Complete and validate the Xcode project and Flutter iOS build.
- Set the production bundle identifier and Apple signing.
- Build and test microphone capture on a physical iPhone.
- Complete App Store Connect setup and meet Apple's review requirements.

## Future production features

- A validated model and secure HTTPS backend are required before showing a cry interpretation.
- Authentication, server-side entitlement checks, and in-app purchases are not part of this MVP.
- Source and medically review each country's vaccination schedule before displaying dates or recommendations.
- Add a privacy policy and complete parental-consent, data-deletion, and security work before collecting audio or health-related data.
