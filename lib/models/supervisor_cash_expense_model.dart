enum SupervisorCashExpenseStatus {
  pending,
  approved,
  revisionRequested,
  rejected,
}

class SupervisorCashExpenseItem {
  final String name;
  final int quantity;
  final double amount;
  final String category;
  final bool transportEnabled;
  final String vehicleType;
  final double transportAmount;

  const SupervisorCashExpenseItem({
    required this.name,
    required this.quantity,
    required this.amount,
    required this.category,
    this.transportEnabled = false,
    this.vehicleType = '',
    this.transportAmount = 0,
  });

  double get baseTotal => quantity * amount;

  double get total => baseTotal + (transportEnabled ? transportAmount : 0);

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'amount': amount,
      'category': category,
      'transportEnabled': transportEnabled,
      'vehicleType': vehicleType,
      'transportAmount': transportAmount,
    };
  }

  factory SupervisorCashExpenseItem.fromJson(Map<String, dynamic> json) {
    return SupervisorCashExpenseItem(
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ??
          int.tryParse(json['quantity']?.toString() ?? '') ??
          0,
      amount: (json['amount'] as num?)?.toDouble() ??
          double.tryParse(json['amount']?.toString() ?? '') ??
          0,
      category: json['category']?.toString() ?? 'others',
      transportEnabled: json['transportEnabled'] == true,
      vehicleType: json['vehicleType']?.toString() ?? '',
      transportAmount: (json['transportAmount'] as num?)?.toDouble() ??
          double.tryParse(json['transportAmount']?.toString() ?? '') ??
          0,
    );
  }
}

class SupervisorCashExpense {
  final String id;
  final String supervisorId;
  final String supervisorName;
  final String thavvuId;
  final String siteId;
  final String siteName;
  final String category;
  final String title;
  final double amount;
  final DateTime submittedAt;
  final List<SupervisorCashExpenseItem> items;
  final String remarks;
  final String invoiceBillPath;
  final String vehiclePhotoPath;
  final SupervisorCashExpenseStatus status;
  final DateTime? decidedAt;
  final String hodNote;

  const SupervisorCashExpense({
    required this.id,
    required this.supervisorId,
    required this.supervisorName,
    required this.thavvuId,
    required this.siteId,
    required this.siteName,
    required this.category,
    required this.title,
    required this.amount,
    required this.submittedAt,
    required this.items,
    required this.remarks,
    this.invoiceBillPath = '',
    this.vehiclePhotoPath = '',
    this.status = SupervisorCashExpenseStatus.pending,
    this.decidedAt,
    this.hodNote = '',
  });

  bool get affectsSupervisorBalance =>
      status != SupervisorCashExpenseStatus.rejected;

  SupervisorCashExpense copyWith({
    String? id,
    String? supervisorId,
    String? supervisorName,
    String? thavvuId,
    String? siteId,
    String? siteName,
    String? category,
    String? title,
    double? amount,
    DateTime? submittedAt,
    List<SupervisorCashExpenseItem>? items,
    String? remarks,
    String? invoiceBillPath,
    String? vehiclePhotoPath,
    SupervisorCashExpenseStatus? status,
    DateTime? decidedAt,
    String? hodNote,
  }) {
    return SupervisorCashExpense(
      id: id ?? this.id,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      thavvuId: thavvuId ?? this.thavvuId,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      submittedAt: submittedAt ?? this.submittedAt,
      items: items ?? this.items,
      remarks: remarks ?? this.remarks,
      invoiceBillPath: invoiceBillPath ?? this.invoiceBillPath,
      vehiclePhotoPath: vehiclePhotoPath ?? this.vehiclePhotoPath,
      status: status ?? this.status,
      decidedAt: decidedAt ?? this.decidedAt,
      hodNote: hodNote ?? this.hodNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'thavvuId': thavvuId,
      'siteId': siteId,
      'siteName': siteName,
      'category': category,
      'title': title,
      'amount': amount,
      'submittedAt': submittedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'remarks': remarks,
      'invoiceBillPath': invoiceBillPath,
      'vehiclePhotoPath': vehiclePhotoPath,
      'status': status.name,
      'decidedAt': decidedAt?.toIso8601String(),
      'hodNote': hodNote,
    };
  }

  factory SupervisorCashExpense.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return SupervisorCashExpense(
      id: json['id']?.toString() ?? '',
      supervisorId: json['supervisorId']?.toString() ?? '',
      supervisorName: json['supervisorName']?.toString() ?? '',
      thavvuId: json['thavvuId']?.toString() ?? '',
      siteId: json['siteId']?.toString() ?? '',
      siteName: json['siteName']?.toString() ?? '',
      category: json['category']?.toString() ?? 'others',
      title: json['title']?.toString() ?? 'Cash Pay',
      amount: (json['amount'] as num?)?.toDouble() ??
          double.tryParse(json['amount']?.toString() ?? '') ??
          0,
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? '') ??
          DateTime.now(),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => SupervisorCashExpenseItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      remarks: json['remarks']?.toString() ?? '',
      invoiceBillPath: json['invoiceBillPath']?.toString() ?? '',
      vehiclePhotoPath: json['vehiclePhotoPath']?.toString() ?? '',
      status: SupervisorCashExpenseStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => SupervisorCashExpenseStatus.pending,
      ),
      decidedAt: DateTime.tryParse(json['decidedAt']?.toString() ?? ''),
      hodNote: json['hodNote']?.toString() ?? '',
    );
  }
}
