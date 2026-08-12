# sugar_plus

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## GlucoScan feature

Non-invasive eye-photo blood sugar estimation. The app captures a photo and
sends it to a separate FastAPI backend (`sugar_plus_backend/`, sibling to
this repo) which runs the OpenCV eye-detection/analysis and returns an
estimate, classification, and recommendation.

1. Run the backend: see `../sugar_plus_backend/README.md`.
2. Point the app at it: `flutter run --dart-define=GLUCOSCAN_API_BASE_URL=http://<your-lan-ip>:8000`
   (defaults to `http://10.0.2.2:8000`, the Android emulator's alias for
   your machine's localhost — override this for a physical device).
3. From Home, tap **GlucoScan** (or the camera FAB) to take an eye photo.

Results save to the same history as manual entries, tagged `source: 'scan'`
vs `source: 'manual'`, and feed the Analytics trend charts. This is
experimental, non-clinical technology — the UI says so, and it should stay
that way.
