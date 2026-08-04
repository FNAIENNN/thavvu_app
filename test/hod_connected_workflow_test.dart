import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thavvu_app/screens/hod/hod_alerts_screen.dart';
import 'package:thavvu_app/screens/hod/modules/hod_cash_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HOD alerts screen no longer loads local shared alerts',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodAlertsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HOD Alerts'), findsWidgets);
    expect(find.text('HOD Work History Table'), findsOneWidget);
  });

  testWidgets('HOD cash module issues cash allocations', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodCashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('HOD Cash'), findsWidgets);
    expect(find.text('AVAILABLE BALANCE'), findsOneWidget);

    await tester.tap(find.text('Allocations'));
    await tester.pumpAndSettle();

    expect(find.text('Issue cash to supervisor'), findsOneWidget);
  });
}
