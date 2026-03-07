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

    final response = await _placesSdk.findAutocompletePredictions(query);
    return response.predictions;
  }

  /// Fetches the place details (including coordinates) for a [placeId].
  Future<PlaceResult?> getPlaceDetails(String placeId) async {
    final response = await _placesSdk.fetchPlace(
      placeId,
      fields: [places_sdk.PlaceField.Name, places_sdk.PlaceField.Location],
    );

    final place = response.place;
    if (place == null || place.latLng == null) return null;

    return PlaceResult(
      displayName: place.name ?? '',
      latLng: LatLng(latitude: place.latLng!.lat, longitude: place.latLng!.lng),
    );
  }
}
