import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/supervisor_cash_expense_model.dart';
import 'cash_sync_store.dart';

class SupervisorCashExpenseService {
  static const _storageKey = 'thavvu_supervisor_cash_expenses_v1';
  final CashSyncStore _syncStore = CashSyncStore();

  Future<List<SupervisorCashExpense>> expenses() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map(
          (item) => SupervisorCashExpense.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  Future<List<SupervisorCashExpense>> expensesForSupervisor(
    String supervisorId,
  ) async {
    final all = await expenses();
    return all
        .where((expense) => expense.supervisorId == supervisorId)
        .toList();
  }

  Future<SupervisorCashExpense> submitExpense({
    required String supervisorId,
    required String supervisorName,
    required String thavvuId,
    required String siteId,
    required String siteName,
    required String category,
    required String title,
    required double amount,
    required List<SupervisorCashExpenseItem> items,
    required String remarks,
    String invoiceBillPath = '',
    String vehiclePhotoPath = '',
  }) async {
    final existing = List<SupervisorCashExpense>.of(await expenses());
    final now = DateTime.now();
    final expense = SupervisorCashExpense(
      id: newExpenseId(supervisorId),
      supervisorId: supervisorId,
      supervisorName: supervisorName,
      thavvuId: thavvuId,
      siteId: siteId,
      siteName: siteName,
      category: category,
      title: title,
      amount: amount,
      submittedAt: now,
      items: items,
      remarks: remarks,
      invoiceBillPath: invoiceBillPath,
      vehiclePhotoPath: vehiclePhotoPath,
    );

    existing.insert(0, expense);
    await _saveAll(existing);
    return expense;
  }

  Future<void> updateStatus({
    required String expenseId,
    required SupervisorCashExpenseStatus status,
    required String hodNote,
  }) async {
    final existing = List<SupervisorCashExpense>.of(await expenses());
    final index = existing.indexWhere((expense) => expense.id == expenseId);
    if (index == -1) return;

    existing[index] = existing[index].copyWith(
      status: status,
      decidedAt: DateTime.now(),
      hodNote: hodNote,
    );
    await _saveAll(existing);
  }

  Future<void> _saveAll(List<SupervisorCashExpense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      expenses.map((expense) => expense.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
    if (_syncStore.isEnabled) {
      try {
        await _syncStore.write(_storageKey, encoded);
      } catch (_) {
        // Keep local cache usable when the optional sync server is offline.
      }
    }
  }

  Future<String?> _readRaw() async {
    final prefs = await SharedPreferences.getInstance();
    if (_syncStore.isEnabled) {
      try {
        final synced = await _syncStore.read(_storageKey);
        if (synced != null) {
          await prefs.setString(_storageKey, synced);
          return synced;
        }
      } catch (_) {
        // Fall back to per-browser cache when sync is unreachable.
      }
    }
    return prefs.getString(_storageKey);
  }

  static String newExpenseId(String supervisorId) {
    final suffix = supervisorId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return 'SUP-CASH-$suffix-${DateTime.now().microsecondsSinceEpoch}';
  }

  static Future<void> resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    try {
      await CashSyncStore().remove(_storageKey);
    } catch (_) {}
  }
}
