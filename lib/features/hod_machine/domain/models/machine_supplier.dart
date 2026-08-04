/// Machine supplier model — mirrors the `machine_suppliers` table.
class MachineSupplier {
  final String id;
  final String siteId;
  final String name;
  final String type; // permanent | temporary | all
  final String? phone;
  final double rating;
  final DateTime? validUntil;
  final String? notes;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MachineSupplier({
    required this.id,
    required this.siteId,
    required this.name,
    this.type = 'permanent',
    this.phone,
    this.rating = 0,
    this.validUntil,
    this.notes,
    this.isActive = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isTemporary => type == 'temporary';

  factory MachineSupplier.fromJson(Map<String, dynamic> json) {
    return MachineSupplier(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'permanent',
      phone: json['phone'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String)
          : null,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'name': name,
    'type': type,
    'phone': phone,
    'rating': rating,
    'valid_until': validUntil?.toIso8601String(),
    'notes': notes,
    'is_active': isActive,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  MachineSupplier copyWith({
    String? id,
    String? siteId,
    String? name,
    String? type,
    String? phone,
    double? rating,
    DateTime? validUntil,
    String? notes,
    bool? isActive,
  }) {
    return MachineSupplier(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      rating: rating ?? this.rating,
      validUntil: validUntil ?? this.validUntil,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
