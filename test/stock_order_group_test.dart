import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/services/stock_inventory_repository.dart';

StockOrder _order({
  required String id,
  required String orderNo,
  String item = 'Cement',
  double qty = 10,
  String status = 'placed',
}) {
  return StockOrder(
    id: id,
    orderNo: orderNo,
    stockPointId: 'TP-VJA-001',
    stockPointName: 'East Ramp Loading Point',
    thavvuPointId: 'TP-VJA-001',
    itemId: '00000000-0000-0000-0000-000000000001',
    itemName: item,
    batch: 'B-1',
    quantity: qty,
    unit: 'BAG',
    status: status,
    placedBy: 'hod@thavvu.com',
    createdAt: DateTime(2026, 8, 5, 10),
  );
}

void main() {
  group('StockOrderGroup.groupOrders', () {
    test('groups multi-item orders by order_no and sums quantities', () {
      final orders = [
        _order(id: '1', orderNo: 'ORD-1', item: 'Cement', qty: 200),
        _order(id: '2', orderNo: 'ORD-1', item: 'Sand', qty: 10),
        _order(id: '3', orderNo: 'ORD-2', item: 'Steel', qty: 500),
      ];
      final groups = StockOrderGroup.groupOrders(orders);
      expect(groups.length, 2);
      final g1 = groups.firstWhere((g) => g.orderNo == 'ORD-1');
      expect(g1.itemCount, 2);
      expect(g1.totalQuantity, 210);
      expect(g1.canReceive, isTrue);
    });

    test('status derived: placed when any line placed', () {
      final groups = StockOrderGroup.groupOrders([
        _order(id: '1', orderNo: 'ORD-A', status: 'received'),
        _order(id: '2', orderNo: 'ORD-A', status: 'placed'),
      ]);
      expect(groups.first.status, 'placed');
      expect(groups.first.canReceive, isTrue);
    });

    test('status derived: received when all lines received', () {
      final groups = StockOrderGroup.groupOrders([
        _order(id: '1', orderNo: 'ORD-B', status: 'received'),
        _order(id: '2', orderNo: 'ORD-B', status: 'received'),
      ]);
      expect(groups.first.status, 'received');
      expect(groups.first.canReceive, isFalse);
    });

    test('status derived: added_to_stock when all lines added', () {
      final groups = StockOrderGroup.groupOrders([
        _order(id: '1', orderNo: 'ORD-C', status: 'added_to_stock'),
        _order(id: '2', orderNo: 'ORD-C', status: 'added_to_stock'),
      ]);
      expect(groups.first.status, 'added_to_stock');
    });

    test('sorts newest first', () {
      final old = _order(id: '1', orderNo: 'OLD')
          .copyWithCreatedAt(DateTime(2026, 8, 1));
      final fresh = _order(id: '2', orderNo: 'NEW')
          .copyWithCreatedAt(DateTime(2026, 8, 5));
      final groups = StockOrderGroup.groupOrders([old, fresh]);
      expect(groups.first.orderNo, 'NEW');
    });
  });
}

extension on StockOrder {
  StockOrder copyWithCreatedAt(DateTime createdAt) => StockOrder(
        id: id,
        orderNo: orderNo,
        siteId: siteId,
        stockPointId: stockPointId,
        stockPointName: stockPointName,
        thavvuPointId: thavvuPointId,
        itemId: itemId,
        itemName: itemName,
        batch: batch,
        quantity: quantity,
        unit: unit,
        status: status,
        notes: notes,
        placedBy: placedBy,
        createdAt: createdAt,
      );
}
