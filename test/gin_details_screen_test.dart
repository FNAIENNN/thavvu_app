import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/screens/gin/gin_bill_details_screen.dart';
import 'package:thavvu_app/services/gin_repository.dart';

void main() {
  GinBill _buildBill({
    double billed1 = 500,
    double received1 = 466,
    double billed2 = 300,
    double received2 = 300,
  }) {
    return GinBill.draft(
      ginNo: 'GIN-TEST-1',
      billNumber: 'BILL-TEST-1',
      supplierName: 'Test Supplier',
      thavvuPointId: 'TP-VJA-001',
      thavvuPointName: 'East Ramp Loading Point',
      lines: [
        GinBillLine(
          id: 'l1',
          itemName: 'TMT Steel Bar 12mm',
          orderedQty: billed1,
          billedQty: billed1,
          receivedQty: received1,
          uom: 'KG',
        ),
        GinBillLine(
          id: 'l2',
          itemName: 'TMT Steel Bar 8mm',
          orderedQty: billed2,
          billedQty: billed2,
          receivedQty: received2,
          uom: 'KG',
        ),
      ],
    );
  }

  testWidgets('supervisor GIN table renders without overflow (large shortage)',
      (tester) async {
    final bill = _buildBill(billed1: 500000, received1: 12345, received2: 300);
    await tester.pumpWidget(MaterialApp(
      home: GinBillDetailsScreen(
        bill: bill,
        mode: GinReviewMode.supervisor,
        repo: GinRepository(),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'table must not overflow with large numbers');
  });

  testWidgets('supervisor GIN table renders without overflow (narrow width)',
      (tester) async {
    final bill = _buildBill();
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GinBillDetailsScreen(
        bill: bill,
        mode: GinReviewMode.supervisor,
        repo: GinRepository(),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'table must not overflow on narrow viewports');
  });

  testWidgets('HOD mode renders table without overflow', (tester) async {
    final bill = _buildBill();
    await tester.pumpWidget(MaterialApp(
      home: GinBillDetailsScreen(
        bill: bill,
        mode: GinReviewMode.hod,
        repo: GinRepository(),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping ACTIONS button resolves the line and updates count',
      (tester) async {
    final bill = _buildBill(received1: 466, received2: 300);
    await tester.pumpWidget(MaterialApp(
      home: GinBillDetailsScreen(
        bill: bill,
        mode: GinReviewMode.supervisor,
        repo: GinRepository(),
      ),
    ));
    await tester.pump();

    // Matched line: the ✓ OK action button is visible; tapping resolves it.
    expect(find.text('✓ OK'), findsWidgets);
    // Bottom bar should initially say both lines need confirmation.
    expect(find.textContaining('2 left'), findsOneWidget);

    await tester.tap(find.text('✓ OK').last);
    await tester.pumpAndSettle();
    // One line resolved -> 1 left.
    expect(find.textContaining('1 left'), findsOneWidget);
  });
}
