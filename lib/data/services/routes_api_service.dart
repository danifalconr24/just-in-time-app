import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import '../models/trip.dart';

/// Result from the Routes API containing travel durations.
class RouteMatrixResult {
  final Duration trafficAwareDuration;
  final Duration staticDuration;

  const RouteMatrixResult({
    required this.trafficAwareDuration,
    required this.staticDuration,
  });
}

/// Calls the Google Routes API `computeRouteMatrix` endpoint.
class RoutesApiService {
  static const _baseUrl =
      'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix';

  static const _fieldMask =
      'originIndex,destinationIndex,duration,staticDuration,status,condition';

  final String apiKey;
  final http.Client _client;

  RoutesApiService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// Fetches the current traffic-aware and static travel durations for [trip].
  ///
  /// Throws [RoutesApiException] on API errors.
  Future<RouteMatrixResult> getRouteDurations(Trip trip) async {
    final body = jsonEncode({
      'origins': [
        {
          'waypoint': {
            'location': {
              'latLng': {
                'latitude': trip.originLatLng.latitude,
                'longitude': trip.originLatLng.longitude,
              },
            },
          },
        },
      ],
      'destinations': [
        {
          'waypoint': {
            'location': {
              'latLng': {
                'latitude': trip.destinationLatLng.latitude,
                'longitude': trip.destinationLatLng.longitude,
              },
            },
          },
        },
      ],
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
    });

    log(
      'POST $_baseUrl | origin=(${trip.originLatLng.latitude}, '
      '${trip.originLatLng.longitude}) dest=(${trip.destinationLatLng.latitude}, '
      '${trip.destinationLatLng.longitude})',
      name: 'RoutesApi',
    );

    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': _fieldMask,
        },
        body: body,
      );
    } catch (e) {
      stopwatch.stop();
      log(
        'POST $_baseUrl FAILED after ${stopwatch.elapsedMilliseconds}ms: $e',
        name: 'RoutesApi',
        level: 1000,
      );
      rethrow;
    }
    stopwatch.stop();

    if (response.statusCode != 200) {
      log(
        'POST $_baseUrl ${response.statusCode} after '
        '${stopwatch.elapsedMilliseconds}ms: ${response.body}',
        name: 'RoutesApi',
        level: 900,
      );
      throw RoutesApiException(
        'Routes API returned status ${response.statusCode}: ${response.body}',
      );
    }

    // The response is a JSON array of route matrix elements.
    final List<dynamic> elements = jsonDecode(response.body) as List<dynamic>;

    if (elements.isEmpty) {
      log(
        'POST $_baseUrl 200 but empty response after '
        '${stopwatch.elapsedMilliseconds}ms',
        name: 'RoutesApi',
        level: 900,
      );
      throw RoutesApiException('Routes API returned empty response');
    }

    final element = elements[0] as Map<String, dynamic>;

    final status = element['status'] as Map<String, dynamic>?;
    if (status != null && status['code'] != null && status['code'] != 0) {
      log(
        'POST $_baseUrl element error after ${stopwatch.elapsedMilliseconds}ms: '
        '${status['message'] ?? 'unknown'}',
        name: 'RoutesApi',
        level: 900,
      );
      throw RoutesApiException(
        'Route matrix element error: ${status['message'] ?? 'unknown'}',
      );
    }

    final condition = element['condition'] as String?;
    if (condition == 'ROUTE_NOT_FOUND') {
      log(
        'POST $_baseUrl ROUTE_NOT_FOUND after '
        '${stopwatch.elapsedMilliseconds}ms',
        name: 'RoutesApi',
        level: 900,
      );
      throw RouteNotFoundException(
        'No route found between origin and destination',
      );
    }

    final trafficDuration = _parseDuration(element['duration'] as String);
    final staticDuration = _parseDuration(element['staticDuration'] as String);

    log(
      'POST $_baseUrl 200 in ${stopwatch.elapsedMilliseconds}ms | '
      'traffic=${trafficDuration.inMinutes}min '
      'static=${staticDuration.inMinutes}min',
      name: 'RoutesApi',
    );

    return RouteMatrixResult(
      trafficAwareDuration: trafficDuration,
      staticDuration: staticDuration,
    );
  }

  /// Parses a duration string like "1234s" into a [Duration].
  Duration _parseDuration(String durationStr) {
    // Google returns durations as strings like "1234s"
    final seconds = int.parse(durationStr.replaceAll('s', ''));
    return Duration(seconds: seconds);
  }

  void dispose() {
    _client.close();
  }
}

/// General Routes API error.
class RoutesApiException implements Exception {
  final String message;
  const RoutesApiException(this.message);

  @override
  String toString() => 'RoutesApiException: $message';
}

/// Thrown when no route exists between the given points.
class RouteNotFoundException extends RoutesApiException {
  const RouteNotFoundException(super.message);

  @override
  String toString() => 'RouteNotFoundException: $message';
}
