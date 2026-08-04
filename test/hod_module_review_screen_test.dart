import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/screens/hod_module_review_screen.dart';

void main() {
  testWidgets(
      'HOD module review screen is frontend-only until backend is connected',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HodModuleReviewScreen(
        title: 'HOD Cash',
        moduleFilter: 'Cash',
        actorId: 'HOD-001',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('HOD Cash'), findsOneWidget);
    expect(find.text('Module Alerts'), findsOneWidget);
    expect(find.text('Cash request waiting'), findsOneWidget);
    expect(find.text('No requests found'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
  });
}
