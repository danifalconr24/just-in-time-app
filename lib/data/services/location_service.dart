import 'dart:developer';

import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;

import '../models/trip.dart';

/// A place result from autocomplete.
class PlaceResult {
  final String displayName;
  final LatLng latLng;

  const PlaceResult({required this.displayName, required this.latLng});
}

/// Wraps [FlutterGooglePlacesSdk] for autocomplete suggestions.
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
}
