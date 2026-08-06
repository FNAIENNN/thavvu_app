enum SupplierType {
  permanent,
  temporary,
}

class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String category;
  final String usagePurpose;
  final String siteName;
  final String siteId;
  final String thavvuPointId;
  final String supervisorId;
  final SupplierType type;
  final DateTime validFrom;
  final DateTime? validUntil;
  final String notes;
  final String createdByHodId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool active; // soft-delete flag (hidden from dropdowns when false)

  // Payment details stored by the HOD enterprise catalog (suppliers table).
  final String paymentUpi;
  final String paymentAccountHolder;
  final String paymentBank;
  final String paymentAccountNumber;
  final String paymentIfsc;
  final String paymentNote;

  const Supplier({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.address,
    required this.category,
    required this.usagePurpose,
    required this.siteName,
    required this.siteId,
    required this.thavvuPointId,
    required this.supervisorId,
    required this.type,
    required this.validFrom,
    required this.validUntil,
    required this.notes,
    required this.createdByHodId,
    required this.createdAt,
    required this.updatedAt,
    this.active = true,
    this.paymentUpi = '',
    this.paymentAccountHolder = '',
    this.paymentBank = '',
    this.paymentAccountNumber = '',
    this.paymentIfsc = '',
    this.paymentNote = '',
  });

  bool get isTemporary => type == SupplierType.temporary;

  bool get isExpired {
    final until = validUntil;
    if (until == null) return false;
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final expiryDate = DateTime(until.year, until.month, until.day);
    return expiryDate.isBefore(currentDate);
  }

  bool get isUsableBySupervisor => !isExpired;

  String get typeLabel => isTemporary ? 'Temporary' : 'Permanent';

  Supplier copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? category,
    String? usagePurpose,
    String? siteName,
    String? siteId,
    String? thavvuPointId,
    String? supervisorId,
    SupplierType? type,
    DateTime? validFrom,
    DateTime? validUntil,
    bool clearValidUntil = false,
    String? notes,
    String? createdByHodId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      category: category ?? this.category,
      usagePurpose: usagePurpose ?? this.usagePurpose,
      siteName: siteName ?? this.siteName,
      siteId: siteId ?? this.siteId,
      thavvuPointId: thavvuPointId ?? this.thavvuPointId,
      supervisorId: supervisorId ?? this.supervisorId,
      type: type ?? this.type,
      validFrom: validFrom ?? this.validFrom,
      validUntil: clearValidUntil ? null : validUntil ?? this.validUntil,
      notes: notes ?? this.notes,
      createdByHodId: createdByHodId ?? this.createdByHodId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'category': category,
      'usagePurpose': usagePurpose,
      'siteName': siteName,
      'siteId': siteId,
      'thavvuPointId': thavvuPointId,
      'supervisorId': supervisorId,
      'type': type.name,
      'validFrom': validFrom.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'notes': notes,
      'createdByHodId': createdByHodId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      usagePurpose: json['usagePurpose']?.toString() ?? '',
      siteName: json['siteName']?.toString() ?? '',
      siteId: json['siteId']?.toString() ?? '',
      thavvuPointId: json['thavvuPointId']?.toString() ?? '',
      supervisorId: json['supervisorId']?.toString() ?? '',
      type: SupplierType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => SupplierType.permanent,
      ),
      validFrom: _parseDate(json['validFrom']) ?? DateTime.now(),
      validUntil: _parseDate(json['validUntil']),
      notes: json['notes']?.toString() ?? '',
      createdByHodId: json['createdByHodId']?.toString() ?? 'HOD-001',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
