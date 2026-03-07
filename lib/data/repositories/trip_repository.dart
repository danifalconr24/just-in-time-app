import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip.dart';

/// Persists the active [Trip] using SharedPreferences.
class TripRepository {
  static const _tripKey = 'active_trip';

  final SharedPreferences _prefs;

  TripRepository({required SharedPreferences prefs}) : _prefs = prefs;

  /// Saves [trip] as the active trip.
  Future<void> saveTrip(Trip trip) async {
    final json = jsonEncode(trip.toJson());
    await _prefs.setString(_tripKey, json);
  }

  /// Loads the active trip, or `null` if none is saved.
  Trip? loadTrip() {
    final json = _prefs.getString(_tripKey);
    if (json == null) return null;

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return Trip.fromJson(map);
    } on FormatException {
      return null;
    }
  }

  /// Clears the active trip.
  Future<void> clearTrip() async {
    await _prefs.remove(_tripKey);
  }
}
