import '../models/machine_asset.dart';
import '../models/machine_daily_log.dart';
import '../models/machine_payment_request.dart';
import '../models/machine_supplier.dart';

/// Production-grade repository for HOD Machine workflows.
///
/// All methods assume the caller has already been authorized by RLS
/// at the database layer. Do not duplicate auth checks in the client.
abstract class HodMachineRepository {
  // ── Suppliers ───────────────────────────────────────────────
  Future<List<MachineSupplier>> getSuppliers({required String siteId});
  Future<MachineSupplier> createSupplier({
    required String siteId,
    required String name,
    required String type,
    String? phone,
    double? rating,
    String? notes,
    required String createdBy,
  });

  // ── Machine Assets ─────────────────────────────────────────
  Future<List<MachineAsset>> getMachines({required String siteId});
  Future<MachineAsset> createMachine({required MachineAsset machine});

  // ── Daily Logs ─────────────────────────────────────────────
  Future<List<MachineDailyLog>> getDailyLogs({
    required String siteId,
    String? thavvuPointId,
    String? supervisorId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  });
  Future<MachineDailyLog> submitDailyLog(MachineDailyLog log);
  Future<MachineDailyLog> reviewDailyLog({
    required String logId,
    required String hodId,
    required String status,
    String? hodNote,
  });

  // ── Payment / Finance ──────────────────────────────────────
  Future<List<MachinePaymentRequest>> getPaymentRequests({
    required String siteId,
    String? status,
  });
  Future<MachinePaymentRequest> createPaymentRequest(
      MachinePaymentRequest request);
  Future<MachinePaymentRequest> approvePaymentByHod({
    required String paymentId,
    required String hodId,
  });
  Future<MachinePaymentRequest> submitApprovedPaymentToFinance({
    required String paymentId,
  });
  Future<MachinePaymentRequest> completeFinancePayment({
    required String paymentId,
    required String proofPath,
    required bool registerInIdsBook,
  });
}
