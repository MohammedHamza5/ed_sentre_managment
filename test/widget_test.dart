import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ed_sentre/core/providers/settings_provider.dart';

void main() {
  testWidgets('Smoke build with SettingsProvider', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: Text('Smoke OK'),
          ),
        ),
      ),
    );

    expect(find.text('Smoke OK'), findsOneWidget);
  });
}


