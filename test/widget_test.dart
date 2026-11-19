import 'package:craft_hub_app/main.dart';
import 'package:craft_hub_app/providers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettingsController();
    await settings.bootstrap();
    await tester.pumpWidget(CraftHubApp(initialSettings: settings));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
