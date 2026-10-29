import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civicai/main.dart';

void main() {
  testWidgets('CivicAI app smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CivicAIApp()),
    );
    // Pump a few frames to let the splash animation initialize
    await tester.pump(const Duration(milliseconds: 100));
    // Verify the app renders (splash screen should be visible)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
