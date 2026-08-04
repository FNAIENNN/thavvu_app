import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thavvu_app/models/supplier_model.dart';
import 'package:thavvu_app/screens/hod/modules/hod_suppliers_screen.dart';
import 'package:thavvu_app/services/supplier_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('HOD-created supplier is available to supervisor', () async {
    final service = SupplierService();
    final now = DateTime.now();

    await service.saveSupplier(
      Supplier(
        id: 'SUP-TEST-001',
        name: 'Sri Lakshmi Aggregates',
        contactPerson: 'Kiran',
        phone: '9876543210',
        email: 'kiran@example.com',
        address: 'Chennai',
        category: 'Materials',
        usagePurpose: 'M-sand for foundation work',
        siteName: 'Site A',
        siteId: 'THV-SITE-CHN-001',
        thavvuPointId: 'TP-001',
        supervisorId: 'THV-SUP-001',
        type: SupplierType.temporary,
        validFrom: now,
        validUntil: now.add(const Duration(days: 7)),
        notes: 'Use only for approved site work.',
        createdByHodId: 'HOD-001',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final supervisorSuppliers = await service.usableSuppliersForSupervisor(
      supervisorId: 'THV-SUP-001',
      siteId: 'THV-SITE-CHN-001',
    );

    expect(supervisorSuppliers, hasLength(1));
    expect(supervisorSuppliers.single.name, 'Sri Lakshmi Aggregates');
    expect(supervisorSuppliers.single.isTemporary, isTrue);
  });

  testWidgets('HOD supplier module opens successfully', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HodSuppliersScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(HodSuppliersScreen), findsOneWidget);
  });

  testWidgets('machine supplier selector shows HOD-created supplier',
      (tester) async {
    final service = SupplierService();
    final now = DateTime.now();

    await service.saveSupplier(
      Supplier(
        id: 'SUP-TEST-002',
        name: 'Metro Diesel Supply',
        contactPerson: 'Arun',
        phone: '9000011111',
        email: '',
        address: 'Chennai North',
        category: 'Diesel',
        usagePurpose: 'Diesel refill for borewell equipment',
        siteName: 'Site A',
        siteId: 'THV-SITE-CHN-001',
        thavvuPointId: '',
        supervisorId: 'THV-SUP-001',
        type: SupplierType.permanent,
        validFrom: now,
        validUntil: null,
        notes: '',
        createdByHodId: 'HOD-001',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final suppliers = await service.usableSuppliersForSupervisor(
      supervisorId: 'THV-SUP-001',
      siteId: 'THV-SITE-CHN-001',
    );

    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, 'Metro Diesel Supply');
  });
}
