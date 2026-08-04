import 'package:flutter/foundation.dart';

enum HodSupplierType { all, permanent, temporary }

enum HodMachinePaymentKind { cash, advance }

enum HodMachinePaymentStatus {
  draft,
  hodApproved,
  submittedToFinance,
  financeCompleted,
  rejected,
}

enum HodMachineEntryStatus {
  draft,
  submitted,
  pendingFinance,
  completed,
}

String hodSupplierTypeLabel(HodSupplierType type) {
  switch (type) {
    case HodSupplierType.all:
      return 'All';
    case HodSupplierType.permanent:
      return 'Permanent';
    case HodSupplierType.temporary:
      return 'Temporary';
  }
}

String hodMachinePaymentKindLabel(HodMachinePaymentKind kind) {
  switch (kind) {
    case HodMachinePaymentKind.cash:
      return 'Cash Payment';
    case HodMachinePaymentKind.advance:
      return 'Advance Request';
  }
}

String hodMachinePaymentStatusLabel(HodMachinePaymentStatus status) {
  switch (status) {
    case HodMachinePaymentStatus.draft:
      return 'Pending HOD Approval';
    case HodMachinePaymentStatus.hodApproved:
      return 'HOD Approved';
    case HodMachinePaymentStatus.submittedToFinance:
      return 'Submitted to Finance';
    case HodMachinePaymentStatus.financeCompleted:
      return 'Finance Completed';
    case HodMachinePaymentStatus.rejected:
      return 'Rejected';
  }
}

String hodMachineEntryStatusLabel(HodMachineEntryStatus status) {
  switch (status) {
    case HodMachineEntryStatus.draft:
      return 'Draft';
    case HodMachineEntryStatus.submitted:
      return 'Submitted';
    case HodMachineEntryStatus.pendingFinance:
      return 'Pending Finance';
    case HodMachineEntryStatus.completed:
      return 'Completed';
  }
}

@immutable
class HodMachineSupplier {
  final String id;
  final String name;
  final HodSupplierType type;
  final DateTime? validUntil;
  final double rating;
  final String phone;
  final String notes;
  final bool isActive;

  const HodMachineSupplier({
    required this.id,
    required this.name,
    required this.type,
    this.validUntil,
    this.rating = 0,
    this.phone = '',
    this.notes = '',
    this.isActive = true,
  });

  bool get isTemporary => type == HodSupplierType.temporary;

  HodMachineSupplier copyWith({
    String? id,
    String? name,
    HodSupplierType? type,
    DateTime? validUntil,
    double? rating,
    String? phone,
    String? notes,
    bool? isActive,
  }) {
    return HodMachineSupplier(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      validUntil: validUntil ?? this.validUntil,
      rating: rating ?? this.rating,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class HodMachineCatalogItem {
  final String id;
  final String siteId;
  final String machineName;
  final String vehicleNumber;
  final String vehicleType;
  final String operatorName;
  final String operatorPhone;
  final String createdByHodId;
  final DateTime createdAt;
  final bool isActive;

  const HodMachineCatalogItem({
    required this.id,
    required this.siteId,
    required this.machineName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.operatorName,
    this.operatorPhone = '',
    this.createdByHodId = '',
    required this.createdAt,
    this.isActive = true,
  });

  HodMachineCatalogItem copyWith({
    String? id,
    String? siteId,
    String? machineName,
    String? vehicleNumber,
    String? vehicleType,
    String? operatorName,
    String? operatorPhone,
    String? createdByHodId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return HodMachineCatalogItem(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      machineName: machineName ?? this.machineName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operatorName: operatorName ?? this.operatorName,
      operatorPhone: operatorPhone ?? this.operatorPhone,
      createdByHodId: createdByHodId ?? this.createdByHodId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

@immutable
class HodMachinePaymentTransaction {
  final String id;
  final HodMachinePaymentKind kind;
  final double amount;
  final DateTime createdAt;
  final HodMachinePaymentStatus status;
  final String paymentMode;
  final String entryMethod;
  final String accountLabel;
  final String notes;
  final String? paymentProofPath;
  final bool registeredInMachineIdsBook;
  final DateTime? hodApprovedAt;
  final DateTime? submittedToFinanceAt;
  final DateTime? financeCompletedAt;
  final String? financeRequestId;

  const HodMachinePaymentTransaction({
    required this.id,
    required this.kind,
    required this.amount,
    required this.createdAt,
    this.status = HodMachinePaymentStatus.draft,
    this.paymentMode = '-',
    this.entryMethod = '-',
    this.accountLabel = '-',
    this.notes = '',
    this.paymentProofPath,
    this.registeredInMachineIdsBook = false,
    this.hodApprovedAt,
    this.submittedToFinanceAt,
    this.financeCompletedAt,
    this.financeRequestId,
  });

  bool get isAdvance => kind == HodMachinePaymentKind.advance;
  bool get isCash => kind == HodMachinePaymentKind.cash;
  bool get isFinanceLocked =>
      status == HodMachinePaymentStatus.submittedToFinance ||
      status == HodMachinePaymentStatus.financeCompleted;
  bool get isCompleted => status == HodMachinePaymentStatus.financeCompleted;

  HodMachinePaymentTransaction copyWith({
    String? id,
    HodMachinePaymentKind? kind,
    double? amount,
    DateTime? createdAt,
    HodMachinePaymentStatus? status,
    String? paymentMode,
    String? entryMethod,
    String? accountLabel,
    String? notes,
    String? paymentProofPath,
    bool? registeredInMachineIdsBook,
    DateTime? hodApprovedAt,
    DateTime? submittedToFinanceAt,
    DateTime? financeCompletedAt,
    String? financeRequestId,
  }) {
    return HodMachinePaymentTransaction(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paymentMode: paymentMode ?? this.paymentMode,
      entryMethod: entryMethod ?? this.entryMethod,
      accountLabel: accountLabel ?? this.accountLabel,
      notes: notes ?? this.notes,
      paymentProofPath: paymentProofPath ?? this.paymentProofPath,
      registeredInMachineIdsBook:
          registeredInMachineIdsBook ?? this.registeredInMachineIdsBook,
      hodApprovedAt: hodApprovedAt ?? this.hodApprovedAt,
      submittedToFinanceAt: submittedToFinanceAt ?? this.submittedToFinanceAt,
      financeCompletedAt: financeCompletedAt ?? this.financeCompletedAt,
      financeRequestId: financeRequestId ?? this.financeRequestId,
    );
  }
}

@immutable
class HodMachineFinanceRequest {
  final String id;
  final String siteId;
  final String hodId;
  final String machineEntryId;
  final String paymentTransactionId;
  final String module;
  final String title;
  final double amount;
  final String paymentMode;
  final String accountLabel;
  final String status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? proofPath;

  const HodMachineFinanceRequest({
    required this.id,
    required this.siteId,
    required this.hodId,
    required this.machineEntryId,
    required this.paymentTransactionId,
    this.module = 'Machines',
    required this.title,
    required this.amount,
    required this.paymentMode,
    required this.accountLabel,
    this.status = 'Submitted to Finance',
    required this.createdAt,
    this.completedAt,
    this.proofPath,
  });

  HodMachineFinanceRequest copyWith({
    String? id,
    String? siteId,
    String? hodId,
    String? machineEntryId,
    String? paymentTransactionId,
    String? module,
    String? title,
    double? amount,
    String? paymentMode,
    String? accountLabel,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? proofPath,
  }) {
    return HodMachineFinanceRequest(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      hodId: hodId ?? this.hodId,
      machineEntryId: machineEntryId ?? this.machineEntryId,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      module: module ?? this.module,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      accountLabel: accountLabel ?? this.accountLabel,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      proofPath: proofPath ?? this.proofPath,
    );
  }
}

@immutable
class HodMachineEntryRecord {
  final String id;
  final String siteId;
  final String hodId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final HodMachineCatalogItem machine;
  final HodMachineSupplier supplier;
  final String billingType;
  final String dieselInclusion;
  final String fuelType;
  final String stockPoint;
  final double fuelLiters;
  final double fareAmount;
  final String commissionAgent;
  final double commissionAmount;
  final double betaEligibleHours;
  final double regularBetaAmount;
  final bool extraBetaApprovalEnabled;
  final double extraBetaLimit;
  final String notes;
  final String? openingPhotoPath;
  final HodMachineEntryStatus status;
  final List<HodMachinePaymentTransaction> payments;

  const HodMachineEntryRecord({
    required this.id,
    required this.siteId,
    required this.hodId,
    required this.createdAt,
    required this.updatedAt,
    required this.machine,
    required this.supplier,
    required this.billingType,
    required this.dieselInclusion,
    required this.fuelType,
    required this.stockPoint,
    required this.fuelLiters,
    required this.fareAmount,
    this.commissionAgent = '',
    this.commissionAmount = 0,
    this.betaEligibleHours = 8,
    this.regularBetaAmount = 0,
    this.extraBetaApprovalEnabled = false,
    this.extraBetaLimit = 0,
    this.notes = '',
    this.openingPhotoPath,
    this.status = HodMachineEntryStatus.submitted,
    this.payments = const [],
  });

  double get cashTotal => payments
      .where((payment) => payment.kind == HodMachinePaymentKind.cash)
      .fold<double>(0, (sum, payment) => sum + payment.amount);

  double get advanceTotal => payments
      .where((payment) => payment.kind == HodMachinePaymentKind.advance)
      .fold<double>(0, (sum, payment) => sum + payment.amount);

  double get payableTotal => fareAmount + commissionAmount + regularBetaAmount;

  bool get hasPendingHodApproval => payments.any(
        (payment) =>
            payment.kind == HodMachinePaymentKind.advance &&
            payment.status == HodMachinePaymentStatus.draft,
      );

  bool get hasPendingFinance => payments.any(
        (payment) =>
            payment.kind == HodMachinePaymentKind.advance &&
            payment.status == HodMachinePaymentStatus.submittedToFinance,
      );

  HodMachineEntryRecord copyWith({
    String? id,
    String? siteId,
    String? hodId,
    DateTime? createdAt,
    DateTime? updatedAt,
    HodMachineCatalogItem? machine,
    HodMachineSupplier? supplier,
    String? billingType,
    String? dieselInclusion,
    String? fuelType,
    String? stockPoint,
    double? fuelLiters,
    double? fareAmount,
    String? commissionAgent,
    double? commissionAmount,
    double? betaEligibleHours,
    double? regularBetaAmount,
    bool? extraBetaApprovalEnabled,
    double? extraBetaLimit,
    String? notes,
    String? openingPhotoPath,
    HodMachineEntryStatus? status,
    List<HodMachinePaymentTransaction>? payments,
  }) {
    return HodMachineEntryRecord(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      hodId: hodId ?? this.hodId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      machine: machine ?? this.machine,
      supplier: supplier ?? this.supplier,
      billingType: billingType ?? this.billingType,
      dieselInclusion: dieselInclusion ?? this.dieselInclusion,
      fuelType: fuelType ?? this.fuelType,
      stockPoint: stockPoint ?? this.stockPoint,
      fuelLiters: fuelLiters ?? this.fuelLiters,
      fareAmount: fareAmount ?? this.fareAmount,
      commissionAgent: commissionAgent ?? this.commissionAgent,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      betaEligibleHours: betaEligibleHours ?? this.betaEligibleHours,
      regularBetaAmount: regularBetaAmount ?? this.regularBetaAmount,
      extraBetaApprovalEnabled:
          extraBetaApprovalEnabled ?? this.extraBetaApprovalEnabled,
      extraBetaLimit: extraBetaLimit ?? this.extraBetaLimit,
      notes: notes ?? this.notes,
      openingPhotoPath: openingPhotoPath ?? this.openingPhotoPath,
      status: status ?? this.status,
      payments: payments ?? this.payments,
    );
  }
}
