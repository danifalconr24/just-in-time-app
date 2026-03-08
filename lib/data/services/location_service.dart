import 'dart:developer';

import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../models/trip.dart';

/// A place result from autocomplete.
class PlaceResult {
  final String displayName;
  final LatLng latLng;

  const PlaceResult({required this.displayName, required this.latLng});
}

/// Exception thrown when location permission is denied by the user.
class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException(this.message);

  @override
  String toString() => 'LocationPermissionDeniedException: $message';
}

/// Exception thrown when location services are disabled on the device.
class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException(this.message);

  @override
  String toString() => 'LocationServiceDisabledException: $message';
}

/// Wraps [FlutterGooglePlacesSdk] for autocomplete suggestions
/// and [Geolocator] for device GPS location.
class LocationService {
  final places_sdk.FlutterGooglePlacesSdk _placesSdk;

  LocationService({required String apiKey})
    : _placesSdk = places_sdk.FlutterGooglePlacesSdk(apiKey);

  /// Returns autocomplete predictions for [query].
  Future<List<places_sdk.AutocompletePrediction>> getAutocomplete(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    log('Autocomplete query="$query"', name: 'PlacesApi');

    try {
      final response = await _placesSdk.findAutocompletePredictions(query);
      log(
        'Autocomplete query="$query" returned '
        '${response.predictions.length} predictions',
        name: 'PlacesApi',
      );
      return response.predictions;
    } catch (e) {
      log(
        'Autocomplete query="$query" FAILED: $e',
        name: 'PlacesApi',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Fetches the place details (including coordinates) for a [placeId].
  Future<PlaceResult?> getPlaceDetails(String placeId) async {
    log('FetchPlace placeId="$placeId"', name: 'PlacesApi');

    try {
      final response = await _placesSdk.fetchPlace(
        placeId,
        fields: [places_sdk.PlaceField.Name, places_sdk.PlaceField.Location],
      );

      final place = response.place;
      if (place == null || place.latLng == null) {
        log(
          'FetchPlace placeId="$placeId" returned null place or location',
          name: 'PlacesApi',
          level: 900,
        );
        return null;
      }

      log(
        'FetchPlace placeId="$placeId" -> "${place.name}" '
        '(${place.latLng!.lat}, ${place.latLng!.lng})',
        name: 'PlacesApi',
      );

      return PlaceResult(
        displayName: place.name ?? '',
        latLng: LatLng(
          latitude: place.latLng!.lat,
          longitude: place.latLng!.lng,
        ),
      );
    } catch (e) {
      log(
        'FetchPlace placeId="$placeId" FAILED: $e',
        name: 'PlacesApi',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Requests location permission, gets the current device position,
  /// and reverse-geocodes it into a [PlaceResult].
  ///
  /// Throws [LocationServiceDisabledException] if location services are off.
  /// Throws [LocationPermissionDeniedException] if the user denies permission.
  Future<PlaceResult> getCurrentLocation() async {
    log('getCurrentLocation: checking service availability', name: 'Location');

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException(
        'Location services are disabled. Please enable them in Settings.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      log('getCurrentLocation: requesting permission', name: 'Location');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException(
          'Location permission was denied.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'Location permission is permanently denied. '
        'Please enable it in your device settings.',
      );
    }

    log('getCurrentLocation: fetching position', name: 'Location');
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    log(
      'getCurrentLocation: got (${position.latitude}, ${position.longitude})',
      name: 'Location',
    );

    final latLng = LatLng(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    // Reverse geocode to get a human-readable address.
    final displayName = await _reverseGeocode(
      position.latitude,
      position.longitude,
    );

    log('getCurrentLocation: resolved to "$displayName"', name: 'Location');

    return PlaceResult(displayName: displayName, latLng: latLng);
  }

  /// Reverse-geocodes coordinates into a readable address string.
  /// Falls back to raw coordinates if geocoding fails.
  Future<String> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Build a concise display name from available components.
        final parts = <String>[
          if (placemark.street != null && placemark.street!.isNotEmpty)
            placemark.street!,
          if (placemark.locality != null && placemark.locality!.isNotEmpty)
            placemark.locality!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (e) {
      log('Reverse geocoding failed: $e', name: 'Location', level: 900);
    }
    // Fallback to raw coordinates.
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}
