import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production repository for the Cash module (cash_allocations +
/// cash_transactions). Site-scoped reads, realtime, and HOD status updates.
class CashRepository {
  CashRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const allocationsTable = 'cash_allocations';
  static const transactionsTable = 'cash_transactions';
  static const financeRequestsTable = 'cash_finance_requests';

  // ═══════════════════════════════════════════════════════════════════
  // ALLOCATIONS (HOD → supervisor)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<CashAllocation>> fetchAllocations({required String siteId}) async {
    final response = await _client
        .from(allocationsTable)
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => CashAllocation.fromJson(_asMap(row)))
        .toList();
  }

  Future<CashAllocation> createAllocation({
    required String siteId,
    required String allocatedBy,
    required String? allocatedTo,
    required double amount,
    required double balanceAfter,
    String? note,
    String? thavvuPointId,
  }) async {
    final response = await _client
        .from(allocationsTable)
        .insert({
          'site_id': siteId,
          'thavvu_point_id': thavvuPointId,
          'allocated_by': allocatedBy,
          'allocated_to': allocatedTo,
          'amount': amount,
          'balance_after': balanceAfter,
          'note': note,
          'is_demo': false,
        })
        .select()
        .single();
    return CashAllocation.fromJson(_asMap(response));
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRANSACTIONS (ledger)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<CashTransactionRecord>> fetchTransactions({
    required String siteId,
    String? status,
  }) async {
    var query = _client
        .from(transactionsTable)
        .select()
        .eq('site_id', siteId);
    if (status != null) {
      query = query.eq('status', status);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List)
        .map((row) => CashTransactionRecord.fromJson(_asMap(row)))
        .toList();
  }

  Future<CashTransactionRecord> createTransaction({
    required String siteId,
    required String txnNo,
    required String type,
    required double amount,
    required String method,
    String? category,
    String? note,
    String? proofPath,
    String? thavvuPointId,
  }) async {
    final response = await _client
        .from(transactionsTable)
        .insert({
          'txn_no': txnNo,
          'site_id': siteId,
          'thavvu_point_id': thavvuPointId,
          'type': type,
          'amount': amount,
          'method': method,
          'category': category,
          'note': note,
          'proof_path': proofPath,
          'status': 'submitted',
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    return CashTransactionRecord.fromJson(_asMap(response));
  }

  Future<bool> updateTransactionStatus({
    required String transactionId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(transactionsTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
      }).eq('id', transactionId);
      return true;
    } catch (e) {
      debugPrint('Error updating cash transaction: $e');
      return false;
    }
  }

  /// Total approved cash available for the site (allocations - spent).
  Future<double> availableBalance(String siteId) async {
    try {
      final allocations =
          await _client.from(allocationsTable).select('amount').eq('site_id', siteId);
      final spent = await _client
          .from(transactionsTable)
          .select('amount')
          .eq('site_id', siteId)
          .inFilter('status', ['approved', 'paid']);
      final totalIn = (allocations as List).fold<double>(
          0, (sum, row) => sum + _toDouble(row['amount']));
      final totalOut = (spent as List).fold<double>(
          0, (sum, row) => sum + _toDouble(row['amount']));
      return (totalIn - totalOut).clamp(0, double.infinity);
    } catch (_) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FINANCE REQUESTS (supervisor -> HOD review)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<CashFinanceRequestRecord>> fetchFinanceRequests({
    required String siteId,
  }) async {
    final response = await _client
        .from(financeRequestsTable)
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => CashFinanceRequestRecord.fromJson(_asMap(row)))
        .toList();
  }

  Future<CashFinanceRequestRecord> createFinanceRequest({
    required String siteId,
    required String requestNo,
    String? thavvuPointId,
    required String type,
    required double amount,
    String? category,
    String? reason,
    required String paymentMethod,
    List<Map<String, dynamic>> items = const [],
    String? proofPath,
    String? voicePath,
  }) async {
    final response = await _client
        .from(financeRequestsTable)
        .insert({
          'request_no': requestNo,
          'site_id': siteId,
          'thavvu_point_id': thavvuPointId,
          'type': type,
          'amount': amount,
          'category': category,
          'reason': reason,
          'payment_method': paymentMethod,
          'items': items,
          'proof_path': proofPath,
          'voice_path': voicePath,
          'status': 'pending',
          'requested_by': _client.auth.currentUser?.id ?? '',
          'is_demo': false,
        })
        .select()
        .single();
    return CashFinanceRequestRecord.fromJson(_asMap(response));
  }

  Future<bool> updateFinanceRequestStatus({
    required String requestId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(financeRequestsTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
      }).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('Error updating finance request: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // REALTIME
  // ═══════════════════════════════════════════════════════════════════

  RealtimeChannel? watchAll(String siteId, void Function() onChanged) {
    try {
      return _client
          .channel('public:cash-all:$siteId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: allocationsTable,
            callback: (_) => onChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: transactionsTable,
            callback: (_) => onChanged(),
          )
          .subscribe();
    } catch (_) {
      // Supabase not initialized / realtime unavailable — caller degrades
      // to pull-based refresh. Never throws during startup or in tests.
      return null;
    }
  }

  Future<void> stopWatching(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } catch (_) {
      // Ignore: tearing down a channel that was never attached is harmless.
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static String _string(Map<String, dynamic> json, String key,
      {String fallback = ''}) {
    final value = json[key];
    return value == null ? fallback : value.toString();
  }

  static double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CashAllocation {
  final String id;
  final String siteId;
  final String allocatedBy;
  final String? allocatedTo;
  final double amount;
  final double balanceAfter;
  final String? note;
  final bool isDemo;
  final DateTime? createdAt;

  const CashAllocation({
    required this.id,
    required this.siteId,
    required this.allocatedBy,
    this.allocatedTo,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.isDemo = false,
    this.createdAt,
  });

  factory CashAllocation.fromJson(Map<String, dynamic> json) {
    return CashAllocation(
      id: CashRepository._string(json, 'id'),
      siteId: CashRepository._string(json, 'site_id'),
      allocatedBy: CashRepository._string(json, 'allocated_by'),
      allocatedTo: json['allocated_to'] as String?,
      amount: CashRepository._double(json, 'amount'),
      balanceAfter: CashRepository._double(json, 'balance_after'),
      note: json['note'] as String?,
      isDemo: json['is_demo'] == true,
      createdAt: DateTime.tryParse(CashRepository._string(json, 'created_at')),
    );
  }
}

class CashTransactionRecord {
  final String id;
  final String txnNo;
  final String siteId;
  final String type;
  final double amount;
  final String method;
  final String? category;
  final String? note;
  final String? proofPath;
  final String status;
  final bool isDemo;
  final String? hodNote;
  final String? createdBy;
  final DateTime? createdAt;

  const CashTransactionRecord({
    required this.id,
    required this.txnNo,
    required this.siteId,
    required this.type,
    required this.amount,
    required this.method,
    this.category,
    this.note,
    this.proofPath,
    this.status = 'submitted',
    this.isDemo = false,
    this.hodNote,
    this.createdBy,
    this.createdAt,
  });

  factory CashTransactionRecord.fromJson(Map<String, dynamic> json) {
    return CashTransactionRecord(
      id: CashRepository._string(json, 'id'),
      txnNo: CashRepository._string(json, 'txn_no'),
      siteId: CashRepository._string(json, 'site_id'),
      type: CashRepository._string(json, 'type', fallback: 'expense'),
      amount: CashRepository._double(json, 'amount'),
      method: CashRepository._string(json, 'method', fallback: 'cash'),
      category: json['category'] as String?,
      note: json['note'] as String?,
      proofPath: json['proof_path'] as String?,
      status: CashRepository._string(json, 'status', fallback: 'submitted'),
      isDemo: json['is_demo'] == true,
      hodNote: json['hod_note'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(CashRepository._string(json, 'created_at')),
    );
  }
}

/// A supervisor's cash finance request awaiting HOD review.
class CashFinanceRequestRecord {
  final String id;
  final String requestNo;
  final String siteId;
  final String type;
  final double amount;
  final String? category;
  final String? reason;
  final String paymentMethod;
  final String status;
  final List<Map<String, dynamic>> items;
  final String? proofPath;
  final String? voicePath;
  final String? hodNote;
  final DateTime? createdAt;

  const CashFinanceRequestRecord({
    required this.id,
    required this.requestNo,
    required this.siteId,
    this.type = 'expense',
    required this.amount,
    this.category,
    this.reason,
    this.paymentMethod = 'upi',
    this.status = 'pending',
    this.items = const [],
    this.proofPath,
    this.voicePath,
    this.hodNote,
    this.createdAt,
  });

  factory CashFinanceRequestRecord.fromJson(Map<String, dynamic> json) {
    return CashFinanceRequestRecord(
      id: CashRepository._string(json, 'id'),
      requestNo: CashRepository._string(json, 'request_no'),
      siteId: CashRepository._string(json, 'site_id'),
      type: CashRepository._string(json, 'type', fallback: 'expense'),
      amount: CashRepository._double(json, 'amount'),
      category: json['category'] as String?,
      reason: json['reason'] as String?,
      paymentMethod:
          CashRepository._string(json, 'payment_method', fallback: 'upi'),
      status: CashRepository._string(json, 'status', fallback: 'pending'),
      items: json['items'] is List
          ? (json['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : const [],
      proofPath: json['proof_path'] as String?,
      voicePath: json['voice_path'] as String?,
      hodNote: json['hod_note'] as String?,
      createdAt: DateTime.tryParse(CashRepository._string(json, 'created_at')),
    );
  }
}
