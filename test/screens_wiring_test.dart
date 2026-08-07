// Smoke/integration tests verifying that StockInventoryScreen,
// InternalTransferScreen and RentalScreen are correctly wired to AppStore.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thavvu_supervisor/providers/app_store.dart';
import 'package:thavvu_supervisor/screens/internal_transfer_screen.dart';
import 'package:thavvu_supervisor/screens/rental_screen.dart';
import 'package:thavvu_supervisor/screens/stock_inventory_screen.dart';

Widget _wrap(AppStore store, Widget child) {
  return ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(home: child),
  );
}

Future<void> _useBigSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Opens a DropdownButtonFormField identified by its [hint] text and selects
/// the option with text [option].
Future<void> _selectDropdown(WidgetTester tester, String hint, String option) async {
  await tester.tap(find.text(hint));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StockInventoryScreen', () {
    testWidgets('shows seeded stock points and raises an order via the store', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());

      await tester.pumpWidget(_wrap(store, const StockInventoryScreen()));
      await tester.pumpAndSettle();

      // View Stock tab: select a stock point and confirm store data renders.
      await _selectDropdown(tester, 'Choose a stock point to view dashboard', 'Site A — North');

      expect(find.text('B-042'), findsWidgets); // batch id from seeded StockPoint
      expect(find.text('Diesel'), findsWidgets); // seeded movement item

      // Raise Order tab.
      await tester.tap(find.text('Raise Order'));
      await tester.pumpAndSettle();

      await _selectDropdown(tester, 'Select stock point', 'Site B — South');
      await _selectDropdown(tester, 'Select item to order', 'Engine Oil');

      await tester.enterText(find.widgetWithText(TextField, 'Quantity Required'), '15');
      await tester.pumpAndSettle();

      final beforeCount = store.stockOrders.length;
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Order for Approval'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Order for Approval'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(store.stockOrders.length, beforeCount + 1);
      expect(store.stockOrders.first.item, 'Engine Oil');
      expect(store.stockOrders.first.quantity, 15);
      expect(find.textContaining('submitted for HOD approval'), findsOneWidget);
    });

    testWidgets('submits a stock return via the store', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());

      await tester.pumpWidget(_wrap(store, const StockInventoryScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Original Batch ID'), 'B-042');
      await _selectDropdown(tester, 'Select item to return', 'Engine Oil');
      await tester.enterText(find.widgetWithText(TextField, 'Quantity to Return'), '3');
      await tester.pumpAndSettle();

      final beforeCount = store.stockReturns.length;
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Submit Return for Approval'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit Return for Approval'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(store.stockReturns.length, beforeCount + 1);
      expect(store.stockReturns.first.originalBatchId, 'B-042');
      expect(store.stockReturns.first.quantity, 3);
    });
  });

  group('InternalTransferScreen', () {
    testWidgets('initiates a transfer via the store and shows insufficient stock error', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());

      await tester.pumpWidget(_wrap(store, const InternalTransferScreen()));
      await tester.pumpAndSettle();

      await _selectDropdown(tester, 'From — source stock point', 'Warehouse Main');
      await _selectDropdown(tester, 'To — destination stock point', 'Field Store');
      await _selectDropdown(tester, 'Select item to transfer', 'Diesel');

      // Warehouse Main only has 18 on hand (5 used today) -> request more than remaining.
      await tester.enterText(find.widgetWithText(TextField, 'Quantity to transfer'), '9999');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Initiate Transfer'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Initiate Transfer'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.textContaining('Insufficient stock'), findsOneWidget);
    });

    testWidgets('successful transfer deducts stock and appears in history', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());

      await tester.pumpWidget(_wrap(store, const InternalTransferScreen()));
      await tester.pumpAndSettle();

      await _selectDropdown(tester, 'From — source stock point', 'Site A — North');
      await _selectDropdown(tester, 'To — destination stock point', 'Site B — South');
      await _selectDropdown(tester, 'Select item to transfer', 'Diesel');

      await tester.enterText(find.widgetWithText(TextField, 'Quantity to transfer'), '20');
      await tester.pumpAndSettle();

      final beforeTransfers = store.transfers.length;
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Initiate Transfer'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Initiate Transfer'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(store.transfers.length, beforeTransfers + 1);
      expect(store.transfers.first.status, 'pending_ack');
      expect(find.textContaining('initiated from Site A — North to Site B — South'), findsOneWidget);

      // Acknowledge receipt.
      await tester.ensureVisible(find.text('Received'));
      await tester.tap(find.text('Received'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(store.transfers.first.status, 'completed');

      // Transfer History tab reflects the live store data.
      await tester.tap(find.text('Transfer History'));
      await tester.pumpAndSettle();
      expect(find.textContaining(store.transfers.first.id), findsWidgets);
    });
  });

  group('RentalScreen', () {
    testWidgets('opens a rental via the store and shows the generated id', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());

      await tester.pumpWidget(_wrap(store, const RentalScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Item Name'), 'Bulldozer');
      await tester.enterText(find.widgetWithText(TextField, 'Rate per day (₹)'), '6000');
      await tester.pumpAndSettle();

      final beforeCount = store.rentals.length;
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Open Rental Record'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Open Rental Record'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(store.rentals.length, beforeCount + 1);
      expect(store.rentals.first.item, 'Bulldozer');
      expect(find.textContaining('opened for Bulldozer'), findsOneWidget);
    });

    testWidgets('closes an active rental and reports not-found for unknown id', (tester) async {
      await _useBigSurface(tester);
      final store = AppStore();
      await tester.runAsync(() => store.init());
      final activeId = store.activeRentals.first.id;

      await tester.pumpWidget(_wrap(store, const RentalScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close Rental'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Rental ID'), activeId);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Close Rental Record'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Close Rental Record'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(store.rentals.firstWhere((r) => r.id == activeId).status, 'closed');
      expect(find.textContaining('closed successfully'), findsOneWidget);

      // Let the first SnackBar's auto-dismiss timer fire so the next one can show.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Rental ID'), 'RNT-NOT-REAL');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Close Rental Record'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Close Rental Record'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Rental ID not found'), findsOneWidget);
    });
  });
}
