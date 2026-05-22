import 'package:craft_hub_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const CraftHubApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
