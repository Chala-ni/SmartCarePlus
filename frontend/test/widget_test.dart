// SMARTCARE+ Widget Tests
//
// Basic smoke test for the app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smartcare_plus/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartCarePlusApp(),
      ),
    );

    // Verify that the app builds without error
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
