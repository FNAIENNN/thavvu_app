// lib/services/payment_repository.dart
//
// Supabase-backed persistence for the Payments and Supplier Bills tabs:
//   - supplier_bills            (bill photo uploads)
//   - supplier_payment_requests (finance requests from Supplier Bills tab)
//   - payment_accounts          (monthly salary accounts, one per worker/month)
//   - payment_ledger            (every used-amount / cash / request entry)
//
// All tables are RLS-protected (site members can select/insert/update;
// HOD/admin/finance can read everything) and added to the
// supabase_realtime publication by migration 00019.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// File-scoped helpers shared by the DTO classes and repository.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime? _toDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ===========================================================================
// DTOs
// ===========================================================================

class SupplierBillRow {
  final String? id;
  final String? siteId;
  final String supplier;
  final String? photoPath;
  final double amount;
  final DateTime billDate;
  final DateTime createdAt;

  const SupplierBillRow({
    this.id,
    this.siteId,
    required this.supplier,
    this.photoPath,
    this.amount = 0,
    required this.billDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        if (siteId != null) 'site_id': siteId,
        'supplier': supplier,
        if (photoPath != null) 'photo_path': photoPath,
        'amount': amount,
        'bill_date': _dateOnly(billDate),
      };

  factory SupplierBillRow.fromJson(Map<String, dynamic> json) {
    return SupplierBillRow(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      supplier: json['supplier'] as String? ?? '',
      photoPath: json['photo_path'] as String?,
      amount: _toDouble(json['amount']),
      billDate: _toDateTime(json['bill_date']) ?? DateTime.now(),
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now(),
    );
  }
}

class SupplierPaymentRequestRow {
  final String? id;
  final String? siteId;
  final String supplierName;
  final List<String> batchIds;
  final double amount;
  final double billAmount;
  final double usedAmount;
  final String requestType;
  final String method;
  final String status;
  final String? paymentProof;
  final DateTime requestedAt;

  const SupplierPaymentRequestRow({
    this.id,
    this.siteId,
    required this.supplierName,
    this.batchIds = const [],
    this.amount = 0,
    this.billAmount = 0,
    this.usedAmount = 0,
    this.requestType = 'Supplier Bill',
    this.method = 'UPI',
    this.status = 'Requested',
    this.paymentProof,
    required this.requestedAt,
  });

  Map<String, dynamic> toJson() => {
        if (siteId != null) 'site_id': siteId,
        'supplier_name': supplierName,
        'batch_ids': batchIds,
        'amount': amount,
        'bill_amount': billAmount,
        'used_amount': usedAmount,
        'request_type': requestType,
        'method': method,
        'status': status,
        if (paymentProof != null) 'payment_proof': paymentProof,
        'requested_at': requestedAt.toUtc().toIso8601String(),
      };

  factory SupplierPaymentRequestRow.fromJson(Map<String, dynamic> json) {
    return SupplierPaymentRequestRow(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      supplierName: json['supplier_name'] as String? ?? '',
      batchIds: (json['batch_ids'] as List? ?? []).cast<String>(),
      amount: _toDouble(json['amount']),
      billAmount: _toDouble(json['bill_amount']),
      usedAmount: _toDouble(json['used_amount']),
      requestType: json['request_type'] as String? ?? 'Supplier Bill',
      method: json['method'] as String? ?? 'UPI',
      status: json['status'] as String? ?? 'Requested',
      paymentProof: json['payment_proof'] as String?,
      requestedAt: _toDateTime(json['requested_at']) ?? DateTime.now(),
    );
  }
}

class PaymentAccountRow {
  final String? id;
  final String? siteId;
  final String? workerId;
  final String workerName;
  final String? department;
  final int daysWorked;
  final double monthlyAmount;
  final double usedAmount;
  final double paidAmount;
  final bool isPaid;
  final DateTime paymentMonth;
  final DateTime? paidAt;

  const PaymentAccountRow({
    this.id,
    this.siteId,
    this.workerId,
    required this.workerName,
    this.department,
    this.daysWorked = 0,
    this.monthlyAmount = 0,
    this.usedAmount = 0,
    this.paidAmount = 0,
    this.isPaid = false,
    required this.paymentMonth,
    this.paidAt,
  });

  Map<String, dynamic> toJson() => {
        if (siteId != null) 'site_id': siteId,
        if (workerId != null) 'worker_id': workerId,
        'worker_name': workerName,
        if (department != null) 'department': department,
        'days_worked': daysWorked,
        'monthly_amount': monthlyAmount,
        'used_amount': usedAmount,
        'paid_amount': paidAmount,
        'is_paid': isPaid,
        'payment_month': _dateOnly(paymentMonth),
        if (paidAt != null) 'paid_at': paidAt!.toUtc().toIso8601String(),
      };

  factory PaymentAccountRow.fromJson(Map<String, dynamic> json) {
    return PaymentAccountRow(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      workerId: json['worker_id'] as String?,
      workerName: json['worker_name'] as String? ?? '',
      department: json['department'] as String?,
      daysWorked: (json['days_worked'] as num?)?.toInt() ?? 0,
      monthlyAmount: _toDouble(json['monthly_amount']),
      usedAmount: _toDouble(json['used_amount']),
      paidAmount: _toDouble(json['paid_amount']),
      isPaid: json['is_paid'] as bool? ?? false,
      paymentMonth: _toDateTime(json['payment_month']) ?? DateTime.now(),
      paidAt: _toDateTime(json['paid_at']),
    );
  }
}

class PaymentLedgerRow {
  final String? id;
  final String? siteId;
  final String? accountId;
  final String? workerId;
  final String? workerName;
  final String type;
  final double amount;
  final String status;
  final String method;
  final String note;
  final String? proofId;
  final bool registeredInMachineIdsBook;
  final DateTime entryDate;

  const PaymentLedgerRow({
    this.id,
    this.siteId,
    this.accountId,
    this.workerId,
    this.workerName,
    required this.type,
    this.amount = 0,
    this.status = 'Pending',
    this.method = '',
    this.note = '',
    this.proofId,
    this.registeredInMachineIdsBook = false,
    required this.entryDate,
  });

  Map<String, dynamic> toJson() => {
        if (siteId != null) 'site_id': siteId,
        if (accountId != null) 'account_id': accountId,
        if (workerId != null) 'worker_id': workerId,
        if (workerName != null) 'worker_name': workerName,
        'type': type,
        'amount': amount,
        'status': status,
        'method': method,
        'note': note,
        if (proofId != null) 'proof_id': proofId,
        'registered_in_machine_ids_book': registeredInMachineIdsBook,
        'entry_date': entryDate.toUtc().toIso8601String(),
      };

  factory PaymentLedgerRow.fromJson(Map<String, dynamic> json) {
    return PaymentLedgerRow(
      id: json['id'] as String?,
      siteId: json['site_id'] as String?,
      accountId: json['account_id'] as String?,
      workerId: json['worker_id'] as String?,
      workerName: json['worker_name'] as String?,
      type: json['type'] as String? ?? '',
      amount: _toDouble(json['amount']),
      status: json['status'] as String? ?? 'Pending',
      method: json['method'] as String? ?? '',
      note: json['note'] as String? ?? '',
      proofId: json['proof_id'] as String?,
      registeredInMachineIdsBook:
          json['registered_in_machine_ids_book'] as bool? ?? false,
      entryDate: _toDateTime(json['entry_date']) ?? DateTime.now(),
    );
  }
}

// ===========================================================================
// Repository
// ===========================================================================

class PaymentRepository {
  PaymentRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _billsTable = 'supplier_bills';
  static const _requestsTable = 'supplier_payment_requests';
  static const _accountsTable = 'payment_accounts';
  static const _ledgerTable = 'payment_ledger';

  // ---------------------------------------------------------------
  // Supplier bills
  // ---------------------------------------------------------------

  Future<List<SupplierBillRow>> fetchBills({String? siteId}) async {
    try {
      var query = _client.from(_billsTable).select();
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((j) => SupplierBillRow.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching supplier bills: $e');
      return [];
    }
  }

  Future<SupplierBillRow?> insertBill(
      {required String siteId,
      required String supplier,
      String? photoPath,
      double amount = 0}) async {
    try {
      final response = await _client
          .from(_billsTable)
          .insert(SupplierBillRow(
            siteId: siteId,
            supplier: supplier,
            photoPath: photoPath,
            amount: amount,
            billDate: DateTime.now(),
            createdAt: DateTime.now(),
          ).toJson())
          .select()
          .single();
      return SupplierBillRow.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting supplier bill: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------
  // Supplier payment requests
  // ---------------------------------------------------------------

  Future<List<SupplierPaymentRequestRow>> fetchPaymentRequests(
      {String? siteId}) async {
    try {
      var query = _client.from(_requestsTable).select();
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('requested_at', ascending: false);
      return (response as List)
          .map((j) =>
              SupplierPaymentRequestRow.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching supplier payment requests: $e');
      return [];
    }
  }

  Future<SupplierPaymentRequestRow?> insertPaymentRequest(
      SupplierPaymentRequestRow row) async {
    try {
      final response = await _client
          .from(_requestsTable)
          .insert(row.toJson())
          .select()
          .single();
      return SupplierPaymentRequestRow.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting supplier payment request: $e');
      return null;
    }
  }

  Future<bool> updatePaymentRequest(
    String id, {
    String? status,
    String? paymentProof,
  }) async {
    try {
      await _client.from(_requestsTable).update({
        if (status != null) 'status': status,
        if (paymentProof != null) 'payment_proof': paymentProof,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating supplier payment request: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Payment accounts (one per worker per month)
  // ---------------------------------------------------------------

  Future<List<PaymentAccountRow>> fetchAccounts(
    DateTime month, {
    String? siteId,
  }) async {
    try {
      final monthKey = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';
      var query = _client
          .from(_accountsTable)
          .select()
          .eq('payment_month', monthKey);
      if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('worker_name', ascending: true);
      return (response as List)
          .map((j) => PaymentAccountRow.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching payment accounts: $e');
      return [];
    }
  }

  /// Upsert an account keyed on (site_id, worker_id, payment_month).
  Future<PaymentAccountRow?> upsertAccount(PaymentAccountRow row) async {
    try {
      final json = row.toJson();
      final response = await _client
          .from(_accountsTable)
          .upsert(json, onConflict: 'site_id,worker_id,payment_month')
          .select()
          .single();
      return PaymentAccountRow.fromJson(response);
    } catch (e) {
      debugPrint('Error upserting payment account: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------
  // Payment ledger
  // ---------------------------------------------------------------

  Future<List<PaymentLedgerRow>> fetchLedger(
      {String? accountId, String? siteId}) async {
    try {
      var query = _client.from(_ledgerTable).select();
      if (accountId != null && accountId.isNotEmpty) {
        query = query.eq('account_id', accountId);
      } else if (siteId != null && siteId.isNotEmpty) {
        query = query.eq('site_id', siteId);
      }
      final response = await query.order('entry_date', ascending: false);
      return (response as List)
          .map((j) => PaymentLedgerRow.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching payment ledger: $e');
      return [];
    }
  }

  Future<PaymentLedgerRow?> insertLedgerEntry(PaymentLedgerRow row) async {
    try {
      final response = await _client
          .from(_ledgerTable)
          .insert(row.toJson())
          .select()
          .single();
      return PaymentLedgerRow.fromJson(response);
    } catch (e) {
      debugPrint('Error inserting payment ledger entry: $e');
      return null;
    }
  }

  Future<bool> updateLedgerEntry(
    String id, {
    String? status,
    String? proofId,
    bool? registeredInMachineIdsBook,
  }) async {
    try {
      await _client.from(_ledgerTable).update({
        if (status != null) 'status': status,
        if (proofId != null) 'proof_id': proofId,
        if (registeredInMachineIdsBook != null)
          'registered_in_machine_ids_book': registeredInMachineIdsBook,
      }).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating payment ledger entry: $e');
      return false;
    }
  }
}
