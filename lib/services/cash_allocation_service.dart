import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cash_allocation_model.dart';
import 'cash_sync_store.dart';

class CashAllocationService {
  static const _storageKey = 'thavvu_hod_cash_allocations_v1';
  final CashSyncStore _syncStore = CashSyncStore();

  Future<List<CashAllocation>> allocations() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => CashAllocation.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  Future<List<CashAllocation>> allocationsForSupervisor(
    String supervisorId,
  ) async {
    final all = await allocations();
    return all
        .where((allocation) =>
            allocation.supervisorId == supervisorId && allocation.isActive)
        .toList();
  }

  Future<List<CashAllocation>> issueCash({
    required List<String> supervisorIds,
    required String Function(String supervisorId) supervisorNameFor,
    required String siteId,
    required String siteName,
    String Function(String supervisorId)? siteIdFor,
    String Function(String supervisorId)? siteNameFor,
    required double amountPerSupervisor,
    required String purpose,
    required String category,
    required String paymentMode,
    required String reference,
    required String notes,
    required String issuedByHodId,
  }) async {
    final existing = List<CashAllocation>.of(await allocations());
    final now = DateTime.now();
    final created = supervisorIds.map((supervisorId) {
      return CashAllocation(
        id: newAllocationId(supervisorId),
        supervisorId: supervisorId,
        supervisorName: supervisorNameFor(supervisorId),
        siteId: siteIdFor?.call(supervisorId) ?? siteId,
        siteName: siteNameFor?.call(supervisorId) ?? siteName,
        amount: amountPerSupervisor,
        purpose: purpose,
        category: category,
        paymentMode: paymentMode,
        reference: reference,
        notes: notes,
        issuedByHodId: issuedByHodId,
        issuedAt: now,
      );
    }).toList();

    existing.insertAll(0, created);
    await _saveAll(existing);
    return created;
  }

  Future<void> voidAllocation(String allocationId, String reason) async {
    final existing = List<CashAllocation>.of(await allocations());
    final index = existing.indexWhere((item) => item.id == allocationId);
    if (index == -1) return;

    existing[index] = existing[index].copyWith(
      status: CashAllocationStatus.voided,
      voidedAt: DateTime.now(),
      voidReason: reason,
    );
    await _saveAll(existing);
  }

  Future<void> _saveAll(List<CashAllocation> allocations) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      allocations.map((allocation) => allocation.toJson()).toList(),
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

  static String newAllocationId(String supervisorId) {
    final now = DateTime.now();
    final suffix = supervisorId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return 'HOD-CASH-$suffix-${now.microsecondsSinceEpoch}';
  }

  static Future<void> resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    try {
      await CashSyncStore().remove(_storageKey);
    } catch (_) {}
  }
}
