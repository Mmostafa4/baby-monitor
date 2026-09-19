# Brand icon

The Baby Monitor brand mark is implemented as `assets/branding/baby_monitor_logo.svg`:

- a small cartoon baby wearing a diaper;
- sound waves coming from the baby's mouth;
- the waves reaching a smiling mother's ear;
- a soft, friendly blue/lilac background suitable for a family-care app.

The reusable Flutter widget is `lib/widgets/baby_monitor_logo.dart`. Import `BabyMonitorLogo` on onboarding, home, and subscription screens. The SVG is also suitable as the source artwork for Android adaptive icons and the iOS App Store icon export. Generate platform-specific PNG sizes during the release build rather than committing secrets or generated signing files.
