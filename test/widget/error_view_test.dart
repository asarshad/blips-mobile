@Tags(['widget'])
library error_view_test;

import 'package:blips_mobile/core/error/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ErrorView renders a friendly message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(error: Exception('boom')),
        ),
      ),
    );

    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });
}
