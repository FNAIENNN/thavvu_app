enum CashAllocationStatus {
  issued,
  voided,
}

class CashAllocation {
  final String id;
  final String supervisorId;
  final String supervisorName;
  final String siteId;
  final String siteName;
  final double amount;
  final String purpose;
  final String category;
  final String paymentMode;
  final String reference;
  final String notes;
  final String issuedByHodId;
  final DateTime issuedAt;
  final CashAllocationStatus status;
  final DateTime? voidedAt;
  final String? voidReason;

  const CashAllocation({
    required this.id,
    required this.supervisorId,
    required this.supervisorName,
    required this.siteId,
    required this.siteName,
    required this.amount,
    required this.purpose,
    required this.category,
    required this.paymentMode,
    required this.reference,
    required this.notes,
    required this.issuedByHodId,
    required this.issuedAt,
    this.status = CashAllocationStatus.issued,
    this.voidedAt,
    this.voidReason,
  });

  bool get isActive => status == CashAllocationStatus.issued;

  CashAllocation copyWith({
    String? id,
    String? supervisorId,
    String? supervisorName,
    String? siteId,
    String? siteName,
    double? amount,
    String? purpose,
    String? category,
    String? paymentMode,
    String? reference,
    String? notes,
    String? issuedByHodId,
    DateTime? issuedAt,
    CashAllocationStatus? status,
    DateTime? voidedAt,
    String? voidReason,
  }) {
    return CashAllocation(
      id: id ?? this.id,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      amount: amount ?? this.amount,
      purpose: purpose ?? this.purpose,
      category: category ?? this.category,
      paymentMode: paymentMode ?? this.paymentMode,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      issuedByHodId: issuedByHodId ?? this.issuedByHodId,
      issuedAt: issuedAt ?? this.issuedAt,
      status: status ?? this.status,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'siteId': siteId,
      'siteName': siteName,
      'amount': amount,
      'purpose': purpose,
      'category': category,
      'paymentMode': paymentMode,
      'reference': reference,
      'notes': notes,
      'issuedByHodId': issuedByHodId,
      'issuedAt': issuedAt.toIso8601String(),
      'status': status.name,
      'voidedAt': voidedAt?.toIso8601String(),
      'voidReason': voidReason,
    };
  }

  factory CashAllocation.fromJson(Map<String, dynamic> json) {
    return CashAllocation(
      id: json['id']?.toString() ?? '',
      supervisorId: json['supervisorId']?.toString() ?? '',
      supervisorName: json['supervisorName']?.toString() ?? '',
      siteId: json['siteId']?.toString() ?? '',
      siteName: json['siteName']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ??
          double.tryParse(json['amount']?.toString() ?? '') ??
          0,
      purpose: json['purpose']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      paymentMode: json['paymentMode']?.toString() ?? 'Cash',
      reference: json['reference']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      issuedByHodId: json['issuedByHodId']?.toString() ?? 'HOD-001',
      issuedAt: DateTime.tryParse(json['issuedAt']?.toString() ?? '') ??
          DateTime.now(),
      status: CashAllocationStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => CashAllocationStatus.issued,
      ),
      voidedAt: DateTime.tryParse(json['voidedAt']?.toString() ?? ''),
      voidReason: json['voidReason']?.toString(),
    );
  }
}
