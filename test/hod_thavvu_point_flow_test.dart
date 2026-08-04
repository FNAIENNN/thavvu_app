import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/screens/hod/hod_sites_screen.dart';
import 'package:thavvu_app/services/hod_site_workspace_service.dart';

void main() {
  setUp(() {
    HodSiteWorkspaceService.resetForTests();
  });

  testWidgets('HOD selects an admin site, creates a point and opens modules',
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
      'North Silt Loading Point',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Supervisor Lead Acres'),
      '8',
    );
    expect(find.text('Supervisor Rajesh • THV-SUP-001'), findsOneWidget);
    await tester.tap(find.text('Create Draft Point'));
    await tester.pumpAndSettle();

    expect(find.text('North Silt Loading Point'), findsOneWidget);
    expect(find.text('Grant'), findsOneWidget);
    await tester.tap(find.text('Grant'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('North Silt Loading Point'));
    await tester.pumpAndSettle();

    expect(find.text('HOD Modules'), findsOneWidget);
    expect(find.text('North Silt Loading Point'), findsWidgets);
    expect(find.text('Machines'), findsOneWidget);
    expect(find.text('Daily Data'), findsOneWidget);
  });

  test('HOD-created supervisor login receives only granted points', () async {
    final service = HodSiteWorkspaceService();
    final supervisor = await service.createSupervisor(
      name: 'Supervisor Ramesh',
      email: 'ramesh@thavvu.com',
      phone: '+91 90000 00000',
      password: 'ramesh123',
    );
    final sites = await service.adminCreatedSites();
    final point = await service.createThavvuPoint(
      site: sites.first,
      pointName: 'Ramesh Lead Point',
      supervisorId: supervisor.id,
      assignedAcres: 7,
    );

    expect(
      await service.authenticateSupervisor(
        identifier: supervisor.email,
        password: 'ramesh123',
      ),
      isNotNull,
    );
    expect(await service.grantedPointsForSupervisor(supervisor.id), isEmpty);

    await service.grantThavvuPoint(point.id);
    final granted = await service.grantedPointsForSupervisor(supervisor.id);

    expect(granted, hasLength(1));
    expect(granted.single.pointName, 'Ramesh Lead Point');
    expect(granted.single.assignedAcres, 7);
  });
}
