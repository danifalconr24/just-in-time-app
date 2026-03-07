# JITA — Just In Time App: Development Plan

## Overview

JITA monitors a single origin→destination route in the background, polling the
Google Routes API every 30 seconds. When traffic increases the route duration, it
calculates the new required departure time and sends a repeated push notification
to the user so they leave on time.

**Stack:** Flutter 3 · Dart 3.10 · Google Routes API (`computeRouteMatrix`)

---

## Architecture

```
lib/
├── main.dart
├── app.dart                        # MaterialApp, theme, routing
│
├── data/
│   ├── models/
│   │   ├── route_status.dart       # Holds duration, departure calc result
│   │   └── trip.dart               # Origin, destination, target arrival time
│   ├── services/
│   │   ├── routes_api_service.dart # HTTP calls to computeRouteMatrix
│   │   └── location_service.dart   # Places Autocomplete (geocoding)
│   └── repositories/
│       └── trip_repository.dart    # Persists active trip (SharedPreferences)
│
├── domain/
│   └── departure_calculator.dart   # Core logic: when must user leave?
│
├── background/
│   └── traffic_monitor.dart        # Background polling task (flutter_background_service)
│
├── notifications/
│   └── notification_service.dart   # Local push notifications (flutter_local_notifications)
│
└── ui/
    ├── home/
    │   ├── home_screen.dart        # Input form + confirm button
    │   └── home_controller.dart    # State management (Riverpod)
    └── monitoring/
        ├── monitoring_screen.dart  # Live status view while trip is active
        └── monitoring_controller.dart
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `http` | REST calls to Google Routes API |
| `flutter_google_places_sdk` | Places Autocomplete for origin/destination input |
| `flutter_background_service` | Run Dart isolate in background (Android foreground service / iOS BGTask) |
| `flutter_local_notifications` | Urgent local push notifications |
| `flutter_riverpod` | State management |
| `shared_preferences` | Persist active trip across app restarts |
| `intl` | Date/time formatting for the arrival time picker |
| `permission_handler` | Request notification + location permissions |

---

## Phases

### Phase 1 — Project Setup
- Create Flutter project (`flutter create jita`)
- Add all dependencies to `pubspec.yaml`
- Configure Google API key:
  - `AndroidManifest.xml` meta-data entry
  - `AppDelegate.swift` / `Info.plist` for iOS
  - Store key in `--dart-define` or `.env` (not committed to git)
- Enable APIs in Google Cloud Console:
  - Routes API
  - Places API (for autocomplete)
- Set up Riverpod `ProviderScope` in `main.dart`

### Phase 2 — Data Layer

#### `Trip` model
```dart
class Trip {
  final String originName;
  final LatLng originLatLng;
  final String destinationName;
  final LatLng destinationLatLng;
  final DateTime targetArrivalTime;
}
```

#### `RouteStatus` model
```dart
class RouteStatus {
  final Duration currentDuration;   // traffic-aware
  final Duration staticDuration;    // no-traffic baseline
  final DateTime sampledAt;
  final DateTime requiredDeparture; // computed
}
```

#### `RoutesApiService`
- POST to `https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix`
- `travelMode: DRIVE`, `routingPreference: TRAFFIC_AWARE`
- Field mask: `originIndex,destinationIndex,duration,staticDuration,status,condition`
- Parse response, return `Duration` (traffic-aware)

#### `LocationService`
- Wrap `flutter_google_places_sdk` for autocomplete suggestions
- Return `(displayName, LatLng)` pairs

#### `TripRepository`
- Serialize/deserialize `Trip` to `SharedPreferences`
- Methods: `saveTrip`, `loadTrip`, `clearTrip`

### Phase 3 — Domain Logic

#### `DepartureCalculator`
```
requiredDepartureTime = targetArrivalTime - currentTravelDuration
minutesEarlierThanPlanned = plannedDeparture - requiredDepartureTime
```
- Returns the new required departure time
- Returns the delta (how many minutes earlier than originally needed)
- Determines if a notification should fire:
  - Fire when `currentDuration > staticDuration` (traffic is worse than baseline)
  - Fire again whenever the required departure time shifts by ≥ 1 minute from the
    last notification (to avoid spam while still supporting repeated alerts)

### Phase 4 — UI

#### Home Screen
- Two `TextField`s with Places Autocomplete dropdown
- `TimePicker` for target arrival time
- "Start Monitoring" button (full-width, bottom of screen)
- Validates all fields before proceeding

#### Monitoring Screen
- Shows origin → destination summary
- Shows target arrival time
- Shows current travel duration (live)
- Shows "Leave by" time (computed, live)
- Shows delta minutes (e.g., "Leave 12 min earlier than planned")
- "Stop Monitoring" button

### Phase 5 — Background Service

Using `flutter_background_service`:

```
onCreate:
  - Start foreground notification (Android requirement)
  - Load active trip from TripRepository

onStart (repeating timer every 30s):
  1. Call RoutesApiService with trip's origin/destination
  2. Run DepartureCalculator
  3. If notification threshold met → call NotificationService
  4. If targetArrivalTime has passed → stop service, clear trip

onStop:
  - Cancel timer
  - Dismiss foreground notification
```

**Android:** Foreground service with `FOREGROUND_SERVICE_TYPE_DATA_SYNC` and a
persistent notification channel.

**iOS:** Uses `BGAppRefreshTask` — note iOS throttles background execution;
the 30-second interval is best-effort and may be less frequent in the background.
Document this limitation in the UI.

### Phase 6 — Notifications

Using `flutter_local_notifications`:

- Create a high-priority notification channel (`JITA_ALERTS`)
- Notification title: `"Leave now — traffic is building"`
- Notification body: `"Leave by HH:mm (X min earlier). Current travel time: Y min."`
- Use `ongoing: false` so the user can dismiss each alert
- Repeated: fires again when departure time shifts by another minute
- On notification tap: bring monitoring screen to foreground

### Phase 7 — Permissions & Platform Config

**Android (`AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

**iOS (`Info.plist`):**
```
UIBackgroundModes: fetch, processing
BGTaskSchedulerPermittedIdentifiers: com.jita.trafficmonitor
NSLocationWhenInUseUsageDescription
```

### Phase 8 — Testing & Polish
- Unit tests for `DepartureCalculator` (edge cases: trip already passed, zero traffic delta)
- Widget tests for Home Screen form validation
- Manual integration test: set a real trip, verify polling, trigger a test notification
- Handle API errors gracefully (no internet, API quota exceeded) — show snackbar, retry
- Handle the case where `ROUTE_NOT_FOUND` is returned
- Add loading states and error states to UI

---

## Key Logic: Departure Time Calculation

```
baseline_departure = targetArrivalTime - staticDuration   (computed once on trip start)
current_required_departure = targetArrivalTime - currentDuration

if current_required_departure < now:
    → User is already late — notify urgently

if current_required_departure < baseline_departure:
    delta = baseline_departure - current_required_departure
    → Notify: "Leave X minutes earlier than planned (by HH:mm)"
```

---

## Google Routes API Integration Notes

- **Endpoint:** `POST https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix`
- **Auth:** API key via `X-Goog-Api-Key` header
- **Field mask:** `X-Goog-FieldMask: originIndex,destinationIndex,duration,staticDuration,status,condition`
- **Routing preference:** `TRAFFIC_AWARE` (up to 625 elements; sufficient for 1×1)
- **Rate:** 1 request per 30 seconds = 2 RPM — well within quota limits
- **Cost:** Routes API Advanced SKU for traffic-aware requests — monitor usage

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| iOS kills background task before 30s | Inform users in UI; use BGTaskScheduler for best-effort scheduling |
| API key exposed in source | Use `--dart-define` build args, never commit key |
| Places Autocomplete cost | Cache recent searches; only call on debounced input |
| Notification fatigue | Only re-notify when departure time shifts ≥ 1 min |
| No network in background | Catch exceptions, log silently, retry next cycle |

---

## Delivery Milestones

| # | Milestone | Deliverable |
|---|---|---|
| 1 | Project scaffold | Runnable empty app with all deps, API key wired |
| 2 | Data + domain layer | Services, models, calculator with unit tests |
| 3 | UI complete | Home + Monitoring screens, form validation |
| 4 | Foreground polling | Timer-based polling works while app is open |
| 5 | Notifications | Alerts fire correctly in foreground |
| 6 | Background service | Polling + notifications work with app minimized |
| 7 | Polish & edge cases | Error handling, permissions flow, iOS caveats |
