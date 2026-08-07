/// Shared domain models for the Thavvu Supervisor local backend.

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role;
  final String empId;
  final String site;
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
        phone: j['phone'] as String? ?? '',
        joinDate: j['joinDate'] as String? ?? '',
        approved: j['approved'] as bool? ?? true,
        rememberMe: j['rememberMe'] as bool? ?? false,
      );
}

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
    required this.createdAt,
  });

  String get displayName => '$vehicleType ($machineId)';

  MachineRecord copyWith({String? status}) => MachineRecord(
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
  final List<TimeBlockData> timeBlocks;
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
    this.timeBlocks = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'machineId': machineId,
        'machineName': machineName,
        'usedAmount': usedAmount,
        'dieselAmount': dieselAmount,
        'betaAmount': betaAmount,
        'notes': notes,
        'paymentMode': paymentMode,
        'timeBlocks': timeBlocks.map((e) => e.toJson()).toList(),
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
        timeBlocks: ((j['timeBlocks'] as List?) ?? [])
            .map((e) => TimeBlockData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

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
        date: DateTime.parse(j['date'] as String),
        photoCaptured: j['photoCaptured'] as bool? ?? false,
      );
}

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
      );
}

class StockMovement {
  final String id;
  final String type; // in | out | return | transfer
  final String item;
  final String batch;
  final String date;
  final String by;
  final int quantity;
  final String? stockPointId;

  const StockMovement({
    required this.id,
    required this.type,
    required this.item,
    required this.quantity,
    required this.batch,
    required this.date,
    required this.by,
    this.stockPointId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'item': item,
        'quantity': quantity,
        'batch': batch,
        'date': date,
        'by': by,
        'stockPointId': stockPointId,
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: j['type'] as String,
        item: j['item'] as String,
        quantity: j['quantity'] as int,
        batch: j['batch'] as String,
        date: j['date'] as String,
        by: j['by'] as String,
        stockPointId: j['stockPointId'] as String?,
      );
}

class StockOrder {
  final String id;
  final String stockPointId;
  final String stockPointName;
  final String item;
  final int quantity;
  final String unit;
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
  final String status;
  final DateTime createdAt;

  const StockReturn({
    required this.id,
    required this.originalBatchId,
    required this.item,
    required this.quantity,
    this.reason = '',
    this.status = 'pending',
    required this.createdAt,
  });

  StockReturn copyWith({String? status}) => StockReturn(
        id: id,
        originalBatchId: originalBatchId,
        item: item,
        quantity: quantity,
        reason: reason,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalBatchId': originalBatchId,
        'item': item,
        'quantity': quantity,
        'reason': reason,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockReturn.fromJson(Map<String, dynamic> j) => StockReturn(
        id: j['id'] as String,
        originalBatchId: j['originalBatchId'] as String,
        item: j['item'] as String,
        quantity: j['quantity'] as int,
        reason: j['reason'] as String? ?? '',
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
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

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
