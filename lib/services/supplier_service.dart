import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/supplier_model.dart';

class SupplierService {
  static const _storageKey = 'thavvu_suppliers_v1';

  Future<List<Supplier>> suppliers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => Supplier.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<Supplier>> usableSuppliersForSupervisor({
    String? supervisorId,
    String? siteId,
  }) async {
    final all = await suppliers();
    return all.where((supplier) {
      final supervisorMatches = supervisorId == null ||
          supplier.supervisorId.isEmpty ||
          supplier.supervisorId == supervisorId;
      final siteMatches = siteId == null ||
          supplier.siteId.isEmpty ||
          supplier.siteId == siteId;
      return supplier.isUsableBySupervisor && supervisorMatches && siteMatches;
    }).toList();
  }

  Future<Supplier> saveSupplier(Supplier supplier) async {
    final existing = List<Supplier>.of(await suppliers());
    final now = DateTime.now();
    final normalized = supplier.copyWith(updatedAt: now);
    final index = existing.indexWhere((item) => item.id == supplier.id);

    if (index >= 0) {
      existing[index] = normalized;
    } else {
      existing.insert(0, normalized);
    }

    await _saveAll(existing);
    return normalized;
  }

  Future<void> deleteSupplier(String supplierId) async {
    final existing = List<Supplier>.of(await suppliers());
    existing.removeWhere((supplier) => supplier.id == supplierId);
    await _saveAll(existing);
  }

  Future<void> _saveAll(List<Supplier> suppliers) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(suppliers.map((supplier) => supplier.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  static String newSupplierId() {
    final now = DateTime.now();
    return 'SUP-${now.microsecondsSinceEpoch}';
  }

  static Future<void> resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
