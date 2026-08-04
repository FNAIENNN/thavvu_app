import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/screens/hod/hod_site_modules_screen.dart';
import 'package:thavvu_app/screens/hod/hod_sites_screen.dart';
import 'package:thavvu_app/services/hod_site_workspace_service.dart';

void main() {
  setUp(() {
    HodSiteWorkspaceService.resetForTests();
  });

  testWidgets('HOD selects admin site and creates Thavvu Point',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodSitesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Admin Created Sites'), findsOneWidget);
    expect(find.text('Create Thavvu Point'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Vijayawada River Bed'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Vijayawada River Bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vijayawada River Bed'));
    await tester.pumpAndSettle();

    expect(find.text('Thavvu Points'), findsOneWidget);
    expect(find.text('Create Thavvu Point'), findsOneWidget);

    await tester.tap(find.text('Create Thavvu Point'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Thavvu Point Name'),
      'Kakinada Road Work Point',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Supervisor Lead Acres'),
      '6',
    );
    expect(find.text('Supervisor Rajesh • THV-SUP-001'), findsOneWidget);
    await tester.tap(find.text('Create Draft Point'));
    await tester.pumpAndSettle();

    expect(find.text('Kakinada Road Work Point'), findsOneWidget);
    expect(find.textContaining('Supervisor Rajesh'), findsWidgets);
    expect(find.text('Grant'), findsOneWidget);
  });

  testWidgets(
      'HOD modules follow supervisor order and show notification badges',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HodSiteModulesScreen(
        siteName: 'Test Site',
        siteId: 'SITE-TST-001',
        thavvuPointName: 'Test Thavvu Point',
        assignedTo: 'Supervisor Test',
        moduleAlertCounts: {'Cash': 3, 'Maps': 1},
      ),
    ));
    await tester.pumpAndSettle();

    final titles = [
      'Machines',
      'Daily Data',
      'Attendance',
      'Maps',
      'Stock',
      'Rental',
      'Cash',
      'Food',
      'Tasks',
      'Reports',
      'Other',
    ];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget);
    }

    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
