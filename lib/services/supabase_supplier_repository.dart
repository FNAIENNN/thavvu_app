import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supplier_model.dart';

/// Enterprise supplier catalog: HOD-created suppliers are stored in
/// Supabase (`suppliers` table) so they flow to every supervisor instantly
/// (replaces the old device-local-only storage). Demo rows (is_demo=true)
/// are visible to demo logins; real rows (is_demo=false) are the live
/// catalog for real logins.
class SupabaseSupplierRepository {
  SupabaseSupplierRepository({SupabaseClient? client})
      : _providedClient = client;

  /// Lazy so widget tests never touch Supabase until the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const table = 'suppliers';

  /// Suppliers for a site, newest first. Demo logins also see the seeded
  /// demo rows; everyone sees the real catalog.
  ///
  /// Bridges BOTH supplier tables so the supervisor's dropdown shows the
  /// enterprise catalog (`suppliers`) AND every machine supplier the HOD
  /// created from the machine-entry sheet (`machine_suppliers`), deduped
  /// by name.
  Future<List<Supplier>> fetchForSupervisor({String? siteId}) async {
    try {
      var query = _client.from(table).select().eq('active', true);
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final rows = await query.order('updated_at', ascending: false);
      final byName = <String, Supplier>{};
      for (final row in rows as List) {
        final s = _fromRow(Map<String, dynamic>.from(row as Map));
        if (s.name.isEmpty) continue;
        byName[s.name.trim().toLowerCase()] = s;
      }
      // Machine suppliers created from the HOD machine-entry sheet.
      if (siteId != null && siteId.isNotEmpty) {
        try {
          final machineRows = await _client
              .from('machine_suppliers')
              .select()
              .eq('site_id', siteId)
              .order('created_at', ascending: false);
          for (final row in machineRows as List) {
            final s =
                _fromMachineSupplierRow(Map<String, dynamic>.from(row as Map));
            if (s.name.isEmpty) continue;
            byName.putIfAbsent(s.name.trim().toLowerCase(), () => s);
          }
        } catch (e) {
          debugPrint('fetchForSupervisor: machine_suppliers bridge failed: $e');
        }
      }
      return byName.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('fetchForSupervisor failed: $e');
      return const [];
    }
  }

  /// All suppliers including soft-deleted (active=false) — for management.
  /// Bridges `machine_suppliers` rows the same way [fetchForSupervisor] does.
  Future<List<Supplier>> fetchAll({String? siteId}) async {
    try {
      var query = _client.from(table).select();
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final rows = await query.order('updated_at', ascending: false);
      final byName = <String, Supplier>{};
      for (final row in rows as List) {
        final s = _fromRow(Map<String, dynamic>.from(row as Map));
        if (s.name.isEmpty) continue;
        byName[s.name.trim().toLowerCase()] = s;
      }
      if (siteId != null && siteId.isNotEmpty) {
        try {
          final machineRows = await _client
              .from('machine_suppliers')
              .select()
              .eq('site_id', siteId)
              .order('created_at', ascending: false);
          for (final row in machineRows as List) {
            final s =
                _fromMachineSupplierRow(Map<String, dynamic>.from(row as Map));
            if (s.name.isEmpty) continue;
            byName.putIfAbsent(s.name.trim().toLowerCase(), () => s);
          }
        } catch (e) {
          debugPrint('fetchAll: machine_suppliers bridge failed: $e');
        }
      }
      return byName.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('fetchAll suppliers failed: $e');
      return const [];
    }
  }

  /// Adds a brand-new supplier (permanent, active by default).
  ///
  /// Throws on failure (RLS, network, validation) so the caller can surface
  /// the REAL error instead of a generic "failed" message.
  Future<bool> addSupplier({
    required String name,
    String? contactPerson,
    String? phone,
    String? address,
    String? siteId,
    String? thavvuPointId,
    String? paymentUpi,
    String? notes,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    await _client.from(table).insert({
      'id': 'SUP-${DateTime.now().millisecondsSinceEpoch}',
      'group_name': 'General',
      'name': trimmed,
      'contact_person': contactPerson,
      'phone': phone,
      'address': address,
      'site_id': siteId,
      'thavvu_point_id': thavvuPointId,
      'payment_upi': paymentUpi,
      'notes': notes,
      'active': true,
      'is_demo': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return true;
  }

  /// Soft-delete / restore a supplier (active=false hides it from the GIN
  /// composer and every list; history is preserved).
  Future<bool> setSupplierActive(String id, bool active) async {
    try {
      await _client.from(table).update({
        'active': active,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('setSupplierActive failed: $e');
      return false;
    }
  }

  /// Upsert one supplier row (used by the HOD screen after a save).
  Future<bool> upsertRaw(Map<String, dynamic> row) async {
    try {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) return false;
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(table).upsert({
        ...row,
        'updated_at': now,
      });
      return true;
    } catch (e) {
      debugPrint('upsertRaw failed: $e');
      return false;
    }
  }

  Future<bool> deleteRaw(String id) async {
    try {
      await _client.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteRaw failed: $e');
      return false;
    }
  }

  /// Upserts one machine-supplier row (`machine_suppliers` table) from the
  /// HOD Supplier module so a machine-group supplier is instantly visible in
  /// the machine entry dropdowns (HOD + supervisor).
  ///
  /// `machine_suppliers.id` is a TEXT PK with no DB default — a client id is
  /// generated when the row does not carry one. `created_by` is a nullable
  /// UUID FK (00054); human-readable ids are dropped so Postgres never
  /// raises 22P02.
  Future<bool> upsertMachineSupplierRow(Map<String, dynamic> row) async {
    try {
      final id = row['id']?.toString() ?? '';
      final name = row['name']?.toString() ?? '';
      if (name.trim().isEmpty) return false;
      final createdAt = row['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String();
      final now = DateTime.now().toUtc().toIso8601String();
      final clean = Map<String, dynamic>.from(row)
        ..remove('created_by_hod_id')
        ..remove('group')
        ..remove('group_name');
      final actor = clean['created_by']?.toString() ?? '';
      if (actor.isEmpty || !_isUuid(actor)) {
        clean.remove('created_by');
      }
      await _client.from('machine_suppliers').upsert({
        'id': id.isNotEmpty ? id : 'SUP-${DateTime.now().millisecondsSinceEpoch}',
        ...clean,
        'type': clean['type']?.toString() ?? 'permanent',
        'rating': (clean['rating'] as num?)?.toDouble() ?? 0,
        'is_active': clean['is_active'] as bool? ?? true,
        'created_at': createdAt,
        'updated_at': now,
      });
      return true;
    } catch (e) {
      debugPrint('upsertMachineSupplierRow failed: $e');
      return false;
    }
  }

  /// Maps a `machine_suppliers` row into the shared [Supplier] model used by
  /// supervisor dropdowns.
  Supplier _fromMachineSupplierRow(Map<String, dynamic> row) {
    final now = DateTime.now();
    final created =
        DateTime.tryParse(row['created_at']?.toString() ?? '') ?? now;
    return Supplier(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      contactPerson: '',
      phone: row['phone']?.toString() ?? '',
      email: '',
      address: '',
      category: 'Machine',
      usagePurpose: '',
      siteName: '',
      siteId: row['site_id']?.toString() ?? '',
      thavvuPointId: '',
      supervisorId: '',
      type: row['type']?.toString() == 'temporary'
          ? SupplierType.temporary
          : SupplierType.permanent,
      validFrom: created,
      validUntil: row['valid_until'] != null
          ? DateTime.tryParse(row['valid_until'].toString())
          : null,
      notes: row['notes']?.toString() ?? '',
      createdByHodId: row['created_by']?.toString() ?? 'HOD',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? created,
      active: row['is_active'] as bool? ?? true,
    );
  }

  bool _isUuid(String value) {
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return pattern.hasMatch(value);
  }

  Supplier _fromRow(Map<String, dynamic> row) {
    final now = DateTime.now();
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? now;
    final updated = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? created;
    return Supplier(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      contactPerson: row['contact_person']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      email: '',
      address: row['address']?.toString() ?? '',
      category: row['group_name']?.toString() ?? '',
      usagePurpose: '',
      siteName: row['site_name']?.toString() ?? '',
      siteId: row['site_id']?.toString() ?? '',
      thavvuPointId: row['thavvu_point_id']?.toString() ?? '',
      supervisorId: '',
      type: SupplierType.permanent,
      validFrom: created,
      validUntil: null,
      notes: row['notes']?.toString() ?? '',
      createdByHodId: row['created_by_hod_id']?.toString() ?? 'HOD',
      createdAt: created,
      updatedAt: updated,
      active: row['active'] as bool? ?? true,
      paymentUpi: row['payment_upi']?.toString() ?? '',
      paymentAccountHolder: row['payment_account_holder']?.toString() ?? '',
      paymentBank: row['payment_bank']?.toString() ?? '',
      paymentAccountNumber: row['payment_account_number']?.toString() ?? '',
      paymentIfsc: row['payment_ifsc']?.toString() ?? '',
      paymentNote: row['payment_note']?.toString() ?? '',
    );
  }
}
