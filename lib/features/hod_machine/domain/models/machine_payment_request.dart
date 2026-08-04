/// Payment kind (cash vs advance).
enum PaymentKind {
  cash,
  advance;

  String get apiValue => name;

  static PaymentKind fromApi(String value) {
    switch (value) {
      case 'cash':
        return PaymentKind.cash;
      case 'advance':
        return PaymentKind.advance;
      default:
        return PaymentKind.cash;
    }
  }
}

/// Payment status — enforced server-side by RLS and guarded transitions.
enum PaymentStatus {
  draft,
  hodApproved,
  hodRejected,
  submittedToFinance,
  financeProcessing,
  paid,
  closed;

  String get apiValue {
    switch (this) {
      case PaymentStatus.draft:
        return 'draft';
      case PaymentStatus.hodApproved:
        return 'hod_approved';
      case PaymentStatus.hodRejected:
        return 'hod_rejected';
      case PaymentStatus.submittedToFinance:
        return 'submitted_to_finance';
      case PaymentStatus.financeProcessing:
        return 'finance_processing';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.closed:
        return 'closed';
    }
  }

  static PaymentStatus fromApi(String value) {
    switch (value) {
      case 'hod_approved':
        return PaymentStatus.hodApproved;
      case 'hod_rejected':
        return PaymentStatus.hodRejected;
      case 'submitted_to_finance':
        return PaymentStatus.submittedToFinance;
      case 'finance_processing':
        return PaymentStatus.financeProcessing;
      case 'paid':
        return PaymentStatus.paid;
      case 'closed':
        return PaymentStatus.closed;
      default:
        return PaymentStatus.draft;
    }
  }

  String get displayLabel {
    switch (this) {
      case PaymentStatus.draft:
        return 'Pending HOD Approval';
      case PaymentStatus.hodApproved:
        return 'HOD Approved';
      case PaymentStatus.hodRejected:
        return 'HOD Rejected';
      case PaymentStatus.submittedToFinance:
        return 'Submitted to Finance';
      case PaymentStatus.financeProcessing:
        return 'Finance Processing';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.closed:
        return 'Closed';
    }
  }
}

/// Machine payment request — mirrors `machine_payment_requests` table.
class MachinePaymentRequest {
  final String id;
  final String? dailyLogId;
  final String? machineEntryId;
  final String siteId;
  final String thavvuPointId;
  final PaymentKind kind;
  final double amount;
  final String? paymentMode;
  final String? entryMethod;
  final String? accountLabel;
  final String? notes;
  final PaymentStatus status;
  final DateTime? hodApprovedAt;
  final String? hodApprovedBy;
  final DateTime? submittedToFinanceAt;
  final DateTime? paidAt;
  final String? paidBy;
  final String? paymentProofPath;
  final bool registeredInIdsBook;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MachinePaymentRequest({
    required this.id,
    this.dailyLogId,
    this.machineEntryId,
    required this.siteId,
    required this.thavvuPointId,
    required this.kind,
    required this.amount,
    this.paymentMode,
    this.entryMethod,
    this.accountLabel,
    this.notes,
    this.status = PaymentStatus.draft,
    this.hodApprovedAt,
    this.hodApprovedBy,
    this.submittedToFinanceAt,
    this.paidAt,
    this.paidBy,
    this.paymentProofPath,
    this.registeredInIdsBook = false,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isAdvance => kind == PaymentKind.advance;
  bool get isCash => kind == PaymentKind.cash;

  factory MachinePaymentRequest.fromJson(Map<String, dynamic> json) {
    return MachinePaymentRequest(
      id: json['id'] as String,
      dailyLogId: json['daily_log_id'] as String?,
      machineEntryId: json['machine_entry_id'] as String?,
      siteId: json['site_id'] as String,
      thavvuPointId: json['thavvu_point_id'] as String,
      kind: PaymentKind.fromApi(json['kind'] as String? ?? 'cash'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMode: json['payment_mode'] as String?,
      entryMethod: json['entry_method'] as String?,
      accountLabel: json['account_label'] as String?,
      notes: json['notes'] as String?,
      status: PaymentStatus.fromApi(json['status'] as String? ?? 'draft'),
      hodApprovedAt: json['hod_approved_at'] != null
          ? DateTime.parse(json['hod_approved_at'] as String)
          : null,
      hodApprovedBy: json['hod_approved_by'] as String?,
      submittedToFinanceAt: json['submitted_to_finance_at'] != null
          ? DateTime.parse(json['submitted_to_finance_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      paidBy: json['paid_by'] as String?,
      paymentProofPath: json['payment_proof_path'] as String?,
      registeredInIdsBook: json['registered_in_ids_book'] as bool? ?? false,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'daily_log_id': dailyLogId,
    'machine_entry_id': machineEntryId,
    'site_id': siteId,
    'thavvu_point_id': thavvuPointId,
    'kind': kind.apiValue,
    'amount': amount,
    'payment_mode': paymentMode,
    'entry_method': entryMethod,
    'account_label': accountLabel,
    'notes': notes,
    'status': status.apiValue,
    'hod_approved_at': hodApprovedAt?.toIso8601String(),
    'hod_approved_by': hodApprovedBy,
    'submitted_to_finance_at': submittedToFinanceAt?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'paid_by': paidBy,
    'payment_proof_path': paymentProofPath,
    'registered_in_ids_book': registeredInIdsBook,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
