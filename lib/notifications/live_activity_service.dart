import 'dart:developer';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:live_activities/live_activities.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Group ID shared between the main app and the widget extension.
const _appGroupId = 'group.com.jita.jita';

/// Stable identifier for the single JITA live activity instance.
const _jitaActivityId = 'jita-route-monitor';

/// SharedPreferences key for persisting the current live activity ID.
const _activityIdKey = 'live_activity_id';

/// Service that manages iOS Live Activity for route monitoring.
///
/// Displays "Leave By" time and current route duration on the lock screen
/// and Dynamic Island. Data is passed to the native widget extension via
/// [UserDefaults] through the `live_activities` package.
class LiveActivityService {
  final LiveActivities _plugin = LiveActivities();
  String? _activityId;

  /// Initializes the plugin. Must be called before any other method.
  Future<void> initialize() async {
    if (!Platform.isIOS) return;
    await _plugin.init(appGroupId: _appGroupId);
  }

  /// Starts a new live activity with the given route data.
  ///
  /// [leaveByTime] is the computed required departure time.
  /// [currentDurationMinutes] is the current traffic-aware travel time in minutes.
  /// [destinationName] is the display name of the destination.
  /// [isLate] indicates whether the user should have already departed.
  Future<void> startActivity({
    required DateTime leaveByTime,
    required int currentDurationMinutes,
    required String destinationName,
    required bool isLate,
  }) async {
    if (!Platform.isIOS) return;

    try {
      final timeFormat = DateFormat('HH:mm');
      final data = <String, dynamic>{
        'leaveByTime': timeFormat.format(leaveByTime),
        'currentDurationMinutes': currentDurationMinutes,
        'destinationName': destinationName,
        'isLate': isLate,
      };

      _activityId = await _plugin.createActivity(_jitaActivityId, data);
      await _persistActivityId(_activityId);

      log(
        'Live activity started | id=$_activityId',
        name: 'LiveActivityService',
      );
    } catch (e) {
      log(
        'Failed to start live activity: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    }
  }

  /// Updates the existing live activity with fresh route data.
  Future<void> updateActivity({
    required DateTime leaveByTime,
    required int currentDurationMinutes,
    required bool isLate,
  }) async {
    if (!Platform.isIOS) return;

    _activityId ??= await _loadPersistedActivityId();
    if (_activityId == null) return;

    try {
      final timeFormat = DateFormat('HH:mm');
      final data = <String, dynamic>{
        'leaveByTime': timeFormat.format(leaveByTime),
        'currentDurationMinutes': currentDurationMinutes,
        'isLate': isLate,
      };

      await _plugin.updateActivity(_activityId!, data);

      log(
        'Live activity updated | leave by ${timeFormat.format(leaveByTime)} '
        '| duration=${currentDurationMinutes}min',
        name: 'LiveActivityService',
      );
    } catch (e) {
      log(
        'Failed to update live activity: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    }
  }

  /// Ends the current live activity.
  Future<void> endActivity() async {
    if (!Platform.isIOS) return;

    _activityId ??= await _loadPersistedActivityId();
    if (_activityId == null) return;

    try {
      await _plugin.endActivity(_activityId!);
      log('Live activity ended | id=$_activityId', name: 'LiveActivityService');
    } catch (e) {
      log(
        'Failed to end live activity: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    } finally {
      _activityId = null;
      await _persistActivityId(null);
    }
  }

  /// Ends all live activities for the app.
  Future<void> endAllActivities() async {
    if (!Platform.isIOS) return;

    try {
      await _plugin.endAllActivities();
      _activityId = null;
      await _persistActivityId(null);
    } catch (e) {
      log(
        'Failed to end all live activities: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    }
  }

  /// Persists the activity ID so the background isolate can access it.
  Future<void> _persistActivityId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setString(_activityIdKey, id);
    } else {
      await prefs.remove(_activityIdKey);
    }
  }

  /// Loads the persisted activity ID (for use in background isolate).
  Future<String?> _loadPersistedActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activityIdKey);
  }
}
