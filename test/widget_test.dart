import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jita/app.dart';
import 'package:jita/ui/home/home_controller.dart';

void main() {
  testWidgets('App launches with JITA title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const JitaApp(),
      ),
    );

    expect(find.text('JITA'), findsOneWidget);
  });

  testWidgets('Home screen shows form fields', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const JitaApp(),
      ),
    );

    expect(find.text('Where do you need to be?'), findsOneWidget);
    expect(find.text('Start Monitoring'), findsOneWidget);
  });
}
