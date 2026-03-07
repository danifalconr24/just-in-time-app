/// The result of polling the Routes API for an active trip.
class RouteStatus {
  /// Traffic-aware travel duration.
  final Duration currentDuration;

  /// Baseline travel duration without traffic.
  final Duration staticDuration;

  /// When this sample was taken.
  final DateTime sampledAt;

  /// Computed required departure time to arrive on schedule.
  final DateTime requiredDeparture;

  const RouteStatus({
    required this.currentDuration,
    required this.staticDuration,
    required this.sampledAt,
    required this.requiredDeparture,
  });

  @override
  String toString() =>
      'RouteStatus(current: ${currentDuration.inMinutes}m, '
      'static: ${staticDuration.inMinutes}m, '
      'depart by: ${requiredDeparture.toIso8601String()})';
}
