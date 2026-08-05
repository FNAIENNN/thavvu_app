import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/services/gin_repository.dart';

void main() {
  group('GinBillLine reconciliation', () {
    test('matched when billed == received', () {
      final line = GinBillLine(
        id: 'l1',
        itemName: 'Cement',
        orderedQty: 200,
        billedQty: 200,
        receivedQty: 200,
      );
      expect(line.status, GinReconciliationStatus.matched);
      expect(line.diffBilledReceived, 0);
      expect(line.suggestedAction, GinLineAction.done);
    });

    test('shortage when received < billed', () {
      final line = GinBillLine(
        id: 'l2',
        itemName: 'TMT 8mm',
        orderedQty: 300,
        billedQty: 300,
        receivedQty: 250,
      );
      expect(line.status, GinReconciliationStatus.shortage);
      expect(line.diffBilledReceived, 50);
      expect(line.suggestedAction, GinLineAction.reorder);
    });

    test('excess when received > billed (extra stock)', () {
      final line = GinBillLine(
        id: 'l3',
        itemName: 'Cement',
        orderedQty: 200,
        billedQty: 200,
        receivedQty: 215,
      );
      expect(line.status, GinReconciliationStatus.excess);
      expect(line.diffBilledReceived, -15);
      expect(line.suggestedAction, GinLineAction.extra);
    });

    test('received qty editable and status recomputes', () {
      final line = GinBillLine(
        id: 'l4',
        itemName: 'Sand',
        orderedQty: 10,
        billedQty: 10,
        receivedQty: 10,
      );
      expect(line.status, GinReconciliationStatus.matched);
      line.receivedQty = 8;
      expect(line.status, GinReconciliationStatus.shortage);
      line.receivedQty = 12;
      expect(line.status, GinReconciliationStatus.excess);
    });
  });

  group('GinBill parsing and computed counts', () {
    test('fromJson with embedded items and documents', () {
      final bill = GinBill.fromJson({
        'id': 'b1',
        'gin_no': 'GIN-20260805-ABCDE',
        'bill_number': 'BILL-1',
        'supplier_id': 'SUP-REAL-001',
        'supplier_name': 'Vijay Concrete Mixers',
        'thavvu_point_id': 'TP-VJA-001',
        'thavvu_point_name': 'East Ramp Loading Point',
        'site_id': 'SITE-VJA-001',
        'status': 'pending',
        'hod_status': 'pending',
        'created_at': '2026-08-05T03:00:00Z',
        'gin_bill_items': [
          {
            'id': 'i1',
            'item_name': 'Cement OPC 53 Grade',
            'ordered_qty': 200,
            'billed_qty': 200,
            'received_qty': 215,
            'uom': 'BAG',
            'action': 'extra',
            'action_note': 'Received extra bags',
          },
          {
            'id': 'i2',
            'item_name': 'River Sand',
            'ordered_qty': 10,
            'billed_qty': 10,
            'received_qty': 8,
            'uom': 'CUM',
            'action': 'reorder',
            'action_note': null,
          },
          {
            'id': 'i3',
            'item_name': 'Binding Wire',
            'ordered_qty': 50,
            'billed_qty': 50,
            'received_qty': 50,
            'uom': 'KG',
            'action': 'done',
            'action_note': null,
          },
        ],
        'gin_bill_documents': [
          {
            'id': 'd1',
            'name': 'invoice.png',
            'type': 'invoice',
            'storage_path': 'user/gin/x/invoice.png',
            'created_at': '2026-08-05T03:01:00Z',
          },
        ],
      });

      expect(bill.isDraft, isFalse);
      expect(bill.ginNo, 'GIN-20260805-ABCDE');
      expect(bill.thavvuPointName, 'East Ramp Loading Point');
      expect(bill.lines.length, 3);
      expect(bill.documents.length, 1);
      expect(bill.documents.first.type, 'invoice');
      expect(bill.lines[0].action, GinLineAction.extra);
      expect(bill.lines[1].action, GinLineAction.reorder);
      expect(bill.lines[2].action, GinLineAction.done);
      expect(bill.excessCount, 1);
      expect(bill.shortageCount, 1);
      expect(bill.matchedCount, 1);
      expect(bill.allMatched, isFalse);
      expect(bill.totalBilled, 260);
      expect(bill.totalReceived, 273);
    });

    test('draft flag and status helpers', () {
      final draft = GinBill.draft(
        ginNo: 'GIN-DRAFT-1',
        billNumber: 'BILL-D',
        supplierName: 'Supplier',
        thavvuPointId: 'TP-VJA-001',
        thavvuPointName: 'Point',
        lines: [],
      );
      expect(draft.isDraft, isTrue);
      expect(draft.isPending, isTrue);
      expect(draft.isApproved, isFalse);
      expect(draft.addedToStock, isFalse);

      final approved = GinBill.fromJson({
        'id': 'b2',
        'gin_no': 'GIN-1',
        'bill_number': 'B',
        'supplier_name': 'S',
        'thavvu_point_id': 'TP-1',
        'thavvu_point_name': 'P',
        'status': 'added_to_stock',
        'hod_status': 'approved',
        'gin_bill_items': [],
      });
      expect(approved.addedToStock, isTrue);
      expect(approved.isApproved, isTrue);
      expect(approved.isPending, isFalse);
    });
  });
}
