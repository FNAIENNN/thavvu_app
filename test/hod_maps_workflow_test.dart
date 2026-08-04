import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/screens/hod/modules/hod_maps_screen.dart';
import 'package:thavvu_app/screens/maps_screen.dart';
import 'package:thavvu_app/services/hod_workflow_store.dart';

void main() {
  testWidgets('supervisor Maps screen remains frontend-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MapsScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Maps & Specifications'), findsOneWidget);
    expect(find.text('Map View'), findsOneWidget);
  });

  test('HOD map upload local persistence is disabled', () async {
    final store = HodWorkflowStore();

    expect(await store.hodMapUploads(), isEmpty);
    expect(await store.mapUploadsForSupervisor('SUP-VJA-001'), isEmpty);
  });

  testWidgets(
      'HOD Maps screen loads successfully',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodMapsScreen()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HodMapsScreen), findsOneWidget);
  });
}
