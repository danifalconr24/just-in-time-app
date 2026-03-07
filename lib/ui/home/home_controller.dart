import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../background/traffic_monitor.dart';
import '../../data/models/trip.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/services/location_service.dart';

/// State for the home screen form.
class HomeState {
  final PlaceResult? origin;
  final PlaceResult? destination;
  final TimeOfDay? arrivalTime;
  final bool isLoading;
  final String? errorMessage;

  const HomeState({
    this.origin,
    this.destination,
    this.arrivalTime,
    this.isLoading = false,
    this.errorMessage,
  });

  HomeState copyWith({
    PlaceResult? origin,
    PlaceResult? destination,
    TimeOfDay? arrivalTime,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomeState(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Whether the form is complete and ready to start monitoring.
  bool get isValid =>
      origin != null && destination != null && arrivalTime != null;
}

/// Controller for the home screen.
class HomeController extends StateNotifier<HomeState> {
  final LocationService _locationService;
  final TripRepository _tripRepository;
  final TrafficMonitor _trafficMonitor;

  HomeController({
    required LocationService locationService,
    required TripRepository tripRepository,
    required TrafficMonitor trafficMonitor,
  }) : _locationService = locationService,
       _tripRepository = tripRepository,
       _trafficMonitor = trafficMonitor,
       super(const HomeState());

  LocationService get locationService => _locationService;

  void setOrigin(PlaceResult place) {
    state = state.copyWith(origin: place, errorMessage: null);
  }

  void setDestination(PlaceResult place) {
    state = state.copyWith(destination: place, errorMessage: null);
  }

  void setArrivalTime(TimeOfDay time) {
    state = state.copyWith(arrivalTime: time, errorMessage: null);
  }

  void clearOrigin() {
    state = HomeState(
      destination: state.destination,
      arrivalTime: state.arrivalTime,
    );
  }

  void clearDestination() {
    state = HomeState(origin: state.origin, arrivalTime: state.arrivalTime);
  }

  /// Validates the form and starts monitoring.
  Future<bool> startMonitoring() async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Please fill in all fields');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Build the target arrival DateTime from today + selected time.
      final now = DateTime.now();
      var targetArrival = DateTime(
        now.year,
        now.month,
        now.day,
        state.arrivalTime!.hour,
        state.arrivalTime!.minute,
      );

      // If the selected time is earlier than now, assume tomorrow.
      if (targetArrival.isBefore(now)) {
        targetArrival = targetArrival.add(const Duration(days: 1));
      }

      final trip = Trip(
        originName: state.origin!.displayName,
        originLatLng: state.origin!.latLng,
        destinationName: state.destination!.displayName,
        destinationLatLng: state.destination!.latLng,
        targetArrivalTime: targetArrival,
      );

      await _tripRepository.saveTrip(trip);
      await _trafficMonitor.start();

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to start monitoring: $e',
      );
      return false;
    }
  }
}

/// Riverpod providers.

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(prefs: ref.watch(sharedPreferencesProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  // API key is injected via --dart-define at build time.
  const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  return LocationService(apiKey: apiKey);
});

final trafficMonitorProvider = Provider<TrafficMonitor>((ref) {
  return TrafficMonitor();
});

final homeControllerProvider = StateNotifierProvider<HomeController, HomeState>(
  (ref) {
    return HomeController(
      locationService: ref.watch(locationServiceProvider),
      tripRepository: ref.watch(tripRepositoryProvider),
      trafficMonitor: ref.watch(trafficMonitorProvider),
    );
  },
);
