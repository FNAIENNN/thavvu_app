import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/machine_asset.dart';
import '../../domain/models/machine_daily_log.dart';
import '../../domain/models/machine_payment_request.dart';
import '../../domain/models/machine_supplier.dart';
import '../../domain/services/hod_machine_repository_interface.dart';

/// Supabase-backed implementation of [HodMachineRepository].
///
/// All queries are scoped by RLS policies defined in the database,
/// so no manual role/site filtering is needed in the client beyond
/// passing the correct `siteId` scoped to the authenticated user's
/// session context.
class SupabaseHodMachineRepository implements HodMachineRepository {
  SupabaseHodMachineRepository(SupabaseClient? client)
      : _providedClient = client;

  /// Lazy so widget tests and early startup never touch Supabase until
  /// the first query.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  // ── Suppliers ───────────────────────────────────────────────

  @override
  Future<List<MachineSupplier>> getSuppliers({required String siteId}) async {
    final response = await _client
        .from('machine_suppliers')
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((j) => MachineSupplier.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MachineSupplier> createSupplier({
    required String siteId,
    required String name,
    required String type,
    String? phone,
    double? rating,
    String? notes,
    required String createdBy,
  }) async {
    final response = await _client.from('machine_suppliers').insert({
      'site_id': siteId,
      'name': name,
      'type': type,
      'phone': phone,
      'rating': rating ?? 0,
      'notes': notes,
      'created_by': createdBy,
    }).select().single();

    return MachineSupplier.fromJson(response);
  }

  // ── Machine Assets ─────────────────────────────────────────

  @override
  Future<List<MachineAsset>> getMachines({required String siteId}) async {
    final response = await _client
        .from('machine_assets')
        .select()
        .eq('site_id', siteId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((j) => MachineAsset.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MachineAsset> createMachine({required MachineAsset machine}) async {
    // `machine_assets.id` is a client-supplied TEXT PK (e.g. MACHINE-001),
    // so we insert the full row including the id.
    final response = await _client
        .from('machine_assets')
        .insert(machine.toJson())
        .select()
        .single();

    return MachineAsset.fromJson(response);
  }

  // ── Daily Logs ─────────────────────────────────────────────

  @override
  Future<List<MachineDailyLog>> getDailyLogs({
    required String siteId,
    String? thavvuPointId,
    String? supervisorId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _client
        .from('machine_daily_logs')
        .select('''*,
          diesel_lines:machine_daily_diesel_lines(*)
        ''')
        .eq('site_id', siteId);

    if (thavvuPointId != null && thavvuPointId.isNotEmpty) {
      query = query.eq('thavvu_point_id', thavvuPointId);
    }
    // `supervisor_id` is a UUID column. A human-readable placeholder like
    // "SUP-VJA-001" is NOT a valid UUID and would make PostgREST return a
    // 400 (could not cast to uuid). Only filter when the value is a real UUID;
    // otherwise treat it as "all supervisors".
    if (supervisorId != null &&
        supervisorId.isNotEmpty &&
        _isValidUuid(supervisorId)) {
      query = query.eq('supervisor_id', supervisorId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }
    if (fromDate != null) {
      query = query.gte('log_date', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('log_date', toDate.toIso8601String());
    }

    final response = await query.order('log_date', ascending: false);

    return (response as List)
        .map((j) => MachineDailyLog.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MachineDailyLog> submitDailyLog(MachineDailyLog log) async {
    final logJson = log.toJson();
    logJson.remove('diesel_lines');
    logJson['status'] = 'submitted';
    logJson['submitted_at'] = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('machine_daily_logs')
        .insert(logJson)
        .select()
        .single();

    final savedLog =
        MachineDailyLog.fromJson(response);

    // Insert diesel lines if present
    if (log.dieselLines.isNotEmpty) {
      final dieselData = log.dieselLines.map((dl) {
        final d = dl.toJson();
        d['daily_log_id'] = savedLog.id;
        return d;
      }).toList();
      await _client.from('machine_daily_diesel_lines').insert(dieselData);
    }

    return savedLog;
  }

  @override
  Future<MachineDailyLog> reviewDailyLog({
    required String logId,
    required String hodId,
    required String status,
    String? hodNote,
  }) async {
    final hodUuid = _uuidOrNull(hodId);
    final response = await _client
        .from('machine_daily_logs')
        .update({
          'status': status,
          if (hodUuid != null) 'hod_id': hodUuid,
          'hod_note': hodNote,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', logId)
        .select(''',*,
          diesel_lines:machine_daily_diesel_lines(*)
        ''')
        .single();

    return MachineDailyLog.fromJson(response);
  }

  // ── Payment / Finance ──────────────────────────────────────

  @override
  Future<List<MachinePaymentRequest>> getPaymentRequests({
    required String siteId,
    String? status,
  }) async {
    var query = _client
        .from('machine_payment_requests')
        .select()
        .eq('site_id', siteId);

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .map(
            (j) => MachinePaymentRequest.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MachinePaymentRequest> createPaymentRequest(
      MachinePaymentRequest request) async {
    final response = await _client
        .from('machine_payment_requests')
        .insert(request.toJson())
        .select()
        .single();

    return MachinePaymentRequest.fromJson(response);
  }

  @override
  Future<MachinePaymentRequest> approvePaymentByHod({
    required String paymentId,
    required String hodId,
  }) async {
    final hodUuid = _uuidOrNull(hodId);
    final response = await _client
        .from('machine_payment_requests')
        .update({
          'status': 'hod_approved',
          'hod_approved_at': DateTime.now().toUtc().toIso8601String(),
          if (hodUuid != null) 'hod_approved_by': hodUuid,
        })
        .eq('id', paymentId)
        .select()
        .single();

    await _audit(
      action: 'payment_approved_by_hod',
      entityType: 'payment_request',
      entityId: paymentId,
      actorId: hodId,
      siteId: response['site_id'] as String,
      details: {'payment_id': paymentId, 'approved_by': hodId},
    );

    return MachinePaymentRequest.fromJson(response);
  }

  @override
  Future<MachinePaymentRequest> submitApprovedPaymentToFinance({
    required String paymentId,
  }) async {
    final payment = await _client
        .from('machine_payment_requests')
        .select('*, machine_finance_requests(*)')
        .eq('id', paymentId)
        .single();

    final paymentMap = payment;

    // Create finance request
    await _client.from('machine_finance_requests').insert({
      'payment_request_id': paymentId,
      'site_id': paymentMap['site_id'],
      'hod_id': paymentMap['hod_approved_by'] ?? paymentMap['created_by'],
      'title': 'Finance for ${paymentMap['kind']} payment',
      'amount': paymentMap['amount'],
      'payment_mode': paymentMap['payment_mode'],
      'account_label': paymentMap['account_label'],
    });

    final updated = await _client
        .from('machine_payment_requests')
        .update({
          'status': 'submitted_to_finance',
          'submitted_to_finance_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', paymentId)
        .select()
        .single();

    return MachinePaymentRequest.fromJson(updated);
  }

  @override
  Future<MachinePaymentRequest> completeFinancePayment({
    required String paymentId,
    required String proofPath,
    required bool registerInIdsBook,
  }) async {
    final response = await _client
        .from('machine_payment_requests')
        .update({
          'status': 'paid',
          'paid_at': DateTime.now().toUtc().toIso8601String(),
          'payment_proof_path': proofPath,
          'registered_in_ids_book': registerInIdsBook,
        })
        .eq('id', paymentId)
        .select()
        .single();

    // Update the linked finance request
    await _client
        .from('machine_finance_requests')
        .update({
          'status': 'paid',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('payment_request_id', paymentId);

    return MachinePaymentRequest.fromJson(response);
  }

  // ── Audit helper ───────────────────────────────────────────

  Future<void> _audit({
    required String action,
    required String entityType,
    required String entityId,
    required String actorId,
    required String siteId,
    Map<String, dynamic>? details,
  }) async {
    final actorUuid = _uuidOrNull(actorId);
    if (actorUuid == null) return; // no real auth uid — skip audit
    try {
      await _client.from('machine_audit_logs').insert({
        'site_id': siteId,
        'actor_id': actorUuid,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details,
      });
    } catch (_) {
      // Audit failures must never block the primary workflow.
    }
  }

  /// Returns [value] when it is a valid UUID, otherwise null.
  ///
  /// Postgres `uuid` columns reject any non-UUID value with HTTP 400. While
  /// Supabase auth wiring is incremental, the UI still passes human-readable
  /// placeholder ids such as "HOD-001" or "SUP-VJA-001". Guarding writes with
  /// this helper avoids spurious 400s; nullable uuid columns simply stay null.
  String? _uuidOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return pattern.hasMatch(value) ? value : null;
  }

  /// Returns true if [value] is a 36-character UUID.
  bool _isValidUuid(String value) => _uuidOrNull(value) != null;
}
