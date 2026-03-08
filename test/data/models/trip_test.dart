import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jita/data/models/trip.dart';

void main() {
  group('Trip', () {
    test('serializes to JSON and back', () {
      final trip = Trip(
        originName: 'Home',
        originLatLng: const LatLng(latitude: 40.7128, longitude: -74.0060),
        destinationName: 'Office',
        destinationLatLng: const LatLng(latitude: 40.7580, longitude: -73.9855),
        targetArrivalTime: DateTime(2026, 3, 7, 9, 0),
      );

      final json = trip.toJson();
      final restored = Trip.fromJson(json);

      expect(restored.originName, trip.originName);
      expect(restored.originLatLng, trip.originLatLng);
      expect(restored.destinationName, trip.destinationName);
      expect(restored.destinationLatLng, trip.destinationLatLng);
      expect(restored.targetArrivalTime, trip.targetArrivalTime);
    });

    test('round-trips through JSON string encoding', () {
      final trip = Trip(
        originName: 'Central Park',
        originLatLng: const LatLng(latitude: 40.7829, longitude: -73.9654),
        destinationName: 'Times Square',
        destinationLatLng: const LatLng(latitude: 40.7580, longitude: -73.9855),
        targetArrivalTime: DateTime(2026, 12, 25, 18, 30),
      );

      final encoded = jsonEncode(trip.toJson());
      final decoded = Trip.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.originName, trip.originName);
      expect(decoded.targetArrivalTime, trip.targetArrivalTime);
    });
  });

  group('LatLng', () {
    test('equality works correctly', () {
      const a = LatLng(latitude: 40.0, longitude: -74.0);
      const b = LatLng(latitude: 40.0, longitude: -74.0);
      const c = LatLng(latitude: 41.0, longitude: -74.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('serializes to JSON and back', () {
      const original = LatLng(latitude: 51.5074, longitude: -0.1278);
      final json = original.toJson();
      final restored = LatLng.fromJson(json);

      expect(restored, equals(original));
    });
  });
}
