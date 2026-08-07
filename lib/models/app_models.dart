/// Shared domain models for the Thavvu local backend.
///
/// v2 schema: adds Sites + Thavvu Points, HOD/Supervisor roles, a stock item
/// catalog with category-based units, photo attachments, supplier registry &
/// payment tracking, and an activity ledger for reporting.

// ── Sites & Thavvu Points ────────────────────────────────────────────────────

class WorkSite {
  final String id;
  final String name;
  final String location;
  final String code;

  const WorkSite({
    required this.id,
    required this.name,
    required this.location,
    required this.code,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'code': code,
      };

  factory WorkSite.fromJson(Map<String, dynamic> j) => WorkSite(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String? ?? '',
        code: j['code'] as String? ?? '',
      );
}

class ThavvuPoint {
  final String id;
  final String siteId;
  final String name;
  final String code;
  final String type; // warehouse | field | office

  const ThavvuPoint({
    required this.id,
    required this.siteId,
    required this.name,
    required this.code,
    this.type = 'field',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'siteId': siteId,
        'name': name,
        'code': code,
        'type': type,
      };

  factory ThavvuPoint.fromJson(Map<String, dynamic> j) => ThavvuPoint(
        id: j['id'] as String,
        siteId: j['siteId'] as String,
        name: j['name'] as String,
        code: j['code'] as String? ?? '',
        type: j['type'] as String? ?? 'field',
      );
}

// ── Stock catalog primitives ─────────────────────────────────────────────────

/// Category identifiers used across the stock catalog.
class StockCategory {
  StockCategory._();
  static const String fuel = 'fuel';
  static const String chemical = 'chemical';
  static const String lubricant = 'lubricant';
  static const String parts = 'parts';
  static const String material = 'material';
  static const String other = 'other';

  static const List<String> all = [
    fuel,
    chemical,
    lubricant,
    parts,
    material,
    other,
  ];

  /// Default unit hint for a category when an item does not specify one.
  static String defaultUnit(String category) {
    switch (category) {
      case fuel:
      case lubricant:
        return 'Litres';
      case chemical:
        return 'Bags';
      case parts:
        return 'Pieces';
      case material:
        return 'Bags';
      default:
        return 'Nos';
    }
  }

  static String label(String category) {
    switch (category) {
      case fuel:
        return 'Fuel';
      case chemical:
        return 'Chemical';
      case lubricant:
        return 'Lubricant';
      case parts:
        return 'Parts';
      case material:
        return 'Material';
      default:
        return 'Other';
    }
  }
}

/// A catalog definition for a stock item.
/// unit: Litres | Kg | Bags | Pieces | Tubes | Quarts | Gallons | Nos
class StockItemDef {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double reorderLevel;

  const StockItemDef({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    this.reorderLevel = 20,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'reorderLevel': reorderLevel,
      };

  factory StockItemDef.fromJson(Map<String, dynamic> j) => StockItemDef(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? StockCategory.other,
        unit: j['unit'] as String? ?? 'Nos',
        reorderLevel: (j['reorderLevel'] as num?)?.toDouble() ?? 20,
      );
}

/// Per-item quantity balance held at a specific stock point.
class StockBalance {
  final String stockPointId;
  final String itemId;
  final String itemName;
  final String category;
  final String unit;
  final double quantity;

  const StockBalance({
    required this.stockPointId,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.unit,
    this.quantity = 0,
  });

  StockBalance copyWith({double? quantity}) => StockBalance(
        stockPointId: stockPointId,
        itemId: itemId,
        itemName: itemName,
        category: category,
        unit: unit,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'stockPointId': stockPointId,
        'itemId': itemId,
        'itemName': itemName,
        'category': category,
        'unit': unit,
        'quantity': quantity,
      };

  factory StockBalance.fromJson(Map<String, dynamic> j) => StockBalance(
        stockPointId: j['stockPointId'] as String,
        itemId: j['itemId'] as String? ?? '',
        itemName: j['itemName'] as String,
        category: j['category'] as String? ?? StockCategory.other,
        unit: j['unit'] as String? ?? 'Nos',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
      );
}

// ── Remote profile (hod | supervisor) ───────────────────────────────────────

/// Lightweight mirror of a `profiles` row from the remote backend, used once
/// a user has authenticated against Supabase Postgres.
class Profile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // hod | supervisor
  final String? hodId;
  final String empId;

  const Profile({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'supervisor',
    this.hodId,
    this.empId = '',
  });

  bool get isHod => role.toLowerCase() == 'hod';
  bool get isSupervisor => role.toLowerCase() == 'supervisor';

  Profile copyWith({String? hodId}) => Profile(
        id: id,
        name: name,
        email: email,
        phone: phone,
        role: role,
        hodId: hodId ?? this.hodId,
        empId: empId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'hodId': hodId,
        'empId': empId,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        role: j['role'] as String? ?? 'supervisor',
        hodId: j['hodId'] as String?,
        empId: j['empId'] as String? ?? '',
      );

  /// Maps a raw row returned by `RemoteRepository.login`.
  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
        id: row['id'].toString(),
        name: row['full_name'] as String? ?? '',
        email: row['email'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
        role: (row['role'] as String? ?? 'supervisor').toLowerCase(),
        hodId: row['hod_id']?.toString(),
        empId: row['emp_id'] as String? ?? '',
      );
}

// ── Users ────────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role; // HOD | Supervisor
  final String empId;
  final String site;
  final String siteId;
  final String? thavvuPointId;
  final String phone;
  final String joinDate;
  final bool approved;
  final bool rememberMe;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.role = 'Supervisor',
    this.empId = '',
    this.site = 'Site A – Chennai North',
    this.siteId = '',
    this.thavvuPointId,
    this.phone = '',
    this.joinDate = '',
    this.approved = true,
    this.rememberMe = false,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? password,
    String? role,
    String? empId,
    String? site,
    String? siteId,
    String? thavvuPointId,
    String? phone,
    String? joinDate,
    bool? approved,
    bool? rememberMe,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      empId: empId ?? this.empId,
      site: site ?? this.site,
      siteId: siteId ?? this.siteId,
      thavvuPointId: thavvuPointId ?? this.thavvuPointId,
      phone: phone ?? this.phone,
      joinDate: joinDate ?? this.joinDate,
      approved: approved ?? this.approved,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'empId': empId,
        'site': site,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'phone': phone,
        'joinDate': joinDate,
        'approved': approved,
        'rememberMe': rememberMe,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        password: j['password'] as String,
        role: j['role'] as String? ?? 'Supervisor',
        empId: j['empId'] as String? ?? '',
        site: j['site'] as String? ?? '',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String?,
        phone: j['phone'] as String? ?? '',
        joinDate: j['joinDate'] as String? ?? '',
        approved: j['approved'] as bool? ?? true,
        rememberMe: j['rememberMe'] as bool? ?? false,
      );
}

// ── Machines ─────────────────────────────────────────────────────────────────

class MachineRecord {
  final String id;
  final String machineId;
  final String operatorName;
  final String vehicleNumber;
  final String vehicleType;
  final String billingType;
  final double workingAmount;
  final String paymentMode;
  final double dieselAmount;
  final double usedAmount;
  final String? dieselInclusion;
  final String supplierName;
  final double supplierAmount;
  final String notes;
  final String status; // pending | approved | rejected
  final String siteId;
  final String thavvuPointId;
  final String? photoPath;
  final String? supplierId;
  final String? supplierPaymentMode;
  final DateTime createdAt;

  const MachineRecord({
    required this.id,
    required this.machineId,
    required this.operatorName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.billingType,
    required this.workingAmount,
    this.paymentMode = 'cash',
    this.dieselAmount = 0,
    this.usedAmount = 0,
    this.dieselInclusion,
    this.supplierName = '',
    this.supplierAmount = 0,
    this.notes = '',
    this.status = 'pending',
    this.siteId = '',
    this.thavvuPointId = '',
    this.photoPath,
    this.supplierId,
    this.supplierPaymentMode,
    required this.createdAt,
  });

  String get displayName => '$vehicleType ($machineId)';

  MachineRecord copyWith({String? status, String? supplierId}) => MachineRecord(
        id: id,
        machineId: machineId,
        operatorName: operatorName,
        vehicleNumber: vehicleNumber,
        vehicleType: vehicleType,
        billingType: billingType,
        workingAmount: workingAmount,
        paymentMode: paymentMode,
        dieselAmount: dieselAmount,
        usedAmount: usedAmount,
        dieselInclusion: dieselInclusion,
        supplierName: supplierName,
        supplierAmount: supplierAmount,
        notes: notes,
        status: status ?? this.status,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        photoPath: photoPath,
        supplierId: supplierId ?? this.supplierId,
        supplierPaymentMode: supplierPaymentMode,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machineId': machineId,
        'operatorName': operatorName,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'billingType': billingType,
        'workingAmount': workingAmount,
        'paymentMode': paymentMode,
        'dieselAmount': dieselAmount,
        'usedAmount': usedAmount,
        'dieselInclusion': dieselInclusion,
        'supplierName': supplierName,
        'supplierAmount': supplierAmount,
        'notes': notes,
        'status': status,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'photoPath': photoPath,
        'supplierId': supplierId,
        'supplierPaymentMode': supplierPaymentMode,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MachineRecord.fromJson(Map<String, dynamic> j) => MachineRecord(
        id: j['id'] as String,
        machineId: j['machineId'] as String,
        operatorName: j['operatorName'] as String,
        vehicleNumber: j['vehicleNumber'] as String,
        vehicleType: j['vehicleType'] as String,
        billingType: j['billingType'] as String,
        workingAmount: (j['workingAmount'] as num).toDouble(),
        paymentMode: j['paymentMode'] as String? ?? 'cash',
        dieselAmount: (j['dieselAmount'] as num?)?.toDouble() ?? 0,
        usedAmount: (j['usedAmount'] as num?)?.toDouble() ?? 0,
        dieselInclusion: j['dieselInclusion'] as String?,
        supplierName: j['supplierName'] as String? ?? '',
        supplierAmount: (j['supplierAmount'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        supplierId: j['supplierId'] as String?,
        supplierPaymentMode: j['supplierPaymentMode'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class TimeBlockData {
  final String id;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const TimeBlockData({
    required this.id,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
      };

  factory TimeBlockData.fromJson(Map<String, dynamic> j) => TimeBlockData(
        id: j['id'] as String,
        startHour: j['startHour'] as int,
        startMinute: j['startMinute'] as int,
        endHour: j['endHour'] as int,
        endMinute: j['endMinute'] as int,
      );
}

class DailyLog {
  final String id;
  final String machineId;
  final String machineName;
  final double usedAmount;
  final double dieselAmount;
  final double betaAmount;
  final String notes;
  final String paymentMode;
  final String siteId;
  final String thavvuPointId;
  final String? photoPath;
  final String? consumptionItemId;
  final List<TimeBlockData> timeBlocks;
  final String status; // submitted | approved | rejected
  final String? hodNote;
  final DateTime createdAt;

  const DailyLog({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.usedAmount,
    this.dieselAmount = 0,
    this.betaAmount = 0,
    this.notes = '',
    this.paymentMode = 'cash',
    this.siteId = '',
    this.thavvuPointId = '',
    this.photoPath,
    this.consumptionItemId,
    this.timeBlocks = const [],
    this.status = 'submitted',
    this.hodNote,
    required this.createdAt,
  });

  /// Alias so screens/reports can read diesel volume in Litres semantics.
  double get dieselLitres => dieselAmount;

  DailyLog copyWith({String? status, String? hodNote}) => DailyLog(
        id: id,
        machineId: machineId,
        machineName: machineName,
        usedAmount: usedAmount,
        dieselAmount: dieselAmount,
        betaAmount: betaAmount,
        notes: notes,
        paymentMode: paymentMode,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        photoPath: photoPath,
        consumptionItemId: consumptionItemId,
        timeBlocks: timeBlocks,
        status: status ?? this.status,
        hodNote: hodNote ?? this.hodNote,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machineId': machineId,
        'machineName': machineName,
        'usedAmount': usedAmount,
        'dieselAmount': dieselAmount,
        'betaAmount': betaAmount,
        'notes': notes,
        'paymentMode': paymentMode,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'photoPath': photoPath,
        'consumptionItemId': consumptionItemId,
        'timeBlocks': timeBlocks.map((e) => e.toJson()).toList(),
        'status': status,
        'hodNote': hodNote,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
        id: j['id'] as String,
        machineId: j['machineId'] as String,
        machineName: j['machineName'] as String,
        usedAmount: (j['usedAmount'] as num).toDouble(),
        dieselAmount: (j['dieselAmount'] as num?)?.toDouble() ?? 0,
        betaAmount: (j['betaAmount'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        paymentMode: j['paymentMode'] as String? ?? 'cash',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        consumptionItemId: j['consumptionItemId'] as String?,
        timeBlocks: ((j['timeBlocks'] as List?) ?? [])
            .map((e) => TimeBlockData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        status: j['status'] as String? ?? 'submitted',
        hodNote: j['hodNote'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── Workers & Attendance ─────────────────────────────────────────────────────

class Worker {
  final String id;
  final String name;
  final String department;
  final String type; // regular | outside
  final double? wage;
  final bool approved;

  const Worker({
    required this.id,
    required this.name,
    required this.department,
    this.type = 'regular',
    this.wage,
    this.approved = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'department': department,
        'type': type,
        'wage': wage,
        'approved': approved,
      };

  factory Worker.fromJson(Map<String, dynamic> j) => Worker(
        id: j['id'] as String,
        name: j['name'] as String,
        department: j['department'] as String,
        type: j['type'] as String? ?? 'regular',
        wage: (j['wage'] as num?)?.toDouble(),
        approved: j['approved'] as bool? ?? true,
      );
}

class AttendanceRecord {
  final String id;
  final String workerId;
  final String workerName;
  final String workerType;
  final String status; // Present | Absent | Half Day | Leave
  final bool morning;
  final bool evening;
  final String method;
  final String siteId;
  final String? photoPath;
  final DateTime date;
  final bool photoCaptured;

  const AttendanceRecord({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.workerType,
    required this.status,
    this.morning = false,
    this.evening = false,
    this.method = 'Manual',
    this.siteId = '',
    this.photoPath,
    required this.date,
    this.photoCaptured = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerId': workerId,
        'workerName': workerName,
        'workerType': workerType,
        'status': status,
        'morning': morning,
        'evening': evening,
        'method': method,
        'siteId': siteId,
        'photoPath': photoPath,
        'date': date.toIso8601String(),
        'photoCaptured': photoCaptured,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: j['id'] as String,
        workerId: j['workerId'] as String,
        workerName: j['workerName'] as String,
        workerType: j['workerType'] as String,
        status: j['status'] as String,
        morning: j['morning'] as bool? ?? false,
        evening: j['evening'] as bool? ?? false,
        method: j['method'] as String? ?? 'Manual',
        siteId: j['siteId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        date: DateTime.parse(j['date'] as String),
        photoCaptured: j['photoCaptured'] as bool? ?? false,
      );
}

// ── Stock points, movements, orders, returns ─────────────────────────────────

class StockPoint {
  final String id;
  final String name;
  final String location;
  final String batchId;
  final int onHand;
  final int todayUsage;
  final int reorderLevel;
  final int totalIn;
  final int totalOut;
  final String siteId;
  final String thavvuPointId;
  final List<StockBalance> balances;

  const StockPoint({
    required this.id,
    required this.name,
    required this.location,
    required this.batchId,
    required this.onHand,
    required this.todayUsage,
    required this.reorderLevel,
    required this.totalIn,
    required this.totalOut,
    this.siteId = '',
    this.thavvuPointId = '',
    this.balances = const [],
  });

  int get remaining => onHand - todayUsage;
  bool get isLow => remaining <= reorderLevel;
  double get stockPercentage =>
      reorderLevel == 0 ? 100 : (remaining / reorderLevel) * 100;

  StockPoint copyWith({
    int? onHand,
    int? todayUsage,
    int? totalIn,
    int? totalOut,
    String? batchId,
    List<StockBalance>? balances,
  }) =>
      StockPoint(
        id: id,
        name: name,
        location: location,
        batchId: batchId ?? this.batchId,
        onHand: onHand ?? this.onHand,
        todayUsage: todayUsage ?? this.todayUsage,
        reorderLevel: reorderLevel,
        totalIn: totalIn ?? this.totalIn,
        totalOut: totalOut ?? this.totalOut,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        balances: balances ?? this.balances,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'batchId': batchId,
        'onHand': onHand,
        'todayUsage': todayUsage,
        'reorderLevel': reorderLevel,
        'totalIn': totalIn,
        'totalOut': totalOut,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'balances': balances.map((e) => e.toJson()).toList(),
      };

  factory StockPoint.fromJson(Map<String, dynamic> j) => StockPoint(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        batchId: j['batchId'] as String,
        onHand: j['onHand'] as int,
        todayUsage: j['todayUsage'] as int,
        reorderLevel: j['reorderLevel'] as int,
        totalIn: j['totalIn'] as int,
        totalOut: j['totalOut'] as int,
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        balances: ((j['balances'] as List?) ?? [])
            .map((e) => StockBalance.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class StockMovement {
  final String id;
  final String type; // in | out | return | transfer
  final String item;
  final String? itemId;
  final String category;
  final String unit;
  final String batch;
  final String date;
  final String by;
  final int quantity;
  final String? stockPointId;
  final String? siteId;
  final String? thavvuPointId;

  const StockMovement({
    required this.id,
    required this.type,
    required this.item,
    required this.quantity,
    required this.batch,
    required this.date,
    required this.by,
    this.itemId,
    this.category = StockCategory.other,
    this.unit = 'Nos',
    this.stockPointId,
    this.siteId,
    this.thavvuPointId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'item': item,
        'itemId': itemId,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'batch': batch,
        'date': date,
        'by': by,
        'stockPointId': stockPointId,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: j['type'] as String,
        item: j['item'] as String,
        itemId: j['itemId'] as String?,
        category: j['category'] as String? ?? StockCategory.other,
        unit: j['unit'] as String? ?? 'Nos',
        quantity: j['quantity'] as int,
        batch: j['batch'] as String,
        date: j['date'] as String,
        by: j['by'] as String,
        stockPointId: j['stockPointId'] as String?,
        siteId: j['siteId'] as String?,
        thavvuPointId: j['thavvuPointId'] as String?,
      );
}

class StockOrder {
  final String id;
  final String stockPointId;
  final String stockPointName;
  final String item;
  final int quantity;
  final String unit;
  final String category;
  final String siteId;
  final String thavvuPointId;
  final String? photoPath;
  final String notes;
  final bool voiceNote;
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  const StockOrder({
    required this.id,
    required this.stockPointId,
    required this.stockPointName,
    required this.item,
    required this.quantity,
    this.unit = 'Units',
    this.category = StockCategory.other,
    this.siteId = '',
    this.thavvuPointId = '',
    this.photoPath,
    this.notes = '',
    this.voiceNote = false,
    this.status = 'pending',
    required this.createdAt,
  });

  StockOrder copyWith({String? status}) => StockOrder(
        id: id,
        stockPointId: stockPointId,
        stockPointName: stockPointName,
        item: item,
        quantity: quantity,
        unit: unit,
        category: category,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        photoPath: photoPath,
        notes: notes,
        voiceNote: voiceNote,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stockPointId': stockPointId,
        'stockPointName': stockPointName,
        'item': item,
        'quantity': quantity,
        'unit': unit,
        'category': category,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'photoPath': photoPath,
        'notes': notes,
        'voiceNote': voiceNote,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockOrder.fromJson(Map<String, dynamic> j) => StockOrder(
        id: j['id'] as String,
        stockPointId: j['stockPointId'] as String,
        stockPointName: j['stockPointName'] as String,
        item: j['item'] as String,
        quantity: j['quantity'] as int,
        unit: j['unit'] as String? ?? 'Units',
        category: j['category'] as String? ?? StockCategory.other,
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        notes: j['notes'] as String? ?? '',
        voiceNote: j['voiceNote'] as bool? ?? false,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class StockReturn {
  final String id;
  final String originalBatchId;
  final String item;
  final int quantity;
  final String reason;
  final String category;
  final String unit;
  final String siteId;
  final String thavvuPointId;
  final String? photoPath;
  final String status;
  final DateTime createdAt;

  const StockReturn({
    required this.id,
    required this.originalBatchId,
    required this.item,
    required this.quantity,
    this.reason = '',
    this.category = StockCategory.other,
    this.unit = 'Nos',
    this.siteId = '',
    this.thavvuPointId = '',
    this.photoPath,
    this.status = 'pending',
    required this.createdAt,
  });

  StockReturn copyWith({String? status}) => StockReturn(
        id: id,
        originalBatchId: originalBatchId,
        item: item,
        quantity: quantity,
        reason: reason,
        category: category,
        unit: unit,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        photoPath: photoPath,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalBatchId': originalBatchId,
        'item': item,
        'quantity': quantity,
        'reason': reason,
        'category': category,
        'unit': unit,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'photoPath': photoPath,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockReturn.fromJson(Map<String, dynamic> j) => StockReturn(
        id: j['id'] as String,
        originalBatchId: j['originalBatchId'] as String,
        item: j['item'] as String,
        quantity: j['quantity'] as int,
        reason: j['reason'] as String? ?? '',
        category: j['category'] as String? ?? StockCategory.other,
        unit: j['unit'] as String? ?? 'Nos',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class TransferRecord {
  final String id;
  final String item;
  final String fromPoint;
  final String toPoint;
  final int quantity;
  final String status; // pending_ack | completed | cancelled
  final String date;
  final String notes;
  final String siteId;
  final String itemCategory;
  final String unit;
  final String? photoPath;
  final DateTime createdAt;

  const TransferRecord({
    required this.id,
    required this.item,
    required this.fromPoint,
    required this.toPoint,
    required this.quantity,
    required this.status,
    required this.date,
    this.notes = '',
    this.siteId = '',
    this.itemCategory = StockCategory.other,
    this.unit = 'Nos',
    this.photoPath,
    required this.createdAt,
  });

  TransferRecord copyWith({String? status}) => TransferRecord(
        id: id,
        item: item,
        fromPoint: fromPoint,
        toPoint: toPoint,
        quantity: quantity,
        status: status ?? this.status,
        date: date,
        notes: notes,
        siteId: siteId,
        itemCategory: itemCategory,
        unit: unit,
        photoPath: photoPath,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'fromPoint': fromPoint,
        'toPoint': toPoint,
        'quantity': quantity,
        'status': status,
        'date': date,
        'notes': notes,
        'siteId': siteId,
        'itemCategory': itemCategory,
        'unit': unit,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TransferRecord.fromJson(Map<String, dynamic> j) => TransferRecord(
        id: j['id'] as String,
        item: j['item'] as String,
        fromPoint: j['fromPoint'] as String,
        toPoint: j['toPoint'] as String,
        quantity: j['quantity'] as int,
        status: j['status'] as String,
        date: j['date'] as String,
        notes: j['notes'] as String? ?? '',
        siteId: j['siteId'] as String? ?? '',
        itemCategory: j['itemCategory'] as String? ?? StockCategory.other,
        unit: j['unit'] as String? ?? 'Nos',
        photoPath: j['photoPath'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class RentalRecord {
  final String id;
  final String item;
  final String billingMode;
  final double rate;
  final double fuel;
  final String notes;
  final String startDate;
  final String? endDate;
  final String status; // active | closed
  final String siteId;
  final String thavvuPointId;
  final String? photoPath;
  final DateTime createdAt;

  const RentalRecord({
    required this.id,
    required this.item,
    required this.billingMode,
    required this.rate,
    this.fuel = 0,
    this.notes = '',
    required this.startDate,
    this.endDate,
    this.status = 'active',
    this.siteId = '',
    this.thavvuPointId = '',
    this.photoPath,
    required this.createdAt,
  });

  RentalRecord copyWith({String? status, String? endDate}) => RentalRecord(
        id: id,
        item: item,
        billingMode: billingMode,
        rate: rate,
        fuel: fuel,
        notes: notes,
        startDate: startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        photoPath: photoPath,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item': item,
        'billingMode': billingMode,
        'rate': rate,
        'fuel': fuel,
        'notes': notes,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RentalRecord.fromJson(Map<String, dynamic> j) => RentalRecord(
        id: j['id'] as String,
        item: j['item'] as String,
        billingMode: j['billingMode'] as String? ?? 'Per day',
        rate: (j['rate'] as num).toDouble(),
        fuel: (j['fuel'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        startDate: j['startDate'] as String,
        endDate: j['endDate'] as String?,
        status: j['status'] as String? ?? 'active',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── Suppliers & payments ─────────────────────────────────────────────────────

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String category; // fuel | parts | general
  final String? siteId;
  final double outstandingBalance;
  final double totalPaid;
  final String notes;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.category = 'general',
    this.siteId,
    this.outstandingBalance = 0,
    this.totalPaid = 0,
    this.notes = '',
    required this.createdAt,
  });

  Supplier copyWith({
    String? name,
    String? phone,
    String? email,
    String? category,
    String? siteId,
    double? outstandingBalance,
    double? totalPaid,
    String? notes,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        category: category ?? this.category,
        siteId: siteId ?? this.siteId,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        totalPaid: totalPaid ?? this.totalPaid,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'category': category,
        'siteId': siteId,
        'outstandingBalance': outstandingBalance,
        'totalPaid': totalPaid,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        category: j['category'] as String? ?? 'general',
        siteId: j['siteId'] as String?,
        outstandingBalance: (j['outstandingBalance'] as num?)?.toDouble() ?? 0,
        totalPaid: (j['totalPaid'] as num?)?.toDouble() ?? 0,
        notes: j['notes'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class SupplierPayment {
  final String id;
  final String supplierId;
  final String supplierName;
  final double amount;
  final String mode; // cash | upi | bank
  final String reference;
  final String relatedModule;
  final String relatedRecordId;
  final String siteId;
  final String thavvuPointId;
  final String notes;
  final String? photoPath;
  final String status; // pending | cleared
  final DateTime createdAt;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.amount,
    this.mode = 'cash',
    this.reference = '',
    this.relatedModule = '',
    this.relatedRecordId = '',
    this.siteId = '',
    this.thavvuPointId = '',
    this.notes = '',
    this.photoPath,
    this.status = 'pending',
    required this.createdAt,
  });

  SupplierPayment copyWith({String? status}) => SupplierPayment(
        id: id,
        supplierId: supplierId,
        supplierName: supplierName,
        amount: amount,
        mode: mode,
        reference: reference,
        relatedModule: relatedModule,
        relatedRecordId: relatedRecordId,
        siteId: siteId,
        thavvuPointId: thavvuPointId,
        notes: notes,
        photoPath: photoPath,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'amount': amount,
        'mode': mode,
        'reference': reference,
        'relatedModule': relatedModule,
        'relatedRecordId': relatedRecordId,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'notes': notes,
        'photoPath': photoPath,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupplierPayment.fromJson(Map<String, dynamic> j) => SupplierPayment(
        id: j['id'] as String,
        supplierId: j['supplierId'] as String,
        supplierName: j['supplierName'] as String,
        amount: (j['amount'] as num).toDouble(),
        mode: j['mode'] as String? ?? 'cash',
        reference: j['reference'] as String? ?? '',
        relatedModule: j['relatedModule'] as String? ?? '',
        relatedRecordId: j['relatedRecordId'] as String? ?? '',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        photoPath: j['photoPath'] as String?,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── Photos & activity ledger ─────────────────────────────────────────────────

class PhotoRecord {
  final String id;
  final String module;
  final String recordId;
  final String label;
  final String path;
  final String siteId;
  final String thavvuPointId;
  final String uploadedBy;
  final DateTime createdAt;

  const PhotoRecord({
    required this.id,
    required this.module,
    required this.recordId,
    required this.label,
    required this.path,
    this.siteId = '',
    this.thavvuPointId = '',
    this.uploadedBy = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'module': module,
        'recordId': recordId,
        'label': label,
        'path': path,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'uploadedBy': uploadedBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhotoRecord.fromJson(Map<String, dynamic> j) => PhotoRecord(
        id: j['id'] as String,
        module: j['module'] as String,
        recordId: j['recordId'] as String,
        label: j['label'] as String? ?? '',
        path: j['path'] as String,
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        uploadedBy: j['uploadedBy'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ActivityEvent {
  final String id;
  // machine_submit | daily_log | attendance | stock_order | stock_return |
  // transfer | rental_open | rental_close | supplier_payment | approval | task
  final String type;
  final String title;
  final String detail;
  final String siteId;
  final String thavvuPointId;
  final String actorName;
  final String actorRole;
  final double? amount;
  final double? quantity;
  final String? unit;
  final Map<String, dynamic> meta;
  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.title,
    this.detail = '',
    this.siteId = '',
    this.thavvuPointId = '',
    this.actorName = '',
    this.actorRole = '',
    this.amount,
    this.quantity,
    this.unit,
    this.meta = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'detail': detail,
        'siteId': siteId,
        'thavvuPointId': thavvuPointId,
        'actorName': actorName,
        'actorRole': actorRole,
        'amount': amount,
        'quantity': quantity,
        'unit': unit,
        'meta': meta,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> j) => ActivityEvent(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        detail: j['detail'] as String? ?? '',
        siteId: j['siteId'] as String? ?? '',
        thavvuPointId: j['thavvuPointId'] as String? ?? '',
        actorName: j['actorName'] as String? ?? '',
        actorRole: j['actorRole'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble(),
        quantity: (j['quantity'] as num?)?.toDouble(),
        unit: j['unit'] as String?,
        meta: (j['meta'] as Map?) != null
            ? Map<String, dynamic>.from(j['meta'] as Map)
            : const {},
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

// ── Tasks, reports, notifications, map ───────────────────────────────────────

class AppTask {
  final String id;
  final String title;
  final String type; // Daily | Weekly | Monthly
  final bool done;
  final String priority;
  final String dueDate;
  final String assignedBy;
  final String source; // checklist | hod
  final String? description;
  final String? siteId;
  final int points;

  const AppTask({
    required this.id,
    required this.title,
    required this.type,
    this.done = false,
    this.priority = 'normal',
    this.dueDate = 'Today',
    this.assignedBy = 'HOD',
    this.source = 'checklist',
    this.description,
    this.siteId,
    this.points = 0,
  });

  AppTask copyWith({bool? done}) => AppTask(
        id: id,
        title: title,
        type: type,
        done: done ?? this.done,
        priority: priority,
        dueDate: dueDate,
        assignedBy: assignedBy,
        source: source,
        description: description,
        siteId: siteId,
        points: points,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'done': done,
        'priority': priority,
        'dueDate': dueDate,
        'assignedBy': assignedBy,
        'source': source,
        'description': description,
        'siteId': siteId,
        'points': points,
      };

  factory AppTask.fromJson(Map<String, dynamic> j) => AppTask(
        id: j['id'] as String,
        title: j['title'] as String,
        type: j['type'] as String,
        done: j['done'] as bool? ?? false,
        priority: j['priority'] as String? ?? 'normal',
        dueDate: j['dueDate'] as String? ?? 'Today',
        assignedBy: j['assignedBy'] as String? ?? 'HOD',
        source: j['source'] as String? ?? 'checklist',
        description: j['description'] as String?,
        siteId: j['siteId'] as String?,
        points: j['points'] as int? ?? 0,
      );
}

class ReportRecord {
  final String id;
  final String title;
  final DateTime date;
  final String size;
  final String type;
  final String status;
  final String period;
  final String summary;

  const ReportRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.size,
    required this.type,
    this.status = 'completed',
    this.period = 'Monthly',
    this.summary = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date.toIso8601String(),
        'size': size,
        'type': type,
        'status': status,
        'period': period,
        'summary': summary,
      };

  factory ReportRecord.fromJson(Map<String, dynamic> j) => ReportRecord(
        id: j['id'] as String,
        title: j['title'] as String,
        date: DateTime.parse(j['date'] as String),
        size: j['size'] as String,
        type: j['type'] as String,
        status: j['status'] as String? ?? 'completed',
        period: j['period'] as String? ?? 'Monthly',
        summary: j['summary'] as String? ?? '',
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type = 'info',
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        type: j['type'] as String? ?? 'info',
        createdAt: DateTime.parse(j['createdAt'] as String),
        read: j['read'] as bool? ?? false,
      );
}

class MapLocation {
  final String id;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final String category;

  const MapLocation({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    this.category = 'site',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'lat': lat,
        'lng': lng,
        'category': category,
      };

  factory MapLocation.fromJson(Map<String, dynamic> j) => MapLocation(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        category: j['category'] as String? ?? 'site',
      );
}
