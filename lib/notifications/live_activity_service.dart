import 'dart:developer';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:live_activities/live_activities.dart';

/// App Group ID shared between the main app and the widget extension.
const _appGroupId = 'group.com.jita.jita';

/// Stable custom identifier for the single JITA live activity.
///
/// This is the `customId` parameter passed to `createOrUpdateActivity` and
/// **not** the system-generated activity ID. The `live_activities` plugin
/// uses this value to match an existing ActivityKit activity so it can
/// update it in place instead of creating a duplicate.
const _jitaActivityId = 'jita-route-monitor';

/// Service that manages iOS Live Activity for route monitoring.
///
/// Displays "Leave By" time and current route duration on the lock screen
/// and Dynamic Island. Data is passed to the native widget extension via
/// [UserDefaults] through the `live_activities` package.
///
/// This service uses [LiveActivities.createOrUpdateActivity] which is
/// idempotent: if a live activity with [_jitaActivityId] already exists it
/// will be updated; otherwise a new one is created. This eliminates an
/// entire class of bugs around stale activity IDs after app kills, race
/// conditions between main and background isolates, and the need to
/// manually persist/reload activity IDs across isolates.
class LiveActivityService {
  final LiveActivities _plugin = LiveActivities();

  /// Initializes the plugin. Must be called before any other method.
  Future<void> initialize() async {
    if (!Platform.isIOS) return;
    await _plugin.init(appGroupId: _appGroupId);
  }

  /// Starts (or updates) the live activity with the given route data.
  ///
  /// Uses [LiveActivities.createOrUpdateActivity] so that:
  /// - On the first call a new Live Activity is created.
  /// - On subsequent calls the existing activity is updated in place.
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
      final data = _buildData(
        leaveByTime: leaveByTime,
        currentDurationMinutes: currentDurationMinutes,
        destinationName: destinationName,
        isLate: isLate,
      );

      await _plugin.createOrUpdateActivity(_jitaActivityId, data);

      log(
        'Live activity started | customId=$_jitaActivityId',
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
  ///
  /// If no activity exists yet this will create one automatically (handled
  /// by the plugin's `createOrUpdateActivity` method). The
  /// [destinationName] should always be provided so the widget can display
  /// it regardless of whether the activity was just created or updated.
  Future<void> updateActivity({
    required DateTime leaveByTime,
    required int currentDurationMinutes,
    required bool isLate,
    required String destinationName,
  }) async {
    if (!Platform.isIOS) return;

    try {
      final data = _buildData(
        leaveByTime: leaveByTime,
        currentDurationMinutes: currentDurationMinutes,
        destinationName: destinationName,
        isLate: isLate,
      );

      await _plugin.createOrUpdateActivity(_jitaActivityId, data);

      final timeFormat = DateFormat('HH:mm');
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

    try {
      await _plugin.endAllActivities();
      log(
        'Live activity ended | customId=$_jitaActivityId',
        name: 'LiveActivityService',
      );
    } catch (e) {
      log(
        'Failed to end live activity: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    }
  }

  /// Ends all live activities for the app.
  Future<void> endAllActivities() async {
    if (!Platform.isIOS) return;

    try {
      await _plugin.endAllActivities();
    } catch (e) {
      log(
        'Failed to end all live activities: $e',
        name: 'LiveActivityService',
        level: 900,
      );
    }
  }

  /// Builds the data map sent to the native widget extension via UserDefaults.
  Map<String, dynamic> _buildData({
    required DateTime leaveByTime,
    required int currentDurationMinutes,
    required String destinationName,
    required bool isLate,
  }) {
    final timeFormat = DateFormat('HH:mm');
    return <String, dynamic>{
      'leaveByTime': timeFormat.format(leaveByTime),
      'currentDurationMinutes': currentDurationMinutes,
      'destinationName': destinationName,
      'isLate': isLate,
    };
  }
}
