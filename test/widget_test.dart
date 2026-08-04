import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thavvu_app/screens/hod/hod_alerts_screen.dart';
import 'package:thavvu_app/screens/main_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'user_name': 'Rajesh Kumar',
      'user_email': 'rajesh@thavvu.com',
      'emp_id': 'EMP-001',
      'user_role': 'supervisor',
    });
  });

  testWidgets('MainShell loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MainShell), findsOneWidget);
  });

  testWidgets('Dedicated HOD alert screen renders title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodAlertsScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HOD Alerts'), findsWidgets);
  });
}
