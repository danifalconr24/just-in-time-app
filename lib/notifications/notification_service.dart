import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local push notifications for traffic alerts.
class NotificationService {
  static const _channelId = 'jita_alerts';
  static const _channelName = 'JITA Traffic Alerts';
  static const _channelDescription =
      'Urgent alerts when you need to leave earlier due to traffic';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  /// Initializes the notification plugin and creates channels.
  Future<void> initialize({void Function(NotificationResponse)? onTap}) async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings, onDidReceiveNotificationResponse: onTap);

    _initialized = true;
  }

  /// Shows a traffic alert notification.
  ///
  /// [leaveByTime] — formatted "HH:mm" departure time.
  /// [deltaMinutes] — how many minutes earlier than planned.
  /// [travelMinutes] — current travel time in minutes.
  /// [isLate] — whether the user is already late.
  Future<void> showTrafficAlert({
    required String leaveByTime,
    required int deltaMinutes,
    required int travelMinutes,
    required bool isLate,
  }) async {
    final title = isLate
        ? 'You should have already left!'
        : 'Leave now \u2014 traffic is building';

    final body = isLate
        ? 'You are late! Current travel time: $travelMinutes min.'
        : 'Leave by $leaveByTime ($deltaMinutes min earlier). '
              'Current travel time: $travelMinutes min.';

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      0, // Use same ID so notifications replace each other
      title,
      body,
      details,
    );
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
