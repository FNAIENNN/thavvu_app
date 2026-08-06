/// Machine asset (catalog item) — mirrors `machine_assets` table.
class MachineAsset {
  final String id;
  final String siteId;
  final String machineName;
  final String vehicleNumber;
  final String vehicleType;
  final String operatorName;
  final String? operatorPhone;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MachineAsset({
    required this.id,
    required this.siteId,
    required this.machineName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.operatorName,
    this.operatorPhone,
    this.isActive = true,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory MachineAsset.fromJson(Map<String, dynamic> json) {
    return MachineAsset(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      machineName: json['machine_name'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      vehicleType: json['vehicle_type'] as String,
      operatorName: json['operator_name'] as String,
      operatorPhone: json['operator_phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'site_id': siteId,
    'machine_name': machineName,
    'vehicle_number': vehicleNumber,
    'vehicle_type': vehicleType,
    'operator_name': operatorName,
    'operator_phone': operatorPhone,
    'is_active': isActive,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  MachineAsset copyWith({
    String? id,
    String? siteId,
    String? machineName,
    String? vehicleNumber,
    String? vehicleType,
    String? operatorName,
    String? operatorPhone,
    bool? isActive,
  }) {
    return MachineAsset(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      machineName: machineName ?? this.machineName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      operatorName: operatorName ?? this.operatorName,
      operatorPhone: operatorPhone ?? this.operatorPhone,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
