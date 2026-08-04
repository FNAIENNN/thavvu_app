import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thavvu_app/models/supervisor_cash_expense_model.dart';
import 'package:thavvu_app/screens/cash_screen.dart';
import 'package:thavvu_app/services/auth_service.dart';
import 'package:thavvu_app/services/cash_allocation_service.dart';
import 'package:thavvu_app/services/supervisor_cash_expense_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('HOD can issue cash to multiple supervisors', () async {
    final service = CashAllocationService();

    final created = await service.issueCash(
      supervisorIds: const ['THV-SUP-001', 'THV-SUP-002'],
      supervisorNameFor: (id) =>
          id == 'THV-SUP-001' ? 'Rajesh Kumar' : 'Kumar Reddy',
      siteId: 'MULTI',
      siteName: 'Multiple Sites',
      amountPerSupervisor: 15000,
      purpose: 'Weekly site expenses',
      category: 'General',
      paymentMode: 'Cash',
      reference: 'BOX-01',
      notes: 'Issued from HOD desk',
      issuedByHodId: 'HOD-001',
    );

    expect(created, hasLength(2));
    expect(created.fold<double>(0, (sum, item) => sum + item.amount), 30000);

    final rajeshAllocations =
        await service.allocationsForSupervisor('THV-SUP-001');
    expect(rajeshAllocations, hasLength(1));
    expect(rajeshAllocations.single.purpose, 'Weekly site expenses');
  });

  testWidgets('supervisor cash module starts at zero without HOD allocation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CashModuleScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cash Summary'), findsOneWidget);
    expect(find.text('₹250000'), findsNothing);
    expect(find.text('₹0'), findsWidgets);
  });

  testWidgets('supervisor cash module shows HOD-issued cash', (tester) async {
    final service = CashAllocationService();
    await service.issueCash(
      supervisorIds: const ['THV-SUP-001'],
      supervisorNameFor: (_) => 'Rajesh Kumar',
      siteId: 'THV-SITE-CHN-001',
      siteName: 'Site A - Chennai North',
      amountPerSupervisor: 42000,
      purpose: 'Pond work cash box',
      category: 'Fuel',
      paymentMode: 'Cash',
      reference: 'HOD-CB-77',
      notes: '',
      issuedByHodId: 'HOD-001',
    );

    await tester.pumpWidget(const MaterialApp(home: CashModuleScreen()));
    await tester.pumpAndSettle();

    expect(find.text('₹42000'), findsWidgets);
    expect(find.text('Cash Summary'), findsOneWidget);
  });

  test('HOD allocation and supervisor cash pay share one ledger', () async {
    final allocationService = CashAllocationService();
    final expenseService = SupervisorCashExpenseService();

    await allocationService.issueCash(
      supervisorIds: const ['THV-SUP-001'],
      supervisorNameFor: (_) => 'Rajesh Kumar',
      siteId: 'THV-SITE-CHN-001',
      siteName: 'Site A - Chennai North',
      amountPerSupervisor: 5000,
      purpose: 'Daily site cash',
      category: 'General',
      paymentMode: 'Cash',
      reference: 'HOD-CASH-TEST',
      notes: '',
      issuedByHodId: 'HOD-001',
    );

    final expense = await expenseService.submitExpense(
      supervisorId: 'THV-SUP-001',
      supervisorName: 'Rajesh Kumar',
      thavvuId: 'THV-SUP-001',
      siteId: 'THV-SITE-CHN-001',
      siteName: 'Site A - Chennai North',
      category: 'food',
      title: 'Food',
      amount: 1800,
      items: const [
        SupervisorCashExpenseItem(
          name: 'Lunch meals',
          quantity: 20,
          amount: 90,
          category: 'food',
        ),
      ],
      remarks: 'Food: Lunch meals x20 - Workers lunch',
    );

    final allocations =
        await allocationService.allocationsForSupervisor('THV-SUP-001');
    final expenses = await expenseService.expensesForSupervisor('THV-SUP-001');

    final allocated = allocations.fold<double>(
      0,
      (sum, allocation) => sum + allocation.amount,
    );
    final spent = expenses
        .where((item) => item.affectsSupervisorBalance)
        .fold<double>(0, (sum, item) => sum + item.amount);

    expect(expenses.single.id, expense.id);
    expect(allocated - spent, 3200);

    await expenseService.updateStatus(
      expenseId: expense.id,
      status: SupervisorCashExpenseStatus.approved,
      hodNote: 'Approved by HOD',
    );

    final reviewed = await expenseService.expensesForSupervisor('THV-SUP-001');
    expect(reviewed.single.status, SupervisorCashExpenseStatus.approved);
    expect(reviewed.single.hodNote, 'Approved by HOD');
  });

  test('logout preserves HOD cash allocations for supervisor login', () async {
    final service = CashAllocationService();

    await AuthService.login(
      'hod@thavvu.com',
      'HOD',
      name: 'HOD Admin',
      empId: 'HOD-001',
    );
    await service.issueCash(
      supervisorIds: const ['THV-SUP-001'],
      supervisorNameFor: (_) => 'Rajesh Kumar',
      siteId: 'THV-SITE-CHN-001',
      siteName: 'Site A - Chennai North',
      amountPerSupervisor: 25000,
      purpose: 'Switch-role cash check',
      category: 'General',
      paymentMode: 'Cash',
      reference: '',
      notes: '',
      issuedByHodId: 'HOD-001',
    );

    await AuthService.logout();
    await AuthService.login(
      'supervisor@thavvu.com',
      'Supervisor',
      name: 'Rajesh Kumar',
      empId: 'EMP-001',
    );

    final allocations = await service.allocationsForSupervisor('THV-SUP-001');
    expect(allocations.single.amount, 25000);
  });
}
