# Device permissions

The app asks for each permission only after the parent chooses the related feature. GPS consent is separate from microphone access.

## Location

- During setup, the parent can opt in to location use. The first native system prompt follows that choice.
- The Emergency screen can request a current location when the parent taps the nearby-hospital action.
- Android declares `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`; iOS declares `NSLocationWhenInUseUsageDescription`.
- The app uses foreground location only. It does not request background location or save coordinates.

## Microphone

- The recording screen requests microphone access only when the parent taps **ابدأ التسجيل**.
- Android declares `RECORD_AUDIO`; iOS declares `NSMicrophoneUsageDescription`.
- Capture lasts up to 10 seconds. Audio stays in memory for an optional preview and is not saved to a file or uploaded. Cry analysis is unavailable.

## iPhone Safari

The published web app must be opened over HTTPS. Safari requests microphone or location access when the parent selects the corresponding feature. If access was denied earlier, update the site's permission in Safari settings.