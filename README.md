# Baby Monitor

A Flutter web app prepared for iPhone Safari. The currently published product is a PWA, not an App Store or TestFlight release.

## What this version does

- Saves the child's basic profile on the device.
- Asks separately for location consent during setup. GPS is requested only after consent; the emergency page shows a green check after a location fix and opens Apple Maps. Coordinates are not saved by the app.
- Captures up to 10 seconds from the microphone as an in-memory stream, confirms that audio bytes arrived, and lets the parent listen before deleting it. Audio is not saved as a file or uploaded, and crying is not analyzed.
- Shows age-based vaccine reminders for the ten countries in onboarding. Dates are calculated from the saved birth date, completion checks are stored locally, and the source schedule is linked in the app. Egypt's zero-dose timing includes HepB within 24 hours and OPV during the first week.
- Lists ten numbered newborn danger signs and links to WHO/AAP guidance.
- Includes a newborn Q&A screen and a secure server Worker scaffold. The Q&A is visibly disconnected until an account owner deploys the Worker and sets the GitHub Actions variable; it never sends the profile, birth date, audio, or location.

## Medical and privacy notes

The schedules are reminders based on the WHO/UNICEF country schedule viewer and official supplemental sources linked in the app. Some items vary by product, season, region, birth cohort, or risk category. The child's official vaccine card and local health center take priority. The Q&A is educational and is not a diagnosis or treatment service.

Profile data and vaccine checkmarks are stored in browser preferences on this device. The user-entered Q&A question is sent to the configured server only after it is connected. Never place API secrets in Flutter or in this public repository.

## iPhone

Open [the published app](https://mmostafa4.github.io/baby-monitor/) in Safari. Choose **Share → Add to Home Screen** to install the PWA. Allow microphone and location access when Safari asks. If permission was previously denied, change it in Safari's website settings.

This is not a signed iOS app. Publishing through the App Store or TestFlight still requires an Apple Developer account, signing, App Store Connect setup, and a real-iPhone release check.

## Development

Install Flutter, then run:

```sh
flutter pub get
flutter run -d chrome
```

The web build is deployed by `.github/workflows/iphone-web.yml`. For newborn Q&A deployment, see [backend/README.md](backend/README.md).
