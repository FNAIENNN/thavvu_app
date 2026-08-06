import 'dart:async';

import 'package:flutter/material.dart';
import '../../../services/supabase_supplier_repository.dart';
import '../../../theme/app_theme.dart';

// ============================================================================
// HOD Suppliers Module - Fully Upgraded
// ----------------------------------------------------------------------------
// This file replaces the old hod_suppliers_screen.dart.
// It implements the rebuild specification:
// - 5 tabs: Machines, Rentals, Workers, Other, History
// - Each of first 4 tabs: Supplier Setup, Ledger Table, Payments
// - Dual payment tracking (Principal & Commission) with separate checkboxes
// - Reusable Request Payment component (Cash Payment removed)
// - History tab with search & filters
// - Cross-module sync for machine suppliers via singleton repository
// ============================================================================

// ─── Enums and Extensions ────────────────────────────────────────────────

enum SupplierGroup { machine, rental, worker, other }

enum PaymentTargetType {
  machineHire,
  supplierCommission,
  rentalSupplier,
  workerSupplier,
  otherSupplier,
}

enum PaymentStatus { requested, completed, rejected }

enum PaymentMode { upi, bank }

extension SupplierGroupX on SupplierGroup {
  String get shortTitle {
    switch (this) {
      case SupplierGroup.machine:
        return 'Mach';
      case SupplierGroup.rental:
        return 'Rent';
      case SupplierGroup.worker:
        return 'Work';
      case SupplierGroup.other:
        return 'Other';
    }
  }

  String get title {
    switch (this) {
      case SupplierGroup.machine:
        return 'Machine Suppliers';
      case SupplierGroup.rental:
        return 'Rental Suppliers';
      case SupplierGroup.worker:
        return 'Worker Suppliers';
      case SupplierGroup.other:
        return 'Other Suppliers';
    }
  }

  String get subtitle {
    switch (this) {
      case SupplierGroup.machine:
        return 'Create machine suppliers, track machine logs, commission, beta, diesel and dues.';
      case SupplierGroup.rental:
        return 'Create rental suppliers, track rental bills, commission and payments.';
      case SupplierGroup.worker:
        return 'Create worker suppliers/mestris, track worker work, commission and payments.';
      case SupplierGroup.other:
        return 'Create miscellaneous suppliers and maintain all other bill/payment records.';
    }
  }

  IconData get icon {
    switch (this) {
      case SupplierGroup.machine:
        return Icons.precision_manufacturing_rounded;
      case SupplierGroup.rental:
        return Icons.handshake_rounded;
      case SupplierGroup.worker:
        return Icons.groups_rounded;
      case SupplierGroup.other:
        return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case SupplierGroup.machine:
        return AppTheme.info;
      case SupplierGroup.rental:
        return AppTheme.warning;
      case SupplierGroup.worker:
        return AppTheme.success;
      case SupplierGroup.other:
        return AppTheme.textSecondary;
    }
  }
}

extension PaymentTargetTypeX on PaymentTargetType {
  String get label {
    switch (this) {
      case PaymentTargetType.machineHire:
        return 'Machine Payment';
      case PaymentTargetType.supplierCommission:
        return 'Supplier Commission';
      case PaymentTargetType.rentalSupplier:
        return 'Rental Supplier';
      case PaymentTargetType.workerSupplier:
        return 'Worker Supplier';
      case PaymentTargetType.otherSupplier:
        return 'Other Supplier';
    }
  }
}

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.requested:
        return 'Requested';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.requested:
        return AppTheme.warning;
      case PaymentStatus.completed:
        return AppTheme.success;
      case PaymentStatus.rejected:
        return AppTheme.danger;
    }
  }
}

extension PaymentModeX on PaymentMode {
  String get label {
    switch (this) {
      case PaymentMode.upi:
        return 'UPI';
      case PaymentMode.bank:
        return 'Bank Transfer';
    }
  }
}

// ─── Models ──────────────────────────────────────────────────────────────

class SupplierPaymentDetails {
  final String upiId;
  final String accountHolder;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String paymentNote;

  const SupplierPaymentDetails({
    this.upiId = '',
    this.accountHolder = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.paymentNote = '',
  });

  SupplierPaymentDetails copyWith({
    String? upiId,
    String? accountHolder,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? paymentNote,
  }) {
    return SupplierPaymentDetails(
      upiId: upiId ?? this.upiId,
      accountHolder: accountHolder ?? this.accountHolder,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      paymentNote: paymentNote ?? this.paymentNote,
    );
  }
}

class HodSupplierRecord {
  final String id;
  final SupplierGroup group;
  final String name;
  final String contactPerson;
  final String phone;
  final String address;
  final String siteName;
  final String siteId;
  final String thavvuPointId;
  final double defaultCommissionPercent;
  final SupplierPaymentDetails paymentDetails;
  final String notes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const HodSupplierRecord({
    required this.id,
    required this.group,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.address,
    required this.siteName,
    required this.siteId,
    required this.thavvuPointId,
    required this.defaultCommissionPercent,
    required this.paymentDetails,
    required this.notes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  HodSupplierRecord copyWith({
    String? id,
    SupplierGroup? group,
    String? name,
    String? contactPerson,
    String? phone,
    String? address,
    String? siteName,
    String? siteId,
    String? thavvuPointId,
    double? defaultCommissionPercent,
    SupplierPaymentDetails? paymentDetails,
    String? notes,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HodSupplierRecord(
      id: id ?? this.id,
      group: group ?? this.group,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      siteName: siteName ?? this.siteName,
      siteId: siteId ?? this.siteId,
      thavvuPointId: thavvuPointId ?? this.thavvuPointId,
      defaultCommissionPercent:
          defaultCommissionPercent ?? this.defaultCommissionPercent,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MachineWorkLogRecord {
  final String id;
  final String supplierId;
  final String machineType;
  final String machineName;
  final String basisOfFare;
  final double fare;
  final double totalWorkPerformed;
  final double dieselUsedAmount;
  final double betaAmount;
  final double commissionPercent;
  final double amountPaid;           // total paid towards principal (machine hire)
  final DateTime startDate;
  final DateTime? endDate;
  final String checkingPurpose;
  final bool machinePaymentDone;     // principal payment done
  final bool supplierPaymentDone;    // commission payment done
  final String remarks;

  const MachineWorkLogRecord({
    required this.id,
    required this.supplierId,
    required this.machineType,
    required this.machineName,
    required this.basisOfFare,
    required this.fare,
    required this.totalWorkPerformed,
    required this.dieselUsedAmount,
    required this.betaAmount,
    required this.commissionPercent,
    required this.amountPaid,
    required this.startDate,
    required this.endDate,
    required this.checkingPurpose,
    required this.machinePaymentDone,
    required this.supplierPaymentDone,
    required this.remarks,
  });

  double get amountEarned => fare * totalWorkPerformed;
  double get commissionAmount => amountEarned * commissionPercent / 100;
  double get netPayable => amountEarned + betaAmount - dieselUsedAmount - commissionAmount;
  double get duePrincipal => netPayable - amountPaid;
  bool get fullyClosed => machinePaymentDone && supplierPaymentDone;
  String get status => fullyClosed ? 'Closed' : 'Pending';

  MachineWorkLogRecord copyWith({
    String? id,
    String? supplierId,
    String? machineType,
    String? machineName,
    String? basisOfFare,
    double? fare,
    double? totalWorkPerformed,
    double? dieselUsedAmount,
    double? betaAmount,
    double? commissionPercent,
    double? amountPaid,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    String? checkingPurpose,
    bool? machinePaymentDone,
    bool? supplierPaymentDone,
    String? remarks,
  }) {
    return MachineWorkLogRecord(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      machineType: machineType ?? this.machineType,
      machineName: machineName ?? this.machineName,
      basisOfFare: basisOfFare ?? this.basisOfFare,
      fare: fare ?? this.fare,
      totalWorkPerformed: totalWorkPerformed ?? this.totalWorkPerformed,
      dieselUsedAmount: dieselUsedAmount ?? this.dieselUsedAmount,
      betaAmount: betaAmount ?? this.betaAmount,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      amountPaid: amountPaid ?? this.amountPaid,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      checkingPurpose: checkingPurpose ?? this.checkingPurpose,
      machinePaymentDone: machinePaymentDone ?? this.machinePaymentDone,
      supplierPaymentDone: supplierPaymentDone ?? this.supplierPaymentDone,
      remarks: remarks ?? this.remarks,
    );
  }
}

class SupplierLedgerRecord {
  final String id;
  final SupplierGroup group;
  final String supplierId;
  final String title;
  final String workType;
  final double quantity;
  final String unit;
  final double rate;
  final double commissionPercent;
  final double betaAmount;           // may be used for some tabs, but not mandatory
  final double amountPaid;           // total paid (principal + commission)
  final DateTime workDate;
  final String remarks;
  final bool principalPaymentDone;   // indicates the principal (net payable) is fully paid
  final bool commissionPaymentDone;  // indicates commission is fully paid

  const SupplierLedgerRecord({
    required this.id,
    required this.group,
    required this.supplierId,
    required this.title,
    required this.workType,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.commissionPercent,
    required this.betaAmount,
    required this.amountPaid,
    required this.workDate,
    required this.remarks,
    required this.principalPaymentDone,
    required this.commissionPaymentDone,
  });

  double get amountEarned => quantity * rate;
  double get commissionAmount => amountEarned * commissionPercent / 100;
  double get netPayable => amountEarned + betaAmount - commissionAmount;
  // Simplify: we track total due as sum of remaining principal and commission.
  double get totalDue => (netPayable - (principalPaymentDone ? netPayable : 0)) +
                         (commissionAmount - (commissionPaymentDone ? commissionAmount : 0));

  SupplierLedgerRecord copyWith({
    String? id,
    SupplierGroup? group,
    String? supplierId,
    String? title,
    String? workType,
    double? quantity,
    String? unit,
    double? rate,
    double? commissionPercent,
    double? betaAmount,
    double? amountPaid,
    DateTime? workDate,
    String? remarks,
    bool? principalPaymentDone,
    bool? commissionPaymentDone,
  }) {
    return SupplierLedgerRecord(
      id: id ?? this.id,
      group: group ?? this.group,
      supplierId: supplierId ?? this.supplierId,
      title: title ?? this.title,
      workType: workType ?? this.workType,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      betaAmount: betaAmount ?? this.betaAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      workDate: workDate ?? this.workDate,
      remarks: remarks ?? this.remarks,
      principalPaymentDone: principalPaymentDone ?? this.principalPaymentDone,
      commissionPaymentDone: commissionPaymentDone ?? this.commissionPaymentDone,
    );
  }
}

class SupplierPaymentRequestRecord {
  final String id;
  final String supplierId;
  final String supplierName;
  final PaymentTargetType targetType;
  final String targetId;
  final String targetName;
  final double amount;
  final PaymentMode mode;
  final String upiId;
  final String bankName;
  final String accountNumber;
  final String ifsc;
  final String entryMethod;
  final PaymentStatus status;
  final String paymentProof;
  final bool registeredInBook;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String requestedBy;
  final String notes;

  const SupplierPaymentRequestRecord({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.amount,
    required this.mode,
    required this.upiId,
    required this.bankName,
    required this.accountNumber,
    required this.ifsc,
    required this.entryMethod,
    required this.status,
    required this.paymentProof,
    required this.registeredInBook,
    required this.requestedAt,
    required this.completedAt,
    required this.requestedBy,
    required this.notes,
  });

  SupplierPaymentRequestRecord copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    PaymentTargetType? targetType,
    String? targetId,
    String? targetName,
    double? amount,
    PaymentMode? mode,
    String? upiId,
    String? bankName,
    String? accountNumber,
    String? ifsc,
    String? entryMethod,
    PaymentStatus? status,
    String? paymentProof,
    bool? registeredInBook,
    DateTime? requestedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? requestedBy,
    String? notes,
  }) {
    return SupplierPaymentRequestRecord(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      upiId: upiId ?? this.upiId,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifsc: ifsc ?? this.ifsc,
      entryMethod: entryMethod ?? this.entryMethod,
      status: status ?? this.status,
      paymentProof: paymentProof ?? this.paymentProof,
      registeredInBook: registeredInBook ?? this.registeredInBook,
      requestedAt: requestedAt ?? this.requestedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      requestedBy: requestedBy ?? this.requestedBy,
      notes: notes ?? this.notes,
    );
  }
}

class SupplierHistoryRecord {
  final String id;
  final DateTime date;
  final String module;
  final String supplierName;
  final String action;
  final String target;
  final double amount;
  final String status;
  final String notes;

  const SupplierHistoryRecord({
    required this.id,
    required this.date,
    required this.module,
    required this.supplierName,
    required this.action,
    required this.target,
    required this.amount,
    required this.status,
    required this.notes,
  });
}

// ─── Repository (Singleton) ──────────────────────────────────────────────

class HodSupplierRepository {
  static final HodSupplierRepository _instance = HodSupplierRepository._internal();
  factory HodSupplierRepository() => _instance;
  HodSupplierRepository._internal() {
    _initSeedData();
  }

  late List<HodSupplierRecord> _suppliers;
  late List<MachineWorkLogRecord> _machineLogs;
  late List<SupplierLedgerRecord> _ledger;
  final List<SupplierPaymentRequestRecord> _payments = [];
  final List<SupplierHistoryRecord> _history = [];

  void _initSeedData() {
    final now = DateTime.now();
    _suppliers = [
      HodSupplierRecord(
        id: 'SUP-M-001',
        group: SupplierGroup.machine,
        name: 'Pamu',
        contactPerson: 'Pamu',
        phone: '9876543210',
        address: 'Kakinada',
        siteName: 'Site A',
        siteId: 'SITE-001',
        thavvuPointId: 'TP-001',
        defaultCommissionPercent: 2.0,
        paymentDetails: const SupplierPaymentDetails(
          upiId: 'pamu@upi',
          accountHolder: 'Pamu',
          bankName: 'SBI',
          accountNumber: '1234567890',
          ifsc: 'SBIN0001234',
          paymentNote: 'Preferred UPI for small payments.',
        ),
        notes: 'Machine mestri/supplier for tractors.',
        active: true,
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      HodSupplierRecord(
        id: 'SUP-M-002',
        group: SupplierGroup.machine,
        name: 'Anjinayalu',
        contactPerson: 'Anjinayalu',
        phone: '9876500001',
        address: 'Rajahmundry',
        siteName: 'Site A',
        siteId: 'SITE-001',
        thavvuPointId: 'TP-001',
        defaultCommissionPercent: 2.5,
        paymentDetails: const SupplierPaymentDetails(upiId: 'anjinayalu@upi'),
        notes: 'Hourly poclain supplier.',
        active: true,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      HodSupplierRecord(
        id: 'SUP-R-001',
        group: SupplierGroup.rental,
        name: 'Delta Rentals',
        contactPerson: 'Ravi',
        phone: '9876501111',
        address: 'Yanam Road',
        siteName: 'Site A',
        siteId: 'SITE-001',
        thavvuPointId: 'TP-002',
        defaultCommissionPercent: 1.5,
        paymentDetails: const SupplierPaymentDetails(upiId: 'deltarentals@upi'),
        notes: 'Rental material and equipment supplier.',
        active: true,
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now,
      ),
      HodSupplierRecord(
        id: 'SUP-W-001',
        group: SupplierGroup.worker,
        name: 'Sri Worker Mestri',
        contactPerson: 'Suresh',
        phone: '9876502222',
        address: 'Amalapuram',
        siteName: 'Site B',
        siteId: 'SITE-002',
        thavvuPointId: 'TP-008',
        defaultCommissionPercent: 1.0,
        paymentDetails: const SupplierPaymentDetails(upiId: 'sriworkers@upi'),
        notes: 'Outside workers supplier/mestri.',
        active: true,
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now,
      ),
      HodSupplierRecord(
        id: 'SUP-O-001',
        group: SupplierGroup.other,
        name: 'General Supplier',
        contactPerson: 'Mohan',
        phone: '9876503333',
        address: 'Kakinada',
        siteName: 'Site A',
        siteId: 'SITE-001',
        thavvuPointId: 'TP-001',
        defaultCommissionPercent: 0.0,
        paymentDetails: const SupplierPaymentDetails(upiId: 'general@upi'),
        notes: 'Miscellaneous bills supplier.',
        active: true,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ),
    ];

    _machineLogs = [
      MachineWorkLogRecord(
        id: 'MLOG-001',
        supplierId: 'SUP-M-001',
        machineType: 'Poclain',
        machineName: 'Poclain Srinu Ex 70',
        basisOfFare: 'Hourly',
        fare: 850,
        totalWorkPerformed: 699.83,
        dieselUsedAmount: 203600,
        betaAmount: 699.50,
        commissionPercent: 2,
        amountPaid: 385400,
        startDate: now.subtract(const Duration(days: 45)),
        endDate: now.subtract(const Duration(days: 2)),
        checkingPurpose: '699:50',
        machinePaymentDone: true,
        supplierPaymentDone: false,
        remarks: 'Machine closed, supplier commission pending.',
      ),
      MachineWorkLogRecord(
        id: 'MLOG-002',
        supplierId: 'SUP-M-001',
        machineType: 'Tractor',
        machineName: 'Tractor 0093',
        basisOfFare: 'Day',
        fare: 1100,
        totalWorkPerformed: 40.25,
        dieselUsedAmount: 2600,
        betaAmount: 0,
        commissionPercent: 2,
        amountPaid: 41400,
        startDate: now.subtract(const Duration(days: 35)),
        endDate: now.subtract(const Duration(days: 1)),
        checkingPurpose: '40.25',
        machinePaymentDone: true,
        supplierPaymentDone: true,
        remarks: 'Closed fully.',
      ),
      MachineWorkLogRecord(
        id: 'MLOG-003',
        supplierId: 'SUP-M-001',
        machineType: 'Tractor',
        machineName: 'Tractor 2887',
        basisOfFare: 'Day',
        fare: 1100,
        totalWorkPerformed: 41,
        dieselUsedAmount: 1750,
        betaAmount: 0,
        commissionPercent: 2,
        amountPaid: 43100,
        startDate: now.subtract(const Duration(days: 29)),
        endDate: now.subtract(const Duration(days: 1)),
        checkingPurpose: '41',
        machinePaymentDone: false,
        supplierPaymentDone: false,
        remarks: 'Pending due and commission.',
      ),
      MachineWorkLogRecord(
        id: 'MLOG-004',
        supplierId: 'SUP-M-002',
        machineType: 'Poclain',
        machineName: 'Poclain Ramana EX - 70',
        basisOfFare: 'Hourly',
        fare: 850,
        totalWorkPerformed: 566.08,
        dieselUsedAmount: 201000,
        betaAmount: 566.05,
        commissionPercent: 2.5,
        amountPaid: 276050,
        startDate: now.subtract(const Duration(days: 50)),
        endDate: now,
        checkingPurpose: '566:05',
        machinePaymentDone: true,
        supplierPaymentDone: false,
        remarks: 'Machine payment closed; supplier commission remains.',
      ),
    ];

    _ledger = [
      SupplierLedgerRecord(
        id: 'RLED-001',
        group: SupplierGroup.rental,
        supplierId: 'SUP-R-001',
        title: 'Water motor rental',
        workType: 'Weekly rental',
        quantity: 2,
        unit: 'weeks',
        rate: 3500,
        commissionPercent: 1.5,
        betaAmount: 0,
        amountPaid: 3500,
        workDate: now.subtract(const Duration(days: 2)),
        remarks: 'Partial payment pending.',
        principalPaymentDone: false,
        commissionPaymentDone: false,
      ),
      SupplierLedgerRecord(
        id: 'WLED-001',
        group: SupplierGroup.worker,
        supplierId: 'SUP-W-001',
        title: 'Outside worker batch',
        workType: 'Full day',
        quantity: 18,
        unit: 'workers',
        rate: 650,
        commissionPercent: 1,
        betaAmount: 0,
        amountPaid: 0,
        workDate: now.subtract(const Duration(days: 1)),
        remarks: 'From attendance module daily wages.',
        principalPaymentDone: false,
        commissionPaymentDone: false,
      ),
      SupplierLedgerRecord(
        id: 'OLED-001',
        group: SupplierGroup.other,
        supplierId: 'SUP-O-001',
        title: 'Site small consumables',
        workType: 'Bill',
        quantity: 1,
        unit: 'bill',
        rate: 4200,
        commissionPercent: 0,
        betaAmount: 0,
        amountPaid: 4200,
        workDate: now,
        remarks: 'Paid completely.',
        principalPaymentDone: true,
        commissionPaymentDone: true,
      ),
    ];

    _history.addAll([
      SupplierHistoryRecord(
        id: 'HIS-001',
        date: DateTime.now().subtract(const Duration(days: 1)),
        module: 'Mach',
        supplierName: 'Pamu',
        action: 'Daily log imported',
        target: 'Tractor 0093',
        amount: 44275,
        status: 'Synced',
        notes: 'Demo data from supervisor daily machine log.',
      ),
    ]);
  }

  // ─── Getters ──────────────────────────────────────────────────────────

  List<HodSupplierRecord> get suppliers => List.unmodifiable(_suppliers);
  List<MachineWorkLogRecord> get machineLogs => List.unmodifiable(_machineLogs);
  List<SupplierLedgerRecord> get ledger => List.unmodifiable(_ledger);
  List<SupplierPaymentRequestRecord> get payments => List.unmodifiable(_payments);
  List<SupplierHistoryRecord> get history => List.unmodifiable(_history);

  // ─── Mutators ─────────────────────────────────────────────────────────

  void upsertSupplier(HodSupplierRecord value) {
    final index = _suppliers.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      _suppliers.insert(0, value);
    } else {
      _suppliers[index] = value;
    }
  }

  void deleteSupplier(String id) {
    _suppliers.removeWhere((item) => item.id == id);
  }

  void upsertMachineLog(MachineWorkLogRecord value) {
    final index = _machineLogs.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      _machineLogs.insert(0, value);
    } else {
      _machineLogs[index] = value;
    }
  }

  void upsertLedger(SupplierLedgerRecord value) {
    final index = _ledger.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      _ledger.insert(0, value);
    } else {
      _ledger[index] = value;
    }
  }

  void upsertPayment(SupplierPaymentRequestRecord value) {
    final index = _payments.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      _payments.insert(0, value);
    } else {
      _payments[index] = value;
    }
  }

  void addHistory(SupplierHistoryRecord value) {
    _history.insert(0, value);
  }

  String newSupplierId(SupplierGroup group) =>
      'SUP-${group.shortTitle.toUpperCase()}-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
  String newMachineLogId() =>
      'MLOG-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
  String newLedgerId(SupplierGroup group) =>
      '${group.shortTitle.toUpperCase()}LED-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
  String newPaymentId() =>
      'REQ-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
  String newHistoryId() =>
      'HIS-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
}

// ─── Main Screen ─────────────────────────────────────────────────────────

class HodSuppliersScreen extends StatefulWidget {
  const HodSuppliersScreen({super.key});

  @override
  State<HodSuppliersScreen> createState() => _HodSuppliersScreenState();
}

class _HodSuppliersScreenState extends State<HodSuppliersScreen> {
  final _repo = HodSupplierRepository();
  final _searchController = TextEditingController();
  final _historySearchController = TextEditingController();

  List<HodSupplierRecord> _suppliers = [];
  List<MachineWorkLogRecord> _machineLogs = [];
  List<SupplierLedgerRecord> _ledger = [];
  List<SupplierPaymentRequestRecord> _payments = [];
  List<SupplierHistoryRecord> _history = [];

  bool _loading = true;
  String _search = '';
  String _historySearch = '';
  String _historyModuleFilter = 'All';
  String? _selectedPaymentSupplierId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    _suppliers = _repo.suppliers;
    _machineLogs = _repo.machineLogs;
    _ledger = _repo.ledger;
    _payments = _repo.payments;
    _history = _repo.history;
    _selectedPaymentSupplierId ??= _suppliers.isNotEmpty ? _suppliers.first.id : null;
    setState(() => _loading = false);
  }

  HodSupplierRecord? _supplierById(String id) {
    try {
      return _suppliers.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  List<HodSupplierRecord> _filteredSuppliers(SupplierGroup group) {
    final query = _search.trim().toLowerCase();
    return _suppliers.where((supplier) {
      if (supplier.group != group) return false;
      if (query.isEmpty) return true;
      return supplier.name.toLowerCase().contains(query) ||
          supplier.contactPerson.toLowerCase().contains(query) ||
          supplier.phone.toLowerCase().contains(query) ||
          supplier.siteName.toLowerCase().contains(query) ||
          supplier.thavvuPointId.toLowerCase().contains(query) ||
          supplier.notes.toLowerCase().contains(query);
    }).toList();
  }

  List<MachineWorkLogRecord> get _machineLogsFiltered {
    final query = _search.trim().toLowerCase();
    return _machineLogs.where((log) {
      final supplier = _supplierById(log.supplierId);
      if (query.isEmpty) return true;
      return log.machineType.toLowerCase().contains(query) ||
          log.machineName.toLowerCase().contains(query) ||
          log.basisOfFare.toLowerCase().contains(query) ||
          (supplier?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<SupplierLedgerRecord> _ledgerForGroup(SupplierGroup group) {
    final query = _search.trim().toLowerCase();
    return _ledger.where((item) {
      if (item.group != group) return false;
      final supplier = _supplierById(item.supplierId);
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.workType.toLowerCase().contains(query) ||
          item.remarks.toLowerCase().contains(query) ||
          (supplier?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  // ─── History Helpers ────────────────────────────────────────────────

  Future<void> _addHistory({
    required String module,
    required String supplierName,
    required String action,
    required String target,
    required double amount,
    required String status,
    required String notes,
  }) async {
    _repo.addHistory(
      SupplierHistoryRecord(
        id: _repo.newHistoryId(),
        date: DateTime.now(),
        module: module,
        supplierName: supplierName,
        action: action,
        target: target,
        amount: amount,
        status: status,
        notes: notes,
      ),
    );
  }

  // ─── Supplier CRUD ──────────────────────────────────────────────────

  Future<void> _openSupplierSheet({
    required SupplierGroup group,
    HodSupplierRecord? supplier,
  }) async {
    final saved = await showModalBottomSheet<HodSupplierRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierEditSheet(
        group: group,
        supplier: supplier,
        newId: () => _repo.newSupplierId(group),
      ),
    );
    if (saved == null) return;
    _repo.upsertSupplier(saved);
    // Sync to the enterprise catalog so every supervisor sees it instantly.
    final syncOk = await SupabaseSupplierRepository().upsertRaw({
      'id': saved.id,
      'group_name': saved.group.title,
      'name': saved.name,
      'contact_person': saved.contactPerson,
      'phone': saved.phone,
      'address': saved.address,
      'site_name': saved.siteName,
      'site_id': saved.siteId,
      'thavvu_point_id': saved.thavvuPointId,
      'default_commission_percent': saved.defaultCommissionPercent,
      'payment_upi': saved.paymentDetails.upiId,
      'payment_account_holder': saved.paymentDetails.accountHolder,
      'payment_bank': saved.paymentDetails.bankName,
      'payment_account_number': saved.paymentDetails.accountNumber,
      'payment_ifsc': saved.paymentDetails.ifsc,
      'payment_note': saved.paymentDetails.paymentNote,
      'notes': saved.notes,
      'active': saved.active,
      'is_demo': false,
      'created_at': saved.createdAt.toUtc().toIso8601String(),
    });
    await _addHistory(
      module: saved.group.shortTitle,
      supplierName: saved.name,
      action: supplier == null ? 'Supplier created' : 'Supplier edited',
      target: saved.group.title,
      amount: 0,
      status: saved.active ? 'Active' : 'Inactive',
      notes: saved.notes,
    );
    await _loadAll();
    if (!mounted) return;
    if (!syncOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saved locally, but the Supabase sync failed. Check your connection and try again.',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${saved.name} saved successfully')),
    );
  }

  Future<void> _deleteSupplier(HodSupplierRecord supplier) async {
    final hasMachineLogs = _machineLogs.any((item) => item.supplierId == supplier.id);
    final hasLedger = _ledger.any((item) => item.supplierId == supplier.id);
    if (hasMachineLogs || hasLedger) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This supplier has work/payment data. Mark inactive instead of deleting.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete supplier?'),
        content: Text('${supplier.name} will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _repo.deleteSupplier(supplier.id);
    final deleteOk = await SupabaseSupplierRepository().deleteRaw(supplier.id);
    await _addHistory(
      module: supplier.group.shortTitle,
      supplierName: supplier.name,
      action: 'Supplier deleted',
      target: supplier.group.title,
      amount: 0,
      status: 'Deleted',
      notes: 'Deleted by HOD.',
    );
    await _loadAll();
    if (!mounted) return;
    if (!deleteOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Removed locally, but the Supabase delete failed. Check your connection and retry.',
          ),
        ),
      );
    }
  }

  // ─── Machine Log CRUD ──────────────────────────────────────────────

  Future<void> _openMachineLogSheet([MachineWorkLogRecord? log]) async {
    final machineSuppliers = _suppliers.where((item) => item.group == SupplierGroup.machine).toList();
    if (machineSuppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create at least one machine supplier first.')),
      );
      return;
    }
    final saved = await showModalBottomSheet<MachineWorkLogRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MachineLogEditSheet(
        log: log,
        suppliers: machineSuppliers,
        newId: _repo.newMachineLogId,
      ),
    );
    if (saved == null) return;
    _repo.upsertMachineLog(saved);
    final supplier = _supplierById(saved.supplierId);
    await _addHistory(
      module: 'Mach',
      supplierName: supplier?.name ?? saved.supplierId,
      action: log == null ? 'Machine log added' : 'Machine log edited',
      target: saved.machineName,
      amount: saved.netPayable,
      status: saved.status,
      notes: 'Commission and beta recalculated.',
    );
    await _loadAll();
  }

  Future<void> _toggleMachinePaymentDone(MachineWorkLogRecord log, bool value) async {
    _repo.upsertMachineLog(log.copyWith(machinePaymentDone: value));
    final supplier = _supplierById(log.supplierId);
    await _addHistory(
      module: 'Mach',
      supplierName: supplier?.name ?? log.supplierId,
      action: 'Machine payment tick ${value ? 'enabled' : 'removed'}',
      target: log.machineName,
      amount: log.netPayable,
      status: value ? 'Done' : 'Pending',
      notes: 'Manual checkbox updated by HOD.',
    );
    await _loadAll();
  }

  Future<void> _toggleSupplierPaymentDone(MachineWorkLogRecord log, bool value) async {
    _repo.upsertMachineLog(log.copyWith(supplierPaymentDone: value));
    final supplier = _supplierById(log.supplierId);
    await _addHistory(
      module: 'Mach',
      supplierName: supplier?.name ?? log.supplierId,
      action: 'Supplier commission tick ${value ? 'enabled' : 'removed'}',
      target: log.machineName,
      amount: log.commissionAmount,
      status: value ? 'Done' : 'Pending',
      notes: 'Manual checkbox updated by HOD.',
    );
    await _loadAll();
  }

  // ─── Ledger CRUD ────────────────────────────────────────────────────

  Future<void> _openLedgerSheet({
    required SupplierGroup group,
    SupplierLedgerRecord? ledger,
  }) async {
    final suppliers = _suppliers.where((item) => item.group == group).toList();
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create at least one ${group.title.toLowerCase()} first.')),
      );
      return;
    }

    final saved = await showModalBottomSheet<SupplierLedgerRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LedgerEditSheet(
        group: group,
        ledger: ledger,
        suppliers: suppliers,
        newId: () => _repo.newLedgerId(group),
      ),
    );
    if (saved == null) return;
    _repo.upsertLedger(saved);
    final supplier = _supplierById(saved.supplierId);
    await _addHistory(
      module: group.shortTitle,
      supplierName: supplier?.name ?? saved.supplierId,
      action: ledger == null ? 'Ledger added' : 'Ledger edited',
      target: saved.title,
      amount: saved.netPayable,
      status: saved.principalPaymentDone && saved.commissionPaymentDone ? 'Closed' : 'Pending',
      notes: saved.remarks,
    );
    await _loadAll();
  }

  Future<void> _togglePrincipalPaymentDone(SupplierLedgerRecord item, bool value) async {
    _repo.upsertLedger(item.copyWith(principalPaymentDone: value));
    final supplier = _supplierById(item.supplierId);
    await _addHistory(
      module: item.group.shortTitle,
      supplierName: supplier?.name ?? item.supplierId,
      action: 'Principal payment tick ${value ? 'enabled' : 'removed'}',
      target: item.title,
      amount: item.netPayable,
      status: value ? 'Done' : 'Pending',
      notes: 'Manual checkbox updated by HOD.',
    );
    await _loadAll();
  }

  Future<void> _toggleCommissionPaymentDone(SupplierLedgerRecord item, bool value) async {
    _repo.upsertLedger(item.copyWith(commissionPaymentDone: value));
    final supplier = _supplierById(item.supplierId);
    await _addHistory(
      module: item.group.shortTitle,
      supplierName: supplier?.name ?? item.supplierId,
      action: 'Commission payment tick ${value ? 'enabled' : 'removed'}',
      target: item.title,
      amount: item.commissionAmount,
      status: value ? 'Done' : 'Pending',
      notes: 'Manual checkbox updated by HOD.',
    );
    await _loadAll();
  }

  // ─── Payments (Request Payment) ─────────────────────────────────────

  Future<void> _openRequestPayment({
    required HodSupplierRecord supplier,
    required PaymentTargetType targetType,
    required String targetId,
    required String targetName,
    required double initialAmount,
  }) async {
    final request = await showModalBottomSheet<SupplierPaymentRequestRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestPaymentSheet(
        newId: _repo.newPaymentId,
        supplier: supplier,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        initialAmount: initialAmount < 0 ? 0 : initialAmount,
      ),
    );
    if (request == null) return;
    _repo.upsertPayment(request);
    await _addHistory(
      module: 'Pay',
      supplierName: supplier.name,
      action: 'Request payment sent',
      target: '${targetType.label} · $targetName',
      amount: request.amount,
      status: request.status.label,
      notes: request.notes,
    );
    await _loadAll();
  }

  Future<void> _markPaymentStatus(SupplierPaymentRequestRecord request, PaymentStatus status) async {
    final updated = request.copyWith(
      status: status,
      completedAt: status == PaymentStatus.completed ? DateTime.now() : null,
      clearCompletedAt: status != PaymentStatus.completed,
      paymentProof: status == PaymentStatus.completed ? 'Proof-${request.id}' : request.paymentProof,
    );
    _repo.upsertPayment(updated);

    if (status == PaymentStatus.completed) {
      // Update the target record
      if (request.targetType == PaymentTargetType.machineHire ||
          request.targetType == PaymentTargetType.supplierCommission) {
        final index = _machineLogs.indexWhere((item) => item.id == request.targetId);
        if (index != -1) {
          final log = _machineLogs[index];
          final updatedLog = log.copyWith(
            amountPaid: request.targetType == PaymentTargetType.machineHire
                ? log.amountPaid + request.amount
                : log.amountPaid,
            machinePaymentDone: request.targetType == PaymentTargetType.machineHire
                ? true
                : log.machinePaymentDone,
            supplierPaymentDone: request.targetType == PaymentTargetType.supplierCommission
                ? true
                : log.supplierPaymentDone,
          );
          _repo.upsertMachineLog(updatedLog);
        }
      } else {
        final index = _ledger.indexWhere((item) => item.id == request.targetId);
        if (index != -1) {
          final item = _ledger[index];
          final updatedItem = item.copyWith(
            amountPaid: item.amountPaid + request.amount,
            principalPaymentDone: request.targetType == PaymentTargetType.rentalSupplier ||
                    request.targetType == PaymentTargetType.workerSupplier ||
                    request.targetType == PaymentTargetType.otherSupplier
                ? true
                : item.principalPaymentDone,
            commissionPaymentDone: request.targetType == PaymentTargetType.supplierCommission
                ? true
                : item.commissionPaymentDone,
          );
          _repo.upsertLedger(updatedItem);
        }
      }
    }

    await _addHistory(
      module: 'Pay',
      supplierName: request.supplierName,
      action: 'Payment ${status.label.toLowerCase()}',
      target: request.targetName,
      amount: request.amount,
      status: status.label,
      notes: request.notes,
    );
    await _loadAll();
  }

  // ─── Build Methods ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FC),
        appBar: AppBar(
          title: const Text('HOD Suppliers'),
          backgroundColor: const Color(0xFF0F3460),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.precision_manufacturing_rounded), text: 'Machines'),
              Tab(icon: Icon(Icons.handshake_rounded), text: 'Rentals'),
              Tab(icon: Icon(Icons.groups_rounded), text: 'Workers'),
              Tab(icon: Icon(Icons.category_rounded), text: 'Other'),
              Tab(icon: Icon(Icons.history_rounded), text: 'History'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: TabBarView(
                  children: [
                    _buildMachinesTab(),
                    _buildGeneralTab(SupplierGroup.rental),
                    _buildGeneralTab(SupplierGroup.worker),
                    _buildGeneralTab(SupplierGroup.other),
                    _buildHistoryTab(),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── Machines Tab ────────────────────────────────────────────────────

  Widget _buildMachinesTab() {
    final suppliers = _filteredSuppliers(SupplierGroup.machine);
    final gross = _machineLogs.fold<double>(0, (sum, item) => sum + item.amountEarned);
    final commission = _machineLogs.fold<double>(0, (sum, item) => sum + item.commissionAmount);
    final net = _machineLogs.fold<double>(0, (sum, item) => sum + item.netPayable);
    final due = _machineLogs.fold<double>(0, (sum, item) => sum + item.duePrincipal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ModuleHeaderCard(
          title: 'Machine Suppliers',
          subtitle: SupplierGroup.machine.subtitle,
          icon: SupplierGroup.machine.icon,
          color: SupplierGroup.machine.color,
        ),
        const SizedBox(height: 14),
        _buildGlobalSearch('Search supplier, machine, site, thavvu point'),
        const SizedBox(height: 14),
        Row(
          children: [
            _SummaryCard(label: 'Suppliers', value: '${suppliers.length}', icon: Icons.storefront_rounded, color: AppTheme.info),
            const SizedBox(width: 10),
            _SummaryCard(label: 'Gross', value: _moneyShort(gross), icon: Icons.trending_up_rounded, color: AppTheme.success),
            const SizedBox(width: 10),
            _SummaryCard(label: 'Due', value: _moneyShort(due), icon: Icons.pending_actions_rounded, color: due > 0 ? AppTheme.warning : AppTheme.success),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SummaryCard(label: 'Commission', value: _moneyShort(commission), icon: Icons.percent_rounded, color: AppTheme.warning),
            const SizedBox(width: 10),
            _SummaryCard(label: 'After Cut', value: _moneyShort(net), icon: Icons.currency_rupee_rounded, color: AppTheme.info),
          ],
        ),
        const SizedBox(height: 16),
        _ActionRow(
          title: 'Machine Supplier Directory',
          actionLabel: 'Add Mach Supplier',
          icon: Icons.add_business_rounded,
          onTap: () => _openSupplierSheet(group: SupplierGroup.machine),
        ),
        const SizedBox(height: 10),
        _buildSupplierTable(SupplierGroup.machine, suppliers),
        const SizedBox(height: 18),
        _ActionRow(
          title: 'Daily Machine Log Table',
          actionLabel: 'Add Log',
          icon: Icons.add_chart_rounded,
          onTap: _openMachineLogSheet,
        ),
        const SizedBox(height: 10),
        _buildMachineLogTable(_machineLogsFiltered),
        const SizedBox(height: 12),
        _buildMachineTotalsTable(_machineLogsFiltered),
        const SizedBox(height: 20),
        _buildPaymentSectionForGroup(SupplierGroup.machine),
      ],
    );
  }

  // ─── General Tabs (Rentals, Workers, Other) ─────────────────────────

  Widget _buildGeneralTab(SupplierGroup group) {
    final suppliers = _filteredSuppliers(group);
    final items = _ledgerForGroup(group);
    final net = items.fold<double>(0, (sum, item) => sum + item.netPayable);
    final paid = items.fold<double>(0, (sum, item) => sum + item.amountPaid);
    final totalDue = items.fold<double>(0, (sum, item) => sum + item.totalDue);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ModuleHeaderCard(
          title: group.title,
          subtitle: group.subtitle,
          icon: group.icon,
          color: group.color,
        ),
        const SizedBox(height: 14),
        _buildGlobalSearch('Search supplier, bill, work type, site'),
        const SizedBox(height: 14),
        Row(
          children: [
            _SummaryCard(label: 'Suppliers', value: '${suppliers.length}', icon: Icons.storefront_rounded, color: group.color),
            const SizedBox(width: 10),
            _SummaryCard(label: 'Payable', value: _moneyShort(net), icon: Icons.currency_rupee_rounded, color: AppTheme.info),
            const SizedBox(width: 10),
            _SummaryCard(label: 'Due', value: _moneyShort(totalDue), icon: Icons.pending_actions_rounded, color: totalDue > 0 ? AppTheme.warning : AppTheme.success),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _SummaryCard(label: 'Paid', value: _moneyShort(paid), icon: Icons.verified_rounded, color: AppTheme.success),
          ],
        ),
        const SizedBox(height: 16),
        _ActionRow(
          title: '${group.title} Directory',
          actionLabel: 'Add ${group.shortTitle}',
          icon: Icons.add_business_rounded,
          onTap: () => _openSupplierSheet(group: group),
        ),
        const SizedBox(height: 10),
        _buildSupplierTable(group, suppliers),
        const SizedBox(height: 18),
        _ActionRow(
          title: '${group.shortTitle} Ledger Table',
          actionLabel: 'Add Entry',
          icon: Icons.playlist_add_rounded,
          onTap: () => _openLedgerSheet(group: group),
        ),
        const SizedBox(height: 10),
        _buildLedgerTable(group, items),
        const SizedBox(height: 20),
        _buildPaymentSectionForGroup(group),
      ],
    );
  }

  // ─── Global Search ──────────────────────────────────────────────────

  Widget _buildGlobalSearch(String hint) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _search = value),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  // ─── Supplier Table ──────────────────────────────────────────────────

  Widget _buildSupplierTable(SupplierGroup group, List<HodSupplierRecord> suppliers) {
    return _TableShell(
      title: '${group.shortTitle} Suppliers Saved Table',
      subtitle: 'Every row is editable. UPI, bank and commission details are stored per supplier.',
      icon: group.icon,
      color: group.color,
      emptyText: 'No ${group.title.toLowerCase()} saved yet.',
      child: suppliers.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 76,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Site')),
                  DataColumn(label: Text('Thavvu')),
                  DataColumn(label: Text('Comm %')),
                  DataColumn(label: Text('UPI')),
                  DataColumn(label: Text('Bank')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Updated')),
                  DataColumn(label: Text('Edit')),
                ],
                rows: suppliers.map((supplier) {
                  return DataRow(
                    cells: [
                      DataCell(_TwoLineText(title: supplier.name, subtitle: supplier.notes)),
                      DataCell(Text(supplier.contactPerson)),
                      DataCell(Text(supplier.phone)),
                      DataCell(Text(supplier.siteName)),
                      DataCell(Text(supplier.thavvuPointId.isEmpty ? '-' : supplier.thavvuPointId)),
                      DataCell(Text('${supplier.defaultCommissionPercent.toStringAsFixed(2)}%')),
                      DataCell(Text(supplier.paymentDetails.upiId.isEmpty ? '-' : supplier.paymentDetails.upiId)),
                      DataCell(_TwoLineText(
                        title: supplier.paymentDetails.bankName.isEmpty ? '-' : supplier.paymentDetails.bankName,
                        subtitle: supplier.paymentDetails.ifsc.isEmpty ? '' : 'IFSC ${supplier.paymentDetails.ifsc}',
                      )),
                      DataCell(_StatusChip(label: supplier.active ? 'Active' : 'Inactive', color: supplier.active ? AppTheme.success : AppTheme.textMuted)),
                      DataCell(Text(_formatDate(supplier.updatedAt))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit supplier',
                            onPressed: () => _openSupplierSheet(group: group, supplier: supplier),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppTheme.info,
                          ),
                          IconButton(
                            tooltip: 'Delete supplier',
                            onPressed: () => _deleteSupplier(supplier),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppTheme.danger,
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ─── Machine Log Table ──────────────────────────────────────────────

  Widget _buildMachineLogTable(List<MachineWorkLogRecord> logs) {
    return _TableShell(
      title: 'Machine-wise Daily Log + Payment Plan',
      subtitle: 'Net payable = amount earned + beta - diesel - commission. Dual payment tracking.',
      icon: Icons.table_chart_rounded,
      color: AppTheme.info,
      emptyText: 'No machine daily logs available.',
      child: logs.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 66,
                dataRowMaxHeight: 86,
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Start Date')),
                  DataColumn(label: Text('Machine Type')),
                  DataColumn(label: Text('Machine Name')),
                  DataColumn(label: Text('Basis')),
                  DataColumn(label: Text('Mestri')),
                  DataColumn(label: Text('Fare')),
                  DataColumn(label: Text('Work')),
                  DataColumn(label: Text('Earned')),
                  DataColumn(label: Text('Diesel')),
                  DataColumn(label: Text('Beta')),
                  DataColumn(label: Text('Comm %')),
                  DataColumn(label: Text('Comm Amt')),
                  DataColumn(label: Text('Net Payable')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Due Principal')),
                  DataColumn(label: Text('Mach Pay')),
                  DataColumn(label: Text('Comm Pay')),
                  DataColumn(label: Text('Checking')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: logs.map((log) {
                  final supplier = _supplierById(log.supplierId);
                  return DataRow(
                    color: MaterialStateProperty.resolveWith<Color?>((states) {
                      if (log.fullyClosed) return AppTheme.success.withOpacity(0.04);
                      if (log.duePrincipal > 0 || !log.supplierPaymentDone) return AppTheme.warning.withOpacity(0.05);
                      return null;
                    }),
                    cells: [
                      DataCell(Text(_formatDate(log.startDate))),
                      DataCell(Text(log.machineType)),
                      DataCell(Text(log.machineName)),
                      DataCell(Text(log.basisOfFare)),
                      DataCell(Text(supplier?.name ?? log.supplierId)),
                      DataCell(Text(_money(log.fare))),
                      DataCell(Text(log.totalWorkPerformed.toStringAsFixed(2))),
                      DataCell(Text(_money(log.amountEarned))),
                      DataCell(Text(_money(log.dieselUsedAmount))),
                      DataCell(Text(_money(log.betaAmount))),
                      DataCell(Text('${log.commissionPercent.toStringAsFixed(2)}%')),
                      DataCell(Text(_money(log.commissionAmount))),
                      DataCell(Text(_money(log.netPayable), style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(Text(_money(log.amountPaid))),
                      DataCell(Text(_money(log.duePrincipal), style: TextStyle(fontWeight: FontWeight.w900, color: log.duePrincipal > 0 ? AppTheme.warning : AppTheme.success))),
                      DataCell(Checkbox(
                        value: log.machinePaymentDone,
                        activeColor: AppTheme.success,
                        onChanged: (value) => _toggleMachinePaymentDone(log, value ?? false),
                      )),
                      DataCell(Checkbox(
                        value: log.supplierPaymentDone,
                        activeColor: AppTheme.success,
                        onChanged: (value) => _toggleSupplierPaymentDone(log, value ?? false),
                      )),
                      DataCell(Text(log.checkingPurpose)),
                      DataCell(_StatusChip(label: log.status, color: log.fullyClosed ? AppTheme.success : AppTheme.warning)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openRequestPayment(
                              supplier: supplier!,
                              targetType: PaymentTargetType.machineHire,
                              targetId: log.id,
                              targetName: log.machineName,
                              initialAmount: log.duePrincipal,
                            ),
                            icon: const Icon(Icons.request_quote_rounded, size: 16),
                            label: const Text('Machine'),
                          ),
                          TextButton.icon(
                            onPressed: () => _openRequestPayment(
                              supplier: supplier!,
                              targetType: PaymentTargetType.supplierCommission,
                              targetId: log.id,
                              targetName: log.machineName,
                              initialAmount: log.commissionAmount - (log.supplierPaymentDone ? log.commissionAmount : 0),
                            ),
                            icon: const Icon(Icons.percent_rounded, size: 16),
                            label: const Text('Comm'),
                          ),
                          IconButton(
                            onPressed: () => _openMachineLogSheet(log),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppTheme.info,
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ─── Machine Totals Table ───────────────────────────────────────────

  Widget _buildMachineTotalsTable(List<MachineWorkLogRecord> logs) {
    final earned = logs.fold<double>(0, (sum, item) => sum + item.amountEarned);
    final diesel = logs.fold<double>(0, (sum, item) => sum + item.dieselUsedAmount);
    final beta = logs.fold<double>(0, (sum, item) => sum + item.betaAmount);
    final commission = logs.fold<double>(0, (sum, item) => sum + item.commissionAmount);
    final afterCut = logs.fold<double>(0, (sum, item) => sum + item.netPayable);
    final paid = logs.fold<double>(0, (sum, item) => sum + item.amountPaid);
    final due = logs.fold<double>(0, (sum, item) => sum + item.duePrincipal);

    return _TableShell(
      title: 'Machine Totals After Commission Cut',
      subtitle: 'Bottom total table like your uploaded sheet format.',
      icon: Icons.functions_rounded,
      color: AppTheme.success,
      emptyText: 'No totals yet.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Total Machines')),
            DataColumn(label: Text('Amount Earned')),
            DataColumn(label: Text('Diesel Used')),
            DataColumn(label: Text('Beta')),
            DataColumn(label: Text('Commission Cut')),
            DataColumn(label: Text('Final Amount')),
            DataColumn(label: Text('Amount Paid')),
            DataColumn(label: Text('Due / Extra')),
          ],
          rows: [
            DataRow(cells: [
              DataCell(Text('${logs.length}')),
              DataCell(Text(_money(earned))),
              DataCell(Text(_money(diesel))),
              DataCell(Text(_money(beta))),
              DataCell(Text(_money(commission))),
              DataCell(Text(_money(afterCut), style: const TextStyle(fontWeight: FontWeight.w900))),
              DataCell(Text(_money(paid))),
              DataCell(Text(_money(due), style: TextStyle(fontWeight: FontWeight.w900, color: due > 0 ? AppTheme.warning : AppTheme.success))),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Ledger Table ────────────────────────────────────────────────────

  Widget _buildLedgerTable(SupplierGroup group, List<SupplierLedgerRecord> items) {
    return _TableShell(
      title: '${group.shortTitle} Supplier Payment Table',
      subtitle: 'Dual payment tracking: Principal and Commission.',
      icon: Icons.receipt_long_rounded,
      color: group.color,
      emptyText: 'No ${group.shortTitle.toLowerCase()} ledger entries yet.',
      child: items.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 44,
                dataRowMinHeight: 62,
                dataRowMaxHeight: 78,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Earned')),
                  DataColumn(label: Text('Beta')),
                  DataColumn(label: Text('Comm %')),
                  DataColumn(label: Text('Comm Amt')),
                  DataColumn(label: Text('Net Payable')),
                  DataColumn(label: Text('Paid')),
                  DataColumn(label: Text('Due Total')),
                  DataColumn(label: Text('Principal Pay')),
                  DataColumn(label: Text('Comm Pay')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: items.map((item) {
                  final supplier = _supplierById(item.supplierId);
                  return DataRow(
                    cells: [
                      DataCell(Text(_formatDate(item.workDate))),
                      DataCell(Text(supplier?.name ?? item.supplierId)),
                      DataCell(Text(item.title)),
                      DataCell(Text(item.workType)),
                      DataCell(Text('${item.quantity.toStringAsFixed(2)} ${item.unit}')),
                      DataCell(Text(_money(item.rate))),
                      DataCell(Text(_money(item.amountEarned))),
                      DataCell(Text(_money(item.betaAmount))),
                      DataCell(Text('${item.commissionPercent.toStringAsFixed(2)}%')),
                      DataCell(Text(_money(item.commissionAmount))),
                      DataCell(Text(_money(item.netPayable), style: const TextStyle(fontWeight: FontWeight.w900))),
                      DataCell(Text(_money(item.amountPaid))),
                      DataCell(Text(_money(item.totalDue), style: TextStyle(fontWeight: FontWeight.w900, color: item.totalDue > 0 ? AppTheme.warning : AppTheme.success))),
                      DataCell(Checkbox(
                        value: item.principalPaymentDone,
                        activeColor: AppTheme.success,
                        onChanged: (value) => _togglePrincipalPaymentDone(item, value ?? false),
                      )),
                      DataCell(Checkbox(
                        value: item.commissionPaymentDone,
                        activeColor: AppTheme.success,
                        onChanged: (value) => _toggleCommissionPaymentDone(item, value ?? false),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openRequestPayment(
                              supplier: supplier!,
                              targetType: group == SupplierGroup.rental
                                  ? PaymentTargetType.rentalSupplier
                                  : group == SupplierGroup.worker
                                      ? PaymentTargetType.workerSupplier
                                      : PaymentTargetType.otherSupplier,
                              targetId: item.id,
                              targetName: item.title,
                              initialAmount: item.netPayable - (item.principalPaymentDone ? item.netPayable : 0),
                            ),
                            icon: const Icon(Icons.request_quote_rounded, size: 16),
                            label: const Text('Principal'),
                          ),
                          TextButton.icon(
                            onPressed: () => _openRequestPayment(
                              supplier: supplier!,
                              targetType: PaymentTargetType.supplierCommission,
                              targetId: item.id,
                              targetName: item.title,
                              initialAmount: item.commissionAmount - (item.commissionPaymentDone ? item.commissionAmount : 0),
                            ),
                            icon: const Icon(Icons.percent_rounded, size: 16),
                            label: const Text('Comm'),
                          ),
                          IconButton(
                            onPressed: () => _openLedgerSheet(group: group, ledger: item),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppTheme.info,
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ─── Payment Section (common for all groups) ──────────────────────

  Widget _buildPaymentSectionForGroup(SupplierGroup group) {
    final suppliers = _suppliers.where((item) => item.group == group).toList();
    if (suppliers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: const Text('No suppliers in this group. Create one to manage payments.'),
      );
    }

    // For machine group, we show machine logs; for others, ledger items.
    final selectedSupplier = _selectedPaymentSupplierId == null ? null : _supplierById(_selectedPaymentSupplierId!);
    final selectedLogs = selectedSupplier == null
        ? <MachineWorkLogRecord>[]
        : _machineLogs.where((item) => item.supplierId == selectedSupplier.id).toList();
    final selectedLedger = selectedSupplier == null
        ? <SupplierLedgerRecord>[]
        : _ledger.where((item) => item.supplierId == selectedSupplier.id && item.group == group).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _buildSupplierSelectorForPayments(group),
        if (selectedSupplier != null) ...[
          const SizedBox(height: 12),
          _SupplierPaymentInfoCard(supplier: selectedSupplier),
          const SizedBox(height: 12),
          if (group == SupplierGroup.machine)
            _buildPaymentMachineCards(selectedLogs)
          else
            _buildPaymentLedgerCards(selectedLedger),
        ],
        const SizedBox(height: 12),
        _buildRequestPaymentTable(),
      ],
    );
  }

  Widget _buildSupplierSelectorForPayments(SupplierGroup group) {
    final suppliers = _suppliers.where((item) => item.group == group).toList();
    return _TableShell(
      title: 'Select Supplier',
      subtitle: 'Tap a supplier to view related items and request payments.',
      icon: Icons.storefront_rounded,
      color: group.color,
      emptyText: 'No suppliers available.',
      child: suppliers.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 68,
                columns: const [
                  DataColumn(label: Text('Select')),
                  DataColumn(label: Text('Tab')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('UPI')),
                  DataColumn(label: Text('Bank')),
                  DataColumn(label: Text('Pending Items')),
                ],
                rows: suppliers.map((supplier) {
                  final pendingMachines = group == SupplierGroup.machine
                      ? _machineLogs.where((log) =>
                          log.supplierId == supplier.id && (!log.machinePaymentDone || !log.supplierPaymentDone)).length
                      : 0;
                  final pendingLedger = _ledger.where((item) =>
                      item.supplierId == supplier.id && (!item.principalPaymentDone || !item.commissionPaymentDone)).length;
                  final selected = _selectedPaymentSupplierId == supplier.id;
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (_) => setState(() => _selectedPaymentSupplierId = supplier.id),
                    cells: [
                      DataCell(Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppTheme.success : AppTheme.textMuted)),
                      DataCell(_StatusChip(label: supplier.group.shortTitle, color: supplier.group.color)),
                      DataCell(Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(supplier.phone)),
                      DataCell(Text(supplier.paymentDetails.upiId.isEmpty ? '-' : supplier.paymentDetails.upiId)),
                      DataCell(Text(supplier.paymentDetails.bankName.isEmpty ? '-' : supplier.paymentDetails.bankName)),
                      DataCell(Text('${pendingMachines + pendingLedger}')),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPaymentMachineCards(List<MachineWorkLogRecord> logs) {
    return _TableShell(
      title: 'Selected Supplier Machines',
      subtitle: 'Request Machine payment and Commission payment separately.',
      icon: Icons.precision_manufacturing_rounded,
      color: AppTheme.info,
      emptyText: 'No machine logs for selected supplier.',
      child: logs.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 82,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Machine')),
                  DataColumn(label: Text('Worked')),
                  DataColumn(label: Text('Net Payable')),
                  DataColumn(label: Text('Due Principal')),
                  DataColumn(label: Text('Commission')),
                  DataColumn(label: Text('Mach Pay')),
                  DataColumn(label: Text('Comm Pay')),
                  DataColumn(label: Text('Request')),
                ],
                rows: logs.map((log) {
                  final supplier = _supplierById(log.supplierId)!;
                  return DataRow(cells: [
                    DataCell(_TwoLineText(title: log.machineName, subtitle: '${log.machineType} · ${log.basisOfFare}')),
                    DataCell(Text('${log.totalWorkPerformed.toStringAsFixed(2)} ${log.basisOfFare.toLowerCase()}')),
                    DataCell(Text(_money(log.netPayable), style: const TextStyle(fontWeight: FontWeight.w900))),
                    DataCell(Text(_money(log.duePrincipal), style: TextStyle(color: log.duePrincipal > 0 ? AppTheme.warning : AppTheme.success, fontWeight: FontWeight.w900))),
                    DataCell(Text(_money(log.commissionAmount))),
                    DataCell(Checkbox(value: log.machinePaymentDone, onChanged: (value) => _toggleMachinePaymentDone(log, value ?? false), activeColor: AppTheme.success)),
                    DataCell(Checkbox(value: log.supplierPaymentDone, onChanged: (value) => _toggleSupplierPaymentDone(log, value ?? false), activeColor: AppTheme.success)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => _openRequestPayment(
                          supplier: supplier,
                          targetType: PaymentTargetType.machineHire,
                          targetId: log.id,
                          targetName: log.machineName,
                          initialAmount: log.duePrincipal,
                        ),
                        child: const Text('Machine'),
                      ),
                      TextButton(
                        onPressed: () => _openRequestPayment(
                          supplier: supplier,
                          targetType: PaymentTargetType.supplierCommission,
                          targetId: log.id,
                          targetName: log.machineName,
                          initialAmount: log.commissionAmount - (log.supplierPaymentDone ? log.commissionAmount : 0),
                        ),
                        child: const Text('Comm'),
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPaymentLedgerCards(List<SupplierLedgerRecord> items) {
    return _TableShell(
      title: 'Selected Supplier Ledger Items',
      subtitle: 'Request Principal payment and Commission payment separately.',
      icon: Icons.receipt_long_rounded,
      color: AppTheme.warning,
      emptyText: 'No ledger items for selected supplier.',
      child: items.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 82,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Tab')),
                  DataColumn(label: Text('Net Payable')),
                  DataColumn(label: Text('Commission')),
                  DataColumn(label: Text('Principal Pay')),
                  DataColumn(label: Text('Comm Pay')),
                  DataColumn(label: Text('Request')),
                ],
                rows: items.map((item) {
                  final supplier = _supplierById(item.supplierId)!;
                  return DataRow(cells: [
                    DataCell(Text(_formatDate(item.workDate))),
                    DataCell(Text(item.title)),
                    DataCell(Text(item.group.shortTitle)),
                    DataCell(Text(_money(item.netPayable))),
                    DataCell(Text(_money(item.commissionAmount))),
                    DataCell(Checkbox(value: item.principalPaymentDone, onChanged: (value) => _togglePrincipalPaymentDone(item, value ?? false), activeColor: AppTheme.success)),
                    DataCell(Checkbox(value: item.commissionPaymentDone, onChanged: (value) => _toggleCommissionPaymentDone(item, value ?? false), activeColor: AppTheme.success)),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(
                        onPressed: () => _openRequestPayment(
                          supplier: supplier,
                          targetType: item.group == SupplierGroup.rental
                              ? PaymentTargetType.rentalSupplier
                              : item.group == SupplierGroup.worker
                                  ? PaymentTargetType.workerSupplier
                                  : PaymentTargetType.otherSupplier,
                          targetId: item.id,
                          targetName: item.title,
                          initialAmount: item.netPayable - (item.principalPaymentDone ? item.netPayable : 0),
                        ),
                        child: const Text('Principal'),
                      ),
                      TextButton(
                        onPressed: () => _openRequestPayment(
                          supplier: supplier,
                          targetType: PaymentTargetType.supplierCommission,
                          targetId: item.id,
                          targetName: item.title,
                          initialAmount: item.commissionAmount - (item.commissionPaymentDone ? item.commissionAmount : 0),
                        ),
                        child: const Text('Comm'),
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  // ─── Request Payment Table ─────────────────────────────────────────

  Widget _buildRequestPaymentTable() {
    return _TableShell(
      title: 'Request Payment Table',
      subtitle: 'Payment proof and book registration unlock after finance completes the request.',
      icon: Icons.request_quote_outlined,
      color: AppTheme.success,
      emptyText: 'No payment requests generated yet.',
      child: _payments.isEmpty
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 66,
                dataRowMaxHeight: 84,
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Request ID')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Target')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Proof')),
                  DataColumn(label: Text('Book')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _payments.map((request) {
                  final completed = request.status == PaymentStatus.completed;
                  return DataRow(cells: [
                    DataCell(Text(request.id, style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(_formatCompactDateTime(request.requestedAt))),
                    DataCell(Text(request.supplierName)),
                    DataCell(Text(request.targetType.label)),
                    DataCell(Text(request.targetName)),
                    DataCell(Text(_money(request.amount), style: const TextStyle(fontWeight: FontWeight.w900))),
                    DataCell(Text(request.mode.label)),
                    DataCell(_StatusChip(label: request.status.label, color: request.status.color)),
                    DataCell(completed ? _ProofPill(text: request.paymentProof) : const Text('Locked', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                    DataCell(completed ? Text(request.registeredInBook ? 'Yes' : 'No') : const Text('Locked', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      if (request.status == PaymentStatus.requested)
                        TextButton.icon(
                          onPressed: () => _markPaymentStatus(request, PaymentStatus.completed),
                          icon: const Icon(Icons.verified_rounded, size: 16),
                          label: const Text('Complete'),
                        ),
                      if (request.status == PaymentStatus.requested)
                        TextButton.icon(
                          onPressed: () => _markPaymentStatus(request, PaymentStatus.rejected),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Reject'),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                        ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  // ─── History Tab ────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final query = _historySearch.trim().toLowerCase();
    final filtered = _history.where((item) {
      final moduleMatches = _historyModuleFilter == 'All' || item.module == _historyModuleFilter;
      final queryMatches = query.isEmpty ||
          item.supplierName.toLowerCase().contains(query) ||
          item.action.toLowerCase().contains(query) ||
          item.target.toLowerCase().contains(query) ||
          item.status.toLowerCase().contains(query) ||
          item.notes.toLowerCase().contains(query);
      return moduleMatches && queryMatches;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _ModuleHeaderCard(
          title: 'History',
          subtitle: 'All supplier creations, edits, daily logs, payment requests, tick changes and completed payments are tracked here.',
          icon: Icons.history_rounded,
          color: AppTheme.info,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              TextField(
                controller: _historySearchController,
                onChanged: (value) => setState(() => _historySearch = value),
                decoration: InputDecoration(
                  hintText: 'Search history by supplier, action, target, status',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _historySearch.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _historySearchController.clear();
                            setState(() => _historySearch = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Mach', 'Rent', 'Work', 'Other', 'Pay']
                      .map((filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _historyModuleFilter == filter,
                              onSelected: (_) => setState(() => _historyModuleFilter = filter),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _TableShell(
          title: 'Complete History Table',
          subtitle: 'Includes dates and all data from supplier tabs and payments.',
          icon: Icons.manage_search_rounded,
          color: AppTheme.info,
          emptyText: 'No history matched your filters.',
          child: filtered.isEmpty
              ? null
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 46,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 74,
                    columnSpacing: 18,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Tab')),
                      DataColumn(label: Text('Supplier')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Target')),
                      DataColumn(label: Text('Amount')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Notes')),
                    ],
                    rows: filtered.map((item) => DataRow(cells: [
                          DataCell(Text(_formatDate(item.date))),
                          DataCell(Text(_formatTime(item.date))),
                          DataCell(Text(item.module)),
                          DataCell(Text(item.supplierName)),
                          DataCell(Text(item.action)),
                          DataCell(Text(item.target)),
                          DataCell(Text(item.amount == 0 ? '-' : _money(item.amount))),
                          DataCell(Text(item.status)),
                          DataCell(Text(item.notes)),
                        ])).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration({Color? color}) {
    return BoxDecoration(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: (color ?? AppTheme.borderLight).withOpacity(color == null ? 1 : 0.20)),
      boxShadow: AppTheme.subtleShadow,
    );
  }
}

// ─── Supplier Edit Sheet ────────────────────────────────────────────────

class _SupplierEditSheet extends StatefulWidget {
  final SupplierGroup group;
  final HodSupplierRecord? supplier;
  final String Function() newId;

  const _SupplierEditSheet({
    required this.group,
    required this.supplier,
    required this.newId,
  });

  @override
  State<_SupplierEditSheet> createState() => _SupplierEditSheetState();
}

class _SupplierEditSheetState extends State<_SupplierEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _site;
  late final TextEditingController _siteId;
  late final TextEditingController _point;
  late final TextEditingController _commission;
  late final TextEditingController _upi;
  late final TextEditingController _holder;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _ifsc;
  late final TextEditingController _paymentNote;
  late final TextEditingController _notes;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    final payment = supplier?.paymentDetails ?? const SupplierPaymentDetails();
    _name = TextEditingController(text: supplier?.name ?? '');
    _contact = TextEditingController(text: supplier?.contactPerson ?? '');
    _phone = TextEditingController(text: supplier?.phone ?? '');
    _address = TextEditingController(text: supplier?.address ?? '');
    _site = TextEditingController(text: supplier?.siteName ?? 'Site A');
    _siteId = TextEditingController(text: supplier?.siteId ?? 'SITE-001');
    _point = TextEditingController(text: supplier?.thavvuPointId ?? 'TP-001');
    _commission = TextEditingController(text: (supplier?.defaultCommissionPercent ?? 0).toString());
    _upi = TextEditingController(text: payment.upiId);
    _holder = TextEditingController(text: payment.accountHolder);
    _bank = TextEditingController(text: payment.bankName);
    _account = TextEditingController(text: payment.accountNumber);
    _ifsc = TextEditingController(text: payment.ifsc);
    _paymentNote = TextEditingController(text: payment.paymentNote);
    _notes = TextEditingController(text: supplier?.notes ?? '');
    _active = supplier?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _address.dispose();
    _site.dispose();
    _siteId.dispose();
    _point.dispose();
    _commission.dispose();
    _upi.dispose();
    _holder.dispose();
    _bank.dispose();
    _account.dispose();
    _ifsc.dispose();
    _paymentNote.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.supplier;
    Navigator.pop(
      context,
      HodSupplierRecord(
        id: existing?.id ?? widget.newId(),
        group: widget.group,
        name: _name.text.trim(),
        contactPerson: _contact.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        siteName: _site.text.trim(),
        siteId: _siteId.text.trim(),
        thavvuPointId: _point.text.trim(),
        defaultCommissionPercent: _toDouble(_commission.text),
        paymentDetails: SupplierPaymentDetails(
          upiId: _upi.text.trim(),
          accountHolder: _holder.text.trim(),
          bankName: _bank.text.trim(),
          accountNumber: _account.text.trim(),
          ifsc: _ifsc.text.trim().toUpperCase(),
          paymentNote: _paymentNote.text.trim(),
        ),
        notes: _notes.text.trim(),
        active: _active,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: widget.supplier == null ? 'Create ${widget.group.title}' : 'Edit ${widget.group.title}',
      icon: widget.group.icon,
      color: widget.group.color,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _FormField(label: 'Supplier / Mestri Name', icon: Icons.storefront_rounded, controller: _name, requiredField: true),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FormField(label: 'Contact Person', icon: Icons.person_rounded, controller: _contact)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'Phone', icon: Icons.call_rounded, controller: _phone, keyboardType: TextInputType.phone, requiredField: true)),
            ]),
            const SizedBox(height: 10),
            _FormField(label: 'Address', icon: Icons.location_on_outlined, controller: _address, maxLines: 2),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FormField(label: 'Site Name', icon: Icons.apartment_rounded, controller: _site)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'Site ID', icon: Icons.pin_drop_rounded, controller: _siteId)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FormField(label: 'Thavvu Point ID', icon: Icons.account_tree_rounded, controller: _point)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'Default Commission %', icon: Icons.percent_rounded, controller: _commission, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            _FormSectionTitle(title: 'Payment Details', icon: Icons.payment_rounded),
            const SizedBox(height: 10),
            _FormField(label: 'UPI ID', icon: Icons.qr_code_rounded, controller: _upi),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FormField(label: 'Account Holder', icon: Icons.person_pin_rounded, controller: _holder)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'Bank Name', icon: Icons.account_balance_rounded, controller: _bank)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _FormField(label: 'Account Number', icon: Icons.numbers_rounded, controller: _account, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'IFSC', icon: Icons.code_rounded, controller: _ifsc)),
            ]),
            const SizedBox(height: 10),
            _FormField(label: 'Payment Notes', icon: Icons.notes_rounded, controller: _paymentNote, maxLines: 2),
            const SizedBox(height: 10),
            _FormField(label: 'General Notes', icon: Icons.description_rounded, controller: _notes, maxLines: 2),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _active,
              activeColor: AppTheme.success,
              contentPadding: EdgeInsets.zero,
              title: const Text('Active supplier', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Inactive suppliers remain in history but are not preferred for new entries.'),
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Supplier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Machine Log Edit Sheet ─────────────────────────────────────────────

class _MachineLogEditSheet extends StatefulWidget {
  final MachineWorkLogRecord? log;
  final List<HodSupplierRecord> suppliers;
  final String Function() newId;

  const _MachineLogEditSheet({
    required this.log,
    required this.suppliers,
    required this.newId,
  });

  @override
  State<_MachineLogEditSheet> createState() => _MachineLogEditSheetState();
}

class _MachineLogEditSheetState extends State<_MachineLogEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _supplierId;
  late final TextEditingController _machineType;
  late final TextEditingController _machineName;
  late final TextEditingController _basis;
  late final TextEditingController _fare;
  late final TextEditingController _work;
  late final TextEditingController _diesel;
  late final TextEditingController _beta;
  late final TextEditingController _commission;
  late final TextEditingController _paid;
  late final TextEditingController _checking;
  late final TextEditingController _remarks;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _machinePaymentDone = false;
  bool _supplierPaymentDone = false;

  @override
  void initState() {
    super.initState();
    final log = widget.log;
    _supplierId = log?.supplierId ?? widget.suppliers.first.id;
    _machineType = TextEditingController(text: log?.machineType ?? 'Tractor');
    _machineName = TextEditingController(text: log?.machineName ?? '');
    _basis = TextEditingController(text: log?.basisOfFare ?? 'Day');
    _fare = TextEditingController(text: (log?.fare ?? 0).toString());
    _work = TextEditingController(text: (log?.totalWorkPerformed ?? 0).toString());
    _diesel = TextEditingController(text: (log?.dieselUsedAmount ?? 0).toString());
    _beta = TextEditingController(text: (log?.betaAmount ?? 0).toString());
    _commission = TextEditingController(text: (log?.commissionPercent ?? widget.suppliers.first.defaultCommissionPercent).toString());
    _paid = TextEditingController(text: (log?.amountPaid ?? 0).toString());
    _checking = TextEditingController(text: log?.checkingPurpose ?? '');
    _remarks = TextEditingController(text: log?.remarks ?? '');
    _startDate = log?.startDate ?? DateTime.now();
    _endDate = log?.endDate;
    _machinePaymentDone = log?.machinePaymentDone ?? false;
    _supplierPaymentDone = log?.supplierPaymentDone ?? false;
  }

  @override
  void dispose() {
    _machineType.dispose();
    _machineName.dispose();
    _basis.dispose();
    _fare.dispose();
    _work.dispose();
    _diesel.dispose();
    _beta.dispose();
    _commission.dispose();
    _paid.dispose();
    _checking.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_endDate ?? _startDate) : _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endDate = picked;
      } else {
        _startDate = picked;
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final record = MachineWorkLogRecord(
      id: widget.log?.id ?? widget.newId(),
      supplierId: _supplierId,
      machineType: _machineType.text.trim(),
      machineName: _machineName.text.trim(),
      basisOfFare: _basis.text.trim(),
      fare: _toDouble(_fare.text),
      totalWorkPerformed: _toDouble(_work.text),
      dieselUsedAmount: _toDouble(_diesel.text),
      betaAmount: _toDouble(_beta.text),
      commissionPercent: _toDouble(_commission.text),
      amountPaid: _toDouble(_paid.text),
      startDate: _startDate,
      endDate: _endDate,
      checkingPurpose: _checking.text.trim(),
      machinePaymentDone: _machinePaymentDone,
      supplierPaymentDone: _supplierPaymentDone,
      remarks: _remarks.text.trim(),
    );
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: widget.log == null ? 'Add Machine Daily Log' : 'Edit Machine Daily Log',
      icon: Icons.precision_manufacturing_rounded,
      color: AppTheme.info,
      child: Form(
        key: _formKey,
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _supplierId,
            decoration: _inputDecoration('Supplier / Mestri', Icons.storefront_rounded),
            items: widget.suppliers
                .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              final selected = widget.suppliers.firstWhere((item) => item.id == value);
              setState(() {
                _supplierId = value;
                _commission.text = selected.defaultCommissionPercent.toString();
              });
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Machine Type', icon: Icons.category_rounded, controller: _machineType, requiredField: true)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Machine Name', icon: Icons.precision_manufacturing_rounded, controller: _machineName, requiredField: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Basis of Fare', icon: Icons.schedule_rounded, controller: _basis, requiredField: true)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Fare (₹)', icon: Icons.currency_rupee_rounded, controller: _fare, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Total Work', icon: Icons.functions_rounded, controller: _work, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Diesel Used (₹)', icon: Icons.local_gas_station_rounded, controller: _diesel, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Beta Amount (₹)', icon: Icons.add_card_rounded, controller: _beta, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Commission %', icon: Icons.percent_rounded, controller: _commission, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          _FormField(label: 'Amount Paid (₹)', icon: Icons.payments_rounded, controller: _paid, keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _DateButton(label: 'Start Date', value: _formatDate(_startDate), color: AppTheme.info, onTap: () => _pickDate(end: false))),
            const SizedBox(width: 10),
            Expanded(child: _DateButton(label: 'End Date', value: _endDate == null ? 'Not closed' : _formatDate(_endDate!), color: AppTheme.warning, onTap: () => _pickDate(end: true))),
          ]),
          const SizedBox(height: 10),
          _FormField(label: 'Checking Purpose', icon: Icons.fact_check_rounded, controller: _checking),
          const SizedBox(height: 10),
          _FormField(label: 'Remarks', icon: Icons.notes_rounded, controller: _remarks, maxLines: 2),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _machinePaymentDone,
            title: const Text('Machine payment done'),
            onChanged: (value) => setState(() => _machinePaymentDone = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _supplierPaymentDone,
            title: const Text('Supplier commission/payment done'),
            onChanged: (value) => setState(() => _supplierPaymentDone = value ?? false),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save Machine Log'))),
        ]),
      ),
    );
  }
}

// ─── Ledger Edit Sheet ──────────────────────────────────────────────────

class _LedgerEditSheet extends StatefulWidget {
  final SupplierGroup group;
  final SupplierLedgerRecord? ledger;
  final List<HodSupplierRecord> suppliers;
  final String Function() newId;

  const _LedgerEditSheet({
    required this.group,
    required this.ledger,
    required this.suppliers,
    required this.newId,
  });

  @override
  State<_LedgerEditSheet> createState() => _LedgerEditSheetState();
}

class _LedgerEditSheetState extends State<_LedgerEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _supplierId;
  late final TextEditingController _title;
  late final TextEditingController _workType;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _rate;
  late final TextEditingController _commission;
  late final TextEditingController _beta;
  late final TextEditingController _paid;
  late final TextEditingController _remarks;
  DateTime _workDate = DateTime.now();
  bool _principalPaymentDone = false;
  bool _commissionPaymentDone = false;

  @override
  void initState() {
    super.initState();
    final ledger = widget.ledger;
    _supplierId = ledger?.supplierId ?? widget.suppliers.first.id;
    _title = TextEditingController(text: ledger?.title ?? '');
    _workType = TextEditingController(text: ledger?.workType ?? 'Bill');
    _quantity = TextEditingController(text: (ledger?.quantity ?? 0).toString());
    _unit = TextEditingController(text: ledger?.unit ?? 'unit');
    _rate = TextEditingController(text: (ledger?.rate ?? 0).toString());
    _commission = TextEditingController(text: (ledger?.commissionPercent ?? widget.suppliers.first.defaultCommissionPercent).toString());
    _beta = TextEditingController(text: (ledger?.betaAmount ?? 0).toString());
    _paid = TextEditingController(text: (ledger?.amountPaid ?? 0).toString());
    _remarks = TextEditingController(text: ledger?.remarks ?? '');
    _workDate = ledger?.workDate ?? DateTime.now();
    _principalPaymentDone = ledger?.principalPaymentDone ?? false;
    _commissionPaymentDone = ledger?.commissionPaymentDone ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _workType.dispose();
    _quantity.dispose();
    _unit.dispose();
    _rate.dispose();
    _commission.dispose();
    _beta.dispose();
    _paid.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() => _workDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      SupplierLedgerRecord(
        id: widget.ledger?.id ?? widget.newId(),
        group: widget.group,
        supplierId: _supplierId,
        title: _title.text.trim(),
        workType: _workType.text.trim(),
        quantity: _toDouble(_quantity.text),
        unit: _unit.text.trim(),
        rate: _toDouble(_rate.text),
        commissionPercent: _toDouble(_commission.text),
        betaAmount: _toDouble(_beta.text),
        amountPaid: _toDouble(_paid.text),
        workDate: _workDate,
        remarks: _remarks.text.trim(),
        principalPaymentDone: _principalPaymentDone,
        commissionPaymentDone: _commissionPaymentDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: widget.ledger == null ? 'Add ${widget.group.shortTitle} Ledger' : 'Edit ${widget.group.shortTitle} Ledger',
      icon: widget.group.icon,
      color: widget.group.color,
      child: Form(
        key: _formKey,
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _supplierId,
            decoration: _inputDecoration('Supplier', Icons.storefront_rounded),
            items: widget.suppliers.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
            onChanged: (value) {
              if (value == null) return;
              final selected = widget.suppliers.firstWhere((item) => item.id == value);
              setState(() {
                _supplierId = value;
                _commission.text = selected.defaultCommissionPercent.toString();
              });
            },
          ),
          const SizedBox(height: 10),
          _FormField(label: 'Entry Title', icon: Icons.title_rounded, controller: _title, requiredField: true),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Work Type', icon: Icons.work_rounded, controller: _workType)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Date', icon: Icons.calendar_month_rounded, controller: TextEditingController(text: _formatDate(_workDate)), readOnly: true, onTap: _pickDate)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Quantity', icon: Icons.functions_rounded, controller: _quantity, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Unit', icon: Icons.straighten_rounded, controller: _unit)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Rate (₹)', icon: Icons.currency_rupee_rounded, controller: _rate, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Commission %', icon: Icons.percent_rounded, controller: _commission, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FormField(label: 'Beta (₹)', icon: Icons.add_card_rounded, controller: _beta, keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _FormField(label: 'Paid (₹)', icon: Icons.payments_rounded, controller: _paid, keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          _FormField(label: 'Remarks', icon: Icons.notes_rounded, controller: _remarks, maxLines: 2),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _principalPaymentDone,
            activeColor: AppTheme.success,
            title: const Text('Principal payment done'),
            onChanged: (value) => setState(() => _principalPaymentDone = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _commissionPaymentDone,
            activeColor: AppTheme.success,
            title: const Text('Commission payment done'),
            onChanged: (value) => setState(() => _commissionPaymentDone = value ?? false),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save Entry'))),
        ]),
      ),
    );
  }
}

// ─── Request Payment Sheet (Reusable) ──────────────────────────────────

class _RequestPaymentSheet extends StatefulWidget {
  final String Function() newId;
  final HodSupplierRecord supplier;
  final PaymentTargetType targetType;
  final String targetId;
  final String targetName;
  final double initialAmount;

  const _RequestPaymentSheet({
    required this.newId,
    required this.supplier,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.initialAmount,
  });

  @override
  State<_RequestPaymentSheet> createState() => _RequestPaymentSheetState();
}

class _RequestPaymentSheetState extends State<_RequestPaymentSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _upi;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _ifsc;
  late final TextEditingController _notes;
  PaymentMode _mode = PaymentMode.upi;
  String? _entryMethod;

  @override
  void initState() {
    super.initState();
    final details = widget.supplier.paymentDetails;
    _amount = TextEditingController(text: widget.initialAmount.toStringAsFixed(0));
    _upi = TextEditingController(text: details.upiId);
    _bank = TextEditingController(text: details.bankName);
    _account = TextEditingController(text: details.accountNumber);
    _ifsc = TextEditingController(text: details.ifsc);
    _notes = TextEditingController(text: details.paymentNote);
  }

  @override
  void dispose() {
    _amount.dispose();
    _upi.dispose();
    _bank.dispose();
    _account.dispose();
    _ifsc.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = _toDouble(_amount.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid request amount.')),
      );
      return;
    }
    if (_mode == PaymentMode.upi && _upi.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or select UPI ID.')),
      );
      return;
    }
    if (_mode == PaymentMode.bank && _entryMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select bank details entry method.')),
      );
      return;
    }

    Navigator.pop(
      context,
      SupplierPaymentRequestRecord(
        id: widget.newId(),
        supplierId: widget.supplier.id,
        supplierName: widget.supplier.name,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetName: widget.targetName,
        amount: amount,
        mode: _mode,
        upiId: _upi.text.trim(),
        bankName: _bank.text.trim(),
        accountNumber: _account.text.trim(),
        ifsc: _ifsc.text.trim().toUpperCase(),
        entryMethod: _mode == PaymentMode.upi ? 'upi_saved' : (_entryMethod ?? ''),
        status: PaymentStatus.requested,
        paymentProof: '',
        registeredInBook: false,
        requestedAt: DateTime.now(),
        completedAt: null,
        requestedBy: 'HOD-001',
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: 'Request Payment',
      icon: Icons.request_quote_rounded,
      color: AppTheme.success,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.success.withOpacity(0.20)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.supplier.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${widget.targetType.label} · ${widget.targetName}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),
        ),
        const SizedBox(height: 12),
        _FormField(label: 'Request Amount (₹)', icon: Icons.currency_rupee_rounded, controller: _amount, keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        const Text('Payment Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _PaymentModeTile(label: 'UPI', icon: Icons.qr_code_rounded, color: AppTheme.success, selected: _mode == PaymentMode.upi, onTap: () => setState(() => _mode = PaymentMode.upi))),
          const SizedBox(width: 10),
          Expanded(child: _PaymentModeTile(label: 'Bank Transfer', icon: Icons.account_balance_rounded, color: AppTheme.info, selected: _mode == PaymentMode.bank, onTap: () => setState(() => _mode = PaymentMode.bank))),
        ]),
        const SizedBox(height: 12),
        if (_mode == PaymentMode.upi) ...[
          const Text('Verified UPI Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          _SelectableAccountTile(
            selected: true,
            icon: Icons.account_balance_wallet_rounded,
            title: _upi.text.trim().isEmpty ? 'Add UPI ID' : _upi.text.trim(),
            subtitle: widget.supplier.paymentDetails.bankName.isEmpty ? 'Supplier saved UPI' : widget.supplier.paymentDetails.bankName,
            color: AppTheme.success,
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _FormField(label: 'Edit / Add UPI ID', icon: Icons.qr_code_rounded, controller: _upi),
        ],
        if (_mode == PaymentMode.bank) ...[
          if (widget.supplier.paymentDetails.bankName.isNotEmpty) ...[
            const Text('Saved Bank Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            _SelectableAccountTile(
              selected: true,
              icon: Icons.account_balance_rounded,
              title: widget.supplier.paymentDetails.bankName,
              subtitle: 'A/C ${widget.supplier.paymentDetails.accountNumber} · IFSC ${widget.supplier.paymentDetails.ifsc}',
              color: AppTheme.info,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            const Divider(),
          ],
          const Text('Select Entry Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _EntryMethodTile(method: 'manual', title: 'Manual', icon: Icons.edit_outlined, selected: _entryMethod == 'manual', onTap: () => setState(() => _entryMethod = 'manual'))),
            const SizedBox(width: 8),
            Expanded(child: _EntryMethodTile(method: 'photo', title: 'Photo', icon: Icons.camera_alt_outlined, selected: _entryMethod == 'photo', onTap: () => setState(() => _entryMethod = 'photo'))),
            const SizedBox(width: 8),
            Expanded(child: _EntryMethodTile(method: 'voice', title: 'Voice', icon: Icons.mic_none_rounded, selected: _entryMethod == 'voice', onTap: () => setState(() => _entryMethod = 'voice'))),
          ]),
          const SizedBox(height: 12),
          if (_entryMethod == 'manual') ...[
            _FormField(label: 'Bank Name', icon: Icons.account_balance_rounded, controller: _bank),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _FormField(label: 'Account Number', icon: Icons.numbers_rounded, controller: _account, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _FormField(label: 'IFSC', icon: Icons.code_rounded, controller: _ifsc)),
            ]),
          ] else if (_entryMethod == 'photo')
            _InfoBox(icon: Icons.camera_alt_rounded, text: 'Upload bank screenshot option selected. Connect file picker here.')
          else if (_entryMethod == 'voice')
            _InfoBox(icon: Icons.mic_rounded, text: 'Voice bank details option selected. Connect voice recorder here.'),
        ],
        const SizedBox(height: 10),
        _FormField(label: 'Request Notes', icon: Icons.notes_rounded, controller: _notes, maxLines: 2),
        const SizedBox(height: 10),
        const _InfoBox(icon: Icons.info_outline_rounded, text: 'Request will be sent to finance. Payment proof and book registration stay locked until finance marks it completed.'),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.send_rounded), label: const Text('Submit Request'))),
      ]),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────

class _BottomSheetShell extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _BottomSheetShell({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 20),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.90), color.withOpacity(0.68)]),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModuleHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ModuleHeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.95), color.withOpacity(0.72)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.30)),
          ]),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withOpacity(0.16)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionRow({
    required this.title,
    required this.actionLabel,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
      ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(actionLabel)),
    ]);
  }
}

class _TableShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String emptyText;
  final Widget? child;

  const _TableShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 12),
        if (child == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(emptyText, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          )
        else
          child!,
      ]),
    );
  }
}

class _TwoLineText extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TwoLineText({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

class _SupplierPaymentInfoCard extends StatelessWidget {
  final HodSupplierRecord supplier;

  const _SupplierPaymentInfoCard({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: supplier.group.color.withOpacity(0.16)),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: supplier.group.color.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
          child: Icon(supplier.group.icon, color: supplier.group.color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 3),
          Text('${supplier.group.title} · ${supplier.phone}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 3),
          Text('UPI: ${supplier.paymentDetails.upiId.isEmpty ? '-' : supplier.paymentDetails.upiId}  ·  Bank: ${supplier.paymentDetails.bankName.isEmpty ? '-' : supplier.paymentDetails.bankName}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _ProofPill extends StatelessWidget {
  final String text;

  const _ProofPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.image_outlined, size: 16, color: AppTheme.success),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _PaymentModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentModeTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : AppTheme.textMuted, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? color : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

class _EntryMethodTile extends StatelessWidget {
  final String method;
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EntryMethodTile({
    required this.method,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.success.withOpacity(0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.success : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 22, color: selected ? AppTheme.success : AppTheme.textSecondary),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? AppTheme.success : AppTheme.textSecondary)),
        ]),
      ),
    );
  }
}

class _SelectableAccountTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SelectableAccountTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.10) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle : icon, color: selected ? color : AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? color : AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ]),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.info.withOpacity(0.20)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.info),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.info, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _FormSectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppTheme.info, size: 18),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
    ]);
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_month_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ])),
        ]),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool requiredField;
  final bool readOnly;
  final VoidCallback? onTap;

  const _FormField({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.requiredField = false,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: requiredField
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
      decoration: _inputDecoration(label, icon),
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18),
    filled: true,
    fillColor: AppTheme.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

double _toDouble(String value) {
  return double.tryParse(value.trim().replaceAll(',', '')) ?? 0;
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  return '$sign₹${abs.toStringAsFixed(2)}';
}

String _moneyShort(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 10000000) return '$sign₹${(abs / 10000000).toStringAsFixed(2)}Cr';
  if (abs >= 100000) return '$sign₹${(abs / 100000).toStringAsFixed(2)}L';
  if (abs >= 1000) return '$sign₹${(abs / 1000).toStringAsFixed(1)}K';
  return '$sign₹${abs.toStringAsFixed(0)}';
}

String _formatDate(DateTime value) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatCompactDateTime(DateTime value) {
  return '${_formatDate(value)} · ${_formatTime(value)}';
}