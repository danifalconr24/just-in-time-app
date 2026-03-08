import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../background/traffic_monitor.dart';
import '../../data/models/trip.dart';
import '../../data/repositories/trip_repository.dart';
import '../home/home_controller.dart'
    show tripRepositoryProvider, trafficMonitorProvider;

/// Live monitoring state.
class MonitoringState {
  final Trip? trip;
  final Duration? currentDuration;
  final Duration? staticDuration;
  final DateTime? requiredDeparture;
  final int? deltaMinutes;
  final bool isLate;
  final bool isLoading;
  final String? errorMessage;

  const MonitoringState({
    this.trip,
    this.currentDuration,
    this.staticDuration,
    this.requiredDeparture,
    this.deltaMinutes,
    this.isLate = false,
    this.isLoading = true,
    this.errorMessage,
  });

  MonitoringState copyWith({
    Trip? trip,
    Duration? currentDuration,
    Duration? staticDuration,
    DateTime? requiredDeparture,
    int? deltaMinutes,
    bool? isLate,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MonitoringState(
      trip: trip ?? this.trip,
      currentDuration: currentDuration ?? this.currentDuration,
      staticDuration: staticDuration ?? this.staticDuration,
      requiredDeparture: requiredDeparture ?? this.requiredDeparture,
      deltaMinutes: deltaMinutes ?? this.deltaMinutes,
      isLate: isLate ?? this.isLate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Controller for the monitoring screen.
class MonitoringController extends StateNotifier<MonitoringState> {
  final TripRepository _tripRepository;
  final TrafficMonitor _trafficMonitor;
  StreamSubscription<Map<String, dynamic>?>? _statusSubscription;

  MonitoringController({
    required TripRepository tripRepository,
    required TrafficMonitor trafficMonitor,
  }) : _tripRepository = tripRepository,
       _trafficMonitor = trafficMonitor,
       super(const MonitoringState()) {
    _loadTrip();
    _listenToUpdates();
  }

  void _loadTrip() {
    final trip = _tripRepository.loadTrip();
    if (trip != null) {
      state = state.copyWith(trip: trip, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'No active trip found',
      );
    }
  }

  void _listenToUpdates() {
    _statusSubscription = FlutterBackgroundService().on('status_update').listen(
      (data) {
        if (data == null) return;

        final currentDuration = Duration(
          seconds: data['currentDurationSeconds'] as int,
        );
        final staticDuration = Duration(
          seconds: data['staticDurationSeconds'] as int,
        );
        final requiredDeparture = DateTime.parse(
          data['requiredDeparture'] as String,
        );
        final deltaMinutes = data['deltaMinutes'] as int;
        final isLate = data['isLate'] as bool;

        state = state.copyWith(
          currentDuration: currentDuration,
          staticDuration: staticDuration,
          requiredDeparture: requiredDeparture,
          deltaMinutes: deltaMinutes,
          isLate: isLate,
          isLoading: false,
        );
      },
    );
  }

  /// Stops monitoring and clears the active trip.
  Future<void> stopMonitoring() async {
    await _trafficMonitor.stop();
    await _tripRepository.clearTrip();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final monitoringControllerProvider =
    StateNotifierProvider.autoDispose<MonitoringController, MonitoringState>((
      ref,
    ) {
      return MonitoringController(
        tripRepository: ref.watch(tripRepositoryProvider),
        trafficMonitor: ref.watch(trafficMonitorProvider),
      );
    });
