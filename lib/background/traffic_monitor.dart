import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/trip_repository.dart';
import '../data/services/routes_api_service.dart';
import '../domain/departure_calculator.dart';
import '../notifications/notification_service.dart';

/// Default polling interval for the background service (in seconds).
const _defaultPollIntervalSeconds = 60;

/// Background polling task that monitors traffic and sends notifications.
class TrafficMonitor {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Configures and initializes the background service.
  Future<void> configure() async {
    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
        notificationChannelId: 'jita_foreground',
        initialNotificationTitle: 'JITA',
        initialNotificationContent: 'Monitoring traffic...',
      ),
    );
  }

  /// Starts the background service.
  Future<void> start() async {
    await _service.startService();
  }

  /// Stops the background service.
  Future<void> stop() async {
    _service.invoke('stop');
  }

  /// Whether the service is currently running.
  Future<bool> get isRunning => _service.isRunning();
}

/// iOS background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

/// Main service entry point — runs in an isolate.
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  final prefs = await SharedPreferences.getInstance();
  final tripRepo = TripRepository(prefs: prefs);
  final calculator = DepartureCalculator();
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Retrieve API key from shared preferences (set by the app before starting).
  final apiKey = prefs.getString('google_api_key') ?? '';
  if (apiKey.isEmpty) {
    service.stopSelf();
    return;
  }

  final routesApi = RoutesApiService(apiKey: apiKey);
  final timeFormat = DateFormat('HH:mm');

  // Read configurable poll interval (persisted by the app before starting).
  final pollIntervalSeconds =
      prefs.getInt('poll_interval_seconds') ?? _defaultPollIntervalSeconds;
  final pollInterval = Duration(seconds: pollIntervalSeconds);

  Timer? timer;

  service.on('stop').listen((_) {
    timer?.cancel();
    routesApi.dispose();
    service.stopSelf();
  });

  Future<void> poll() async {
    final trip = tripRepo.loadTrip();
    if (trip == null) {
      timer?.cancel();
      service.stopSelf();
      return;
    }

    // Stop if the target arrival time has passed.
    if (DateTime.now().isAfter(trip.targetArrivalTime)) {
      await tripRepo.clearTrip();
      timer?.cancel();
      service.stopSelf();
      return;
    }

    try {
      final result = await routesApi.getRouteDurations(trip);
      final departure = calculator.calculate(
        targetArrival: trip.targetArrivalTime,
        trafficDuration: result.trafficAwareDuration,
        staticDuration: result.staticDuration,
      );

      // Send status update to UI (if app is in foreground).
      service.invoke('status_update', {
        'currentDurationSeconds': result.trafficAwareDuration.inSeconds,
        'staticDurationSeconds': result.staticDuration.inSeconds,
        'requiredDeparture': departure.requiredDeparture.toIso8601String(),
        'deltaMinutes': departure.deltaMinutes,
        'isLate': departure.isLate,
      });

      if (departure.shouldNotify) {
        await notificationService.showTrafficAlert(
          leaveByTime: timeFormat.format(departure.requiredDeparture),
          deltaMinutes: departure.deltaMinutes,
          travelMinutes: result.trafficAwareDuration.inMinutes,
          isLate: departure.isLate,
        );
      }
    } on RoutesApiException {
      // Silently retry next cycle — don't crash the background service.
    } catch (_) {
      // Catch-all for network errors, etc.
    }
  }

  // Run an immediate first poll, then continue on the periodic timer.
  await poll();
  timer = Timer.periodic(pollInterval, (_) => poll());
}
