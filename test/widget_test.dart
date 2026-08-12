import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sugar_plus/main.dart';

void main() {
  testWidgets('App builds and shows a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
