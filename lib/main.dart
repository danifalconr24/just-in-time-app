import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'background/traffic_monitor.dart';
import 'notifications/live_activity_service.dart';
import 'ui/home/home_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Configure background service.
  final trafficMonitor = TrafficMonitor();
  await trafficMonitor.configure();

  // Initialize iOS Live Activity support.
  final liveActivityService = LiveActivityService();
  await liveActivityService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveActivityServiceProvider.overrideWithValue(liveActivityService),
      ],
      child: const JitaApp(),
    ),
  );
}
