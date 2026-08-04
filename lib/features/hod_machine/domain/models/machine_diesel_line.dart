/// Diesel line within a daily machine log.
class MachineDieselLine {
  final String id;
  final String dailyLogId;
  final String fuelType;
  final String? stockPoint;
  final double liters;
  final double amount;
  final String? remarks;
  final DateTime createdAt;

  MachineDieselLine({
    required this.id,
    required this.dailyLogId,
    this.fuelType = 'Diesel',
    this.stockPoint,
    this.liters = 0,
    this.amount = 0,
    this.remarks,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MachineDieselLine.fromJson(Map<String, dynamic> json) {
    return MachineDieselLine(
      id: json['id'] as String,
      dailyLogId: json['daily_log_id'] as String,
      fuelType: json['fuel_type'] as String? ?? 'Diesel',
      stockPoint: json['stock_point'] as String?,
      liters: (json['liters'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      remarks: json['remarks'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'daily_log_id': dailyLogId,
    'fuel_type': fuelType,
    'stock_point': stockPoint,
    'liters': liters,
    'amount': amount,
    'remarks': remarks,
    'created_at': createdAt.toIso8601String(),
  };
}
