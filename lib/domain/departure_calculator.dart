import '../data/models/route_status.dart';

/// Result of a departure calculation.
class DepartureResult {
  /// When the user must leave to arrive on time.
  final DateTime requiredDeparture;

  /// The baseline departure time (without traffic).
  final DateTime baselineDeparture;

  /// How many minutes earlier the user must leave vs the no-traffic baseline.
  /// Positive means traffic is worse; zero or negative means traffic is fine.
  final int deltaMinutes;

  /// Whether the user is already late (required departure is in the past).
  final bool isLate;

  /// Whether a notification should fire for this result.
  final bool shouldNotify;

  const DepartureResult({
    required this.requiredDeparture,
    required this.baselineDeparture,
    required this.deltaMinutes,
    required this.isLate,
    required this.shouldNotify,
  });

  @override
  String toString() =>
      'DepartureResult('
      'depart: ${requiredDeparture.toIso8601String()}, '
      'delta: ${deltaMinutes}m, '
      'late: $isLate, '
      'notify: $shouldNotify)';
}

/// Core business logic: computes when the user must leave and whether to alert.
class DepartureCalculator {
  DateTime? _lastNotifiedDeparture;

  /// Resets the notification state (e.g., when starting a new trip).
  void reset() {
    _lastNotifiedDeparture = null;
  }

  /// Calculates the required departure time and whether to notify.
  ///
  /// [targetArrival] — when the user wants to arrive.
  /// [trafficDuration] — current traffic-aware travel time.
  /// [staticDuration] — baseline travel time without traffic.
  /// [now] — current time (injectable for testing).
  DepartureResult calculate({
    required DateTime targetArrival,
    required Duration trafficDuration,
    required Duration staticDuration,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    final baselineDeparture = targetArrival.subtract(staticDuration);
    final requiredDeparture = targetArrival.subtract(trafficDuration);

    final isLate = requiredDeparture.isBefore(currentTime);

    // Delta: how many minutes earlier than baseline the user must leave.
    // Positive means traffic is worse than normal.
    final deltaMinutes = baselineDeparture
        .difference(requiredDeparture)
        .inMinutes;

    // Determine whether to fire a notification:
    // 1. Traffic is worse than baseline (current duration > static duration).
    // 2. The required departure shifted by >= 1 minute since last notification.
    final trafficIsWorse = trafficDuration > staticDuration;
    final shouldNotify = _shouldNotify(
      trafficIsWorse: trafficIsWorse,
      isLate: isLate,
      requiredDeparture: requiredDeparture,
    );

    if (shouldNotify) {
      _lastNotifiedDeparture = requiredDeparture;
    }

    return DepartureResult(
      requiredDeparture: requiredDeparture,
      baselineDeparture: baselineDeparture,
      deltaMinutes: deltaMinutes,
      isLate: isLate,
      shouldNotify: shouldNotify,
    );
  }

  bool _shouldNotify({
    required bool trafficIsWorse,
    required bool isLate,
    required DateTime requiredDeparture,
  }) {
    // Always notify if the user is already late.
    if (isLate) {
      if (_lastNotifiedDeparture == null) return true;
      // Re-notify if departure shifted by >= 1 minute.
      final shift = _lastNotifiedDeparture!
          .difference(requiredDeparture)
          .inMinutes
          .abs();
      return shift >= 1;
    }

    // Only notify when traffic is actually worse than baseline.
    if (!trafficIsWorse) return false;

    // First time notifying.
    if (_lastNotifiedDeparture == null) return true;

    // Re-notify when departure time shifted by >= 1 minute.
    final shift = _lastNotifiedDeparture!
        .difference(requiredDeparture)
        .inMinutes
        .abs();
    return shift >= 1;
  }

  /// Builds a [RouteStatus] from the calculation inputs.
  RouteStatus buildRouteStatus({
    required Duration trafficDuration,
    required Duration staticDuration,
    required DateTime requiredDeparture,
  }) {
    return RouteStatus(
      currentDuration: trafficDuration,
      staticDuration: staticDuration,
      sampledAt: DateTime.now(),
      requiredDeparture: requiredDeparture,
    );
  }
}
