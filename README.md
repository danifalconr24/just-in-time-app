# JITA - Just In Time App

JITA helps users arrive on time by continuously monitoring traffic for a selected
trip and recalculating when they should leave.

The app monitors one active route (origin -> destination) in the background,
polling Google Routes API every 30 seconds. If travel time increases due to
traffic, JITA computes a new required departure time and sends urgent repeated
notifications when the departure window shifts.

## Core Features

- Origin and destination input with Google Places Autocomplete
- Arrival time picker (user selects desired destination arrival time)
- Background monitoring every 30 seconds
- Live traffic-aware travel duration updates
- Dynamic "Leave by" time recalculation
- Repeated notifications when traffic worsens and departure time shifts
- One active route at a time (simple and focused UX)

## Product Flow

1. User selects origin and destination using autocomplete.
2. User selects target arrival time.
3. User taps "Start Monitoring".
4. App stores active trip and starts background monitoring.
5. Every 30 seconds, app calls `computeRouteMatrix`.
6. App recalculates required departure time.
7. If traffic increases and required departure shifts, app sends urgent alert.
8. Monitoring stops automatically when arrival time passes or user taps
   "Stop Monitoring".

## Running Locally

### Prerequisites

- Flutter SDK (3.41+ recommended)
- Dart SDK (3.11+)
- A Google Cloud project with **Routes API** and **Places API** enabled
- A Google API key with access to both APIs

Verify your toolchain:

```bash
flutter doctor -v
```

### Setup

1. Clone the repository and install dependencies:

```bash
git clone <repo-url>
cd just-in-time-app
flutter pub get
```

2. Obtain a Google API key from the
   [Google Cloud Console](https://console.cloud.google.com/apis/credentials).
   Enable the following APIs for your project:
   - Routes API
   - Places API (New)

3. Run the app, injecting the API key at build time:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

Replace `YOUR_KEY_HERE` with your actual key. The key is never stored in
source — it is passed as a compile-time constant via `--dart-define`.

### Running on a specific platform

```bash
flutter run -d ios --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
flutter run -d android --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

### Running tests

```bash
flutter test                # all tests
flutter test --coverage     # with coverage report

# single file
flutter test test/domain/departure_calculator_test.dart

# single test by name
flutter test --plain-name "returns correct required departure time"
```

### Static analysis and formatting

```bash
flutter analyze   # check for lint/type issues
dart format .     # auto-format all Dart files
```

### Building release artifacts

```bash
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
flutter build ios --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

## Tech Stack

- Flutter 3.41 / Dart 3.11
- Google Routes API (`computeRouteMatrix`)
- Google Places API (autocomplete)

Documentation:

- https://developers.google.com/maps/documentation/routes/compute_route_matrix
- https://developers.google.com/maps/documentation/routes/reference/rest/v2/TopLevel/computeRouteMatrix

## App Architecture

```text
lib/
├── main.dart
├── app.dart
├── data/
│   ├── models/
│   │   ├── route_status.dart
│   │   └── trip.dart
│   ├── services/
│   │   ├── routes_api_service.dart
│   │   └── location_service.dart
│   └── repositories/
│       └── trip_repository.dart
├── domain/
│   └── departure_calculator.dart
├── background/
│   └── traffic_monitor.dart
├── notifications/
│   └── notification_service.dart
└── ui/
    ├── home/
    │   ├── home_screen.dart
    │   └── home_controller.dart
    └── monitoring/
        ├── monitoring_screen.dart
        └── monitoring_controller.dart
```

## Main Dependencies

- `http` - Google Routes API REST calls
- `flutter_google_places_sdk` - Places autocomplete
- `flutter_background_service` - background monitoring isolate
- `flutter_local_notifications` - local urgent notifications
- `flutter_riverpod` - state management
- `shared_preferences` - persist active trip
- `intl` - time/date formatting
- `permission_handler` - runtime permissions

## Departure Time Logic

```text
baseline_departure = targetArrivalTime - staticDuration
current_required_departure = targetArrivalTime - currentDuration

if current_required_departure < now:
    notify urgently (user is already late)

if current_required_departure < baseline_departure:
    delta = baseline_departure - current_required_departure
    notify: Leave delta earlier (by HH:mm)
```

Notification strategy:

- Fire when traffic-aware duration becomes worse than baseline.
- Re-fire whenever required departure shifts by >= 1 minute since last alert.

## Google Routes API Integration

- Endpoint:
  `POST https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix`
- Auth header: `X-Goog-Api-Key`
- Field mask:
  `X-Goog-FieldMask: originIndex,destinationIndex,duration,staticDuration,status,condition`
- Request mode: `travelMode=DRIVE`, `routingPreference=TRAFFIC_AWARE`
- Polling frequency: every 30 seconds (1x1 matrix)

## UI Design

### Home Screen

- Origin autocomplete input
- Destination autocomplete input
- Arrival time picker
- Full-width "Start Monitoring" button (bottom)

### Monitoring Screen

- Route summary (origin -> destination)
- Target arrival time
- Current travel duration (live)
- Computed "Leave by" time (live)
- Delta display (e.g., "Leave 12 min earlier than planned")
- "Stop Monitoring" button

## Platform Behavior

### Android

- Uses foreground service for reliable background monitoring
- Persistent service notification channel required

### iOS

- Uses `BGAppRefreshTask` / background fetch style scheduling
- 30-second polling in background is best-effort (OS may throttle)

## Permissions

### Android

- `android.permission.FOREGROUND_SERVICE`
- `android.permission.POST_NOTIFICATIONS`
- `android.permission.RECEIVE_BOOT_COMPLETED`

### iOS

- `UIBackgroundModes` (`fetch`, `processing`)
- `BGTaskSchedulerPermittedIdentifiers`
- `NSLocationWhenInUseUsageDescription`

## Risks and Mitigations

- iOS background throttling -> clearly communicate best-effort behavior
- API key exposure -> inject with `--dart-define`, never commit secrets
- API usage costs -> debounce autocomplete and monitor quotas
- Notification fatigue -> thresholded re-alerting (>= 1 minute shift)
- Network failures -> retry on next polling cycle with graceful UI feedback

## Development Roadmap

1. ~~Project scaffold and dependency setup~~
2. ~~Data/domain implementation (models, services, calculator)~~
3. ~~UI implementation (home + monitoring)~~
4. ~~Foreground polling loop~~
5. ~~Notification behavior~~
6. ~~Background service hardening~~
7. ~~Testing, edge cases, and polish~~

For a detailed implementation plan, see `DEVELOPMENT-PLAN.md`.
