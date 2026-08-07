import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../models/stock_catalog.dart';
import '../services/remote_repository.dart';
import '../services/photo_service.dart';

/// Local backend / application state for Thavvu Supervisor.
/// Persists key collections to SharedPreferences as JSON.
///
/// When a live Supabase Postgres connection is reachable and the signed-in
/// user is a real remote profile (HOD/Supervisor from `app_credentials`),
/// this store additionally hydrates a parallel set of `remote*` collections
/// from [RemoteRepository] and routes key mutations to the backend. The
/// original local/demo collections and workflows are left completely
/// untouched so the app keeps working fully offline (or with the bundled
/// demo account) exactly as before.
class AppStore extends ChangeNotifier {
  static const _storageKey = 'thavvu_app_store_v1';
  static const _sessionKey = 'thavvu_session_email';
  static const _profileKey = 'thavvu_remote_profile';
  static const _activeSiteKey = 'thavvu_active_site_id';
  static const _activePointKey = 'thavvu_active_point_id';

  AppStore({RemoteRepository? remote}) : remote = remote ?? RemoteRepository();

  bool ready = false;
  AppUser? currentUser;

  /// Backend access. See class doc for how remote state layers on top of the
  /// local/offline collections below.
  final RemoteRepository remote;
  bool remoteEnabled = false;
  Profile? currentProfile;
  String? activeSiteId;
  String? activeThavvuPointId;

  // ── Remote-hydrated collections (populated only for a real remote login) ──
  final List<WorkSite> remoteSites = [];
  final List<ThavvuPoint> remoteThavvuPoints = [];
  final List<StockItemDef> remoteStockItems = [];
  final List<StockBalance> remoteStockBalances = [];
  final List<MachineRecord> remoteMachines = [];
  final List<DailyLog> remoteDailyLogs = [];
  final List<StockOrder> remoteStockOrders = [];
  final List<TransferRecord> remoteTransfers = [];
  final List<AppTask> remoteTasks = [];
  final List<Supplier> suppliers = [];
  final List<SupplierPayment> supplierPayments = [];

  final List<AppUser> users = [];
  final List<MachineRecord> machines = [];
  final List<DailyLog> dailyLogs = [];
  final List<Worker> workers = [];
  final List<AttendanceRecord> attendance = [];
  final List<StockPoint> stockPoints = [];
  final List<StockMovement> stockMovements = [];
  final List<StockOrder> stockOrders = [];
  final List<StockReturn> stockReturns = [];
  final List<TransferRecord> transfers = [];
  final List<RentalRecord> rentals = [];
  final List<AppTask> tasks = [];
  final List<ReportRecord> reports = [];
  final List<AppNotification> notifications = [];
  final List<MapLocation> mapLocations = [];

  String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> init() async {
    if (ready) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _seed();
      }
    } else {
      _seed();
    }

    final sessionEmail = prefs.getString(_sessionKey);
    if (sessionEmail != null) {
      try {
        currentUser = users.firstWhere((u) => u.email == sessionEmail && u.approved);
      } catch (_) {
        currentUser = null;
      }
    }

    // Best-effort remote connectivity check. Never blocks local/offline use —
    // any failure (no network, DNS, auth) simply leaves remoteEnabled=false
    // and the app keeps working entirely off the local seed data above.
    try {
      remoteEnabled = await remote.ping().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
    } catch (_) {
      remoteEnabled = false;
    }

    if (remoteEnabled) {
      final profileRaw = prefs.getString(_profileKey);
      if (profileRaw != null) {
        try {
          currentProfile = Profile.fromJson(
            Map<String, dynamic>.from(jsonDecode(profileRaw) as Map),
          );
          activeSiteId = prefs.getString(_activeSiteKey);
          activeThavvuPointId = prefs.getString(_activePointKey);
        } catch (_) {
          currentProfile = null;
        }
      }
      if (currentProfile != null) {
        try {
          await hydrateFromRemote();
        } catch (_) {
          // Keep whatever restored profile/session we have; screens fall
          // back to empty remote lists until connectivity returns.
        }
      }
    }

    ready = true;
    notifyListeners();
  }

  Future<void> _persistRemoteSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (currentProfile == null) {
      await prefs.remove(_profileKey);
      await prefs.remove(_activeSiteKey);
      await prefs.remove(_activePointKey);
      return;
    }
    await prefs.setString(_profileKey, jsonEncode(currentProfile!.toJson()));
    if (activeSiteId != null) {
      await prefs.setString(_activeSiteKey, activeSiteId!);
    }
    if (activeThavvuPointId != null) {
      await prefs.setString(_activePointKey, activeThavvuPointId!);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  Future<void> _setSession(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, email);
    }
  }

  // ── Remote hydration & site/point selection ──────────────────────────────

  bool get isHod => currentProfile?.isHod ?? false;
  bool get isSupervisor => currentProfile == null ? true : currentProfile!.isSupervisor;

  /// Scope for HOD-owned data: the HOD's own id when signed in as HOD, or
  /// their assigned HOD's id when signed in as a supervisor.
  String? get effectiveHodId =>
      currentProfile == null ? null : (currentProfile!.isHod ? currentProfile!.id : currentProfile!.hodId);

  WorkSite _mapSite(Map<String, dynamic> row) => WorkSite(
        id: (row['id'] ?? row['site_id']).toString(),
        name: (row['name'] ?? row['site_name'] ?? '').toString(),
        location: (row['place'] ?? '').toString(),
        code: (row['id'] ?? row['site_id'] ?? '').toString(),
      );

  ThavvuPoint _mapPoint(Map<String, dynamic> row, {String? fallbackSiteId}) => ThavvuPoint(
        id: row['id'].toString(),
        siteId: (row['site_id'] ?? fallbackSiteId ?? '').toString(),
        name: (row['point_name'] ?? '').toString(),
        code: row['id'].toString(),
        type: 'field',
      );

  StockItemDef _mapStockItem(Map<String, dynamic> row) {
    final name = (row['item_name'] ?? row['name'] ?? '').toString();
    final category = (row['category'] ?? row['group_name'] ?? StockCategory.other).toString();
    final unit = (row['primary_uom'] ?? row['uom'] ?? StockCatalog.unitForName(name)).toString();
    return StockItemDef(
      id: (row['code'] ?? row['id'] ?? name).toString(),
      name: name,
      category: category,
      unit: unit,
      reorderLevel: (row['reorder_level'] as num?)?.toDouble() ?? 20,
    );
  }

  StockBalance _mapStockBalance(Map<String, dynamic> row) {
    final name = (row['item_name'] ?? '').toString();
    final unit = unitForItem(name);
    final category = StockCatalog.categoryForName(name);
    return StockBalance(
      stockPointId: (row['stock_point_id'] ?? '').toString(),
      itemId: (row['item_id'] ?? row['item_code'] ?? '').toString(),
      itemName: name,
      category: category,
      unit: unit,
      quantity: (row['available_qty'] as num?)?.toDouble() ?? 0,
    );
  }

  Supplier _mapSupplier(Map<String, dynamic> row) => Supplier(
        id: row['id'].toString(),
        name: (row['name'] ?? '').toString(),
        phone: (row['phone'] ?? '').toString(),
        email: '',
        category: (row['group_name'] ?? 'general').toString(),
        siteId: row['site_id']?.toString(),
        outstandingBalance: 0,
        totalPaid: 0,
        notes: (row['notes'] ?? '').toString(),
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );

  SupplierPayment _mapSupplierPayment(Map<String, dynamic> row) => SupplierPayment(
        id: row['id'].toString(),
        supplierId: '',
        supplierName: (row['supplier_name'] ?? '').toString(),
        amount: (row['amount'] as num?)?.toDouble() ?? 0,
        mode: (row['method'] ?? 'cash').toString(),
        reference: '',
        relatedModule: (row['request_type'] ?? '').toString(),
        siteId: (row['site_id'] ?? '').toString(),
        photoPath: row['payment_proof'] as String?,
        status: (row['status'] ?? 'pending').toString(),
        createdAt: _parseDate(row['requested_at'] ?? row['created_at']) ?? DateTime.now(),
      );

  MachineRecord _mapMachine(Map<String, dynamic> row) => MachineRecord(
        id: row['id'].toString(),
        machineId: row['id'].toString(),
        operatorName: (row['operator_name'] ?? '').toString(),
        vehicleNumber: (row['vehicle_number'] ?? '').toString(),
        vehicleType: (row['vehicle_type'] ?? '').toString(),
        billingType: 'Daily',
        workingAmount: 0,
        status: 'approved',
        siteId: (row['site_id'] ?? '').toString(),
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );

  DailyLog _mapDailyLog(Map<String, dynamic> row) => DailyLog(
        id: row['id'].toString(),
        machineId: (row['machine_id'] ?? '').toString(),
        machineName: (row['machine_id'] ?? '').toString(),
        usedAmount: 0,
        dieselAmount: 0,
        betaAmount: (row['beta_amount'] as num?)?.toDouble() ?? 0,
        notes: (row['notes'] ?? '').toString(),
        siteId: (row['site_id'] ?? '').toString(),
        thavvuPointId: (row['thavvu_point_id'] ?? '').toString(),
        photoPath: row['bill_file_path'] as String?,
        status: (row['status'] ?? 'submitted').toString(),
        hodNote: row['hod_note'] as String?,
        createdAt: _parseDate(row['created_at'] ?? row['log_date']) ?? DateTime.now(),
      );

  StockOrder _mapStockOrder(Map<String, dynamic> row) => StockOrder(
        id: row['id'].toString(),
        stockPointId: (row['stock_point_id'] ?? '').toString(),
        stockPointName: (row['stock_point_name'] ?? '').toString(),
        item: (row['item_name'] ?? '').toString(),
        quantity: ((row['quantity'] as num?) ?? 0).round(),
        unit: (row['unit'] ?? 'Units').toString(),
        category: StockCatalog.categoryForName((row['item_name'] ?? '').toString()),
        siteId: (row['site_id'] ?? '').toString(),
        thavvuPointId: (row['thavvu_point_id'] ?? '').toString(),
        notes: (row['notes'] ?? '').toString(),
        status: (row['status'] ?? 'pending').toString(),
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );

  TransferRecord _mapTransfer(Map<String, dynamic> row) => TransferRecord(
        id: row['id'].toString(),
        item: (row['item_name'] ?? '').toString(),
        fromPoint: (row['from_thavvu_point'] ?? row['from_point'] ?? '').toString(),
        toPoint: (row['to_thavvu_point'] ?? row['to_point'] ?? '').toString(),
        quantity: ((row['quantity'] as num?) ?? 0).round(),
        status: (row['status'] ?? 'pending_ack').toString(),
        date: _fmtDate(_parseDate(row['initiated_at']) ?? DateTime.now()),
        notes: (row['notes'] ?? '').toString(),
        siteId: (row['site_id'] ?? '').toString(),
        unit: (row['unit'] ?? 'Nos').toString(),
        photoPath: row['photo_name'] as String?,
        createdAt: _parseDate(row['initiated_at']) ?? DateTime.now(),
      );

  Worker _mapWorker(Map<String, dynamic> row) => Worker(
        id: row['id'].toString(),
        name: (row['name'] ?? '').toString(),
        department: (row['department'] ?? '').toString(),
        type: (row['is_temporary'] == true) ? 'outside' : 'regular',
        wage: (row['wage'] as num?)?.toDouble(),
        approved: (row['status']?.toString() ?? 'active') != 'inactive',
      );

  ActivityEvent _mapActivityEvent(Map<String, dynamic> row) => ActivityEvent(
        id: row['id'].toString(),
        type: (row['module'] ?? '').toString(),
        title: (row['action'] ?? '').toString(),
        detail: (row['summary'] ?? '').toString(),
        siteId: (row['site_id'] ?? '').toString(),
        thavvuPointId: (row['thavvu_point_id'] ?? '').toString(),
        amount: row['unit'] == 'INR' ? (row['quantity'] as num?)?.toDouble() : null,
        quantity: (row['quantity'] as num?)?.toDouble(),
        unit: row['unit'] as String?,
        createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      );

  DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  /// Resolve the display unit for a stock item name: prefer the live
  /// `remoteStockItems` catalog, then fall back to the bundled
  /// [StockCatalog] so units (Litres/Bags/Kg/etc.) are always sensible.
  String unitForItem(String name) {
    final needle = name.trim().toLowerCase();
    for (final item in remoteStockItems) {
      if (item.name.toLowerCase() == needle) return item.unit;
    }
    return StockCatalog.unitForName(name);
  }

  /// Stock catalog (remote when available, else the bundled catalog),
  /// grouped by category for the "view by category" stock screens.
  Map<String, List<StockItemDef>> get stockItemsByCategory {
    final source = remoteStockItems.isNotEmpty ? remoteStockItems : StockCatalog.items;
    final grouped = <String, List<StockItemDef>>{};
    for (final item in source) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }

  /// Remote stock balances scoped to the active Thavvu Point; falls back to
  /// every remote balance known when no point is selected yet.
  List<StockBalance> get balancesForActivePoint {
    if (activeThavvuPointId == null) return remoteStockBalances;
    final scoped = remoteStockBalances
        .where((b) => b.stockPointId == activeThavvuPointId)
        .toList();
    return scoped.isEmpty ? remoteStockBalances : scoped;
  }

  Future<void> setActiveSite(String siteId) async {
    if (activeSiteId == siteId) return;
    activeSiteId = siteId;
    activeThavvuPointId = null;
    await _loadPointsForActiveSite();
    if (remoteThavvuPoints.isNotEmpty) {
      activeThavvuPointId = remoteThavvuPoints.first.id;
    }
    await _persistRemoteSession();
    try {
      await hydrateFromRemote();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setActiveThavvuPoint(String pointId) async {
    if (activeThavvuPointId == pointId) return;
    activeThavvuPointId = pointId;
    await _persistRemoteSession();
    try {
      await hydrateFromRemote();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _loadPointsForActiveSite() async {
    remoteThavvuPoints.clear();
    if (activeSiteId == null) return;
    try {
      final rows = await remote.thavvuPointsForSite(activeSiteId!);
      remoteThavvuPoints.addAll(rows.map((r) => _mapPoint(r, fallbackSiteId: activeSiteId)));
    } catch (_) {}
  }

  /// Loads sites/points/stock/suppliers/machines/logs/orders/transfers/tasks
  /// scoped to the current remote profile + active site/point. Every fetch
  /// is independent and best-effort so a single failing table never blocks
  /// the rest of the dashboard from loading.
  Future<void> hydrateFromRemote() async {
    if (!remoteEnabled || currentProfile == null) return;
    final hodId = effectiveHodId;

    try {
      List<Map<String, dynamic>> siteRows;
      if (currentProfile!.isHod) {
        siteRows = await remote.allSites(hodId: hodId);
      } else {
        final pts = await remote.pointsForSupervisor(currentProfile!.id);
        final seen = <String>{};
        siteRows = [];
        for (final p in pts) {
          final sid = p['site_id']?.toString();
          if (sid == null || !seen.add(sid)) continue;
          siteRows.add({'id': sid, 'name': p['site_name']});
        }
        if (siteRows.isEmpty) siteRows = await remote.allSites(hodId: hodId);
      }
      remoteSites
        ..clear()
        ..addAll(siteRows.map(_mapSite));
    } catch (_) {}

    activeSiteId ??= remoteSites.isNotEmpty ? remoteSites.first.id : null;
    if (activeSiteId != null && remoteThavvuPoints.isEmpty) {
      await _loadPointsForActiveSite();
    }
    activeThavvuPointId ??= remoteThavvuPoints.isNotEmpty ? remoteThavvuPoints.first.id : null;

    try {
      final rows = await remote.stockItems();
      remoteStockItems
        ..clear()
        ..addAll(rows.map(_mapStockItem));
    } catch (_) {}

    try {
      final rows = await remote.stockBalances(thavvuPointId: activeThavvuPointId, hodId: hodId);
      remoteStockBalances
        ..clear()
        ..addAll(rows.map(_mapStockBalance));
    } catch (_) {}

    try {
      final rows = await remote.suppliers(siteId: activeSiteId, hodId: hodId);
      suppliers
        ..clear()
        ..addAll(rows.map(_mapSupplier));
    } catch (_) {}

    try {
      final rows = await remote.supplierPaymentRequests(siteId: activeSiteId, hodId: hodId);
      supplierPayments
        ..clear()
        ..addAll(rows.map(_mapSupplierPayment));
    } catch (_) {}

    try {
      final rows = await remote.machines(siteId: activeSiteId, hodId: hodId);
      remoteMachines
        ..clear()
        ..addAll(rows.map(_mapMachine));
    } catch (_) {}

    try {
      final rows = await remote.dailyLogs(siteId: activeSiteId, thavvuPointId: activeThavvuPointId, hodId: hodId);
      remoteDailyLogs
        ..clear()
        ..addAll(rows.map(_mapDailyLog));
    } catch (_) {}

    try {
      final rows = await remote.stockOrders(siteId: activeSiteId, thavvuPointId: activeThavvuPointId, hodId: hodId);
      remoteStockOrders
        ..clear()
        ..addAll(rows.map(_mapStockOrder));
    } catch (_) {}

    try {
      final rows = await remote.stockTransfers(siteId: activeSiteId, thavvuPointId: activeThavvuPointId, hodId: hodId);
      remoteTransfers
        ..clear()
        ..addAll(rows.map(_mapTransfer));
    } catch (_) {}

    try {
      final rows = await remote.workers(siteId: activeSiteId, thavvuPointId: activeThavvuPointId);
      // Merge (don't replace) so the bundled demo workers stay usable offline
      // while real DB workers become selectable — and, crucially, carry real
      // UUIDs so `markAttendance` can sync to the remote `attendance_records`.
      for (final row in rows) {
        final mapped = _mapWorker(row);
        final idx = workers.indexWhere((w) => w.id == mapped.id);
        if (idx >= 0) {
          workers[idx] = mapped;
        } else {
          workers.add(mapped);
        }
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Fetches a fresh activity feed for the Reports screen. Not cached on the
  /// store so callers can apply their own module/date filters live.
  Future<List<ActivityEvent>> loadActivityReport({
    String? module,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!remoteEnabled) return [];
    try {
      final rows = await remote.activityReport(
        siteId: activeSiteId,
        thavvuPointId: activeThavvuPointId,
        module: module,
        from: from,
        to: to,
        hodId: effectiveHodId,
      );
      return rows.map(_mapActivityEvent).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Supplier payments (remote-first; no local/offline equivalent) ───────

  Future<Map<String, dynamic>?> requestSupplierPayment({
    required String supplierName,
    required double amount,
    String method = 'upi',
    double? billAmount,
    double? usedAmount,
    String? photoPath,
  }) async {
    if (!remoteEnabled || currentProfile == null || activeSiteId == null) {
      return null;
    }
    try {
      final row = await remote.requestSupplierPayment(
        siteId: activeSiteId!,
        supplierName: supplierName,
        amount: amount,
        billAmount: billAmount,
        usedAmount: usedAmount,
        method: method,
        paymentProof: photoPath,
        hodId: effectiveHodId,
      );
      supplierPayments.insert(0, _mapSupplierPayment(row));
      await _addNotification(
        'Payment Requested',
        '₹${amount.toStringAsFixed(0)} to $supplierName ($method)',
        type: 'warning',
      );
      notifyListeners();
      return row;
    } catch (_) {
      return null;
    }
  }

  Future<void> reviewSupplierPayment(String requestId, String status) async {
    if (!remoteEnabled) return;
    try {
      await remote.reviewSupplierPayment(
        requestId: requestId,
        status: status,
        hodId: effectiveHodId,
      );
      final idx = supplierPayments.indexWhere((p) => p.id == requestId);
      if (idx >= 0) {
        supplierPayments[idx] = supplierPayments[idx].copyWith(status: status);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── HOD approvals over remote-hydrated collections ───────────────────────

  Future<void> reviewRemoteDailyLog(String logId, String status, {String? hodNote}) async {
    if (!remoteEnabled) return;
    try {
      await remote.reviewDailyLog(logId: logId, status: status, hodNote: hodNote, hodId: effectiveHodId);
      final idx = remoteDailyLogs.indexWhere((l) => l.id == logId);
      if (idx >= 0) {
        remoteDailyLogs[idx] = remoteDailyLogs[idx].copyWith(status: status, hodNote: hodNote);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> reviewRemoteStockOrder(String orderId, String status) async {
    if (!remoteEnabled) return;
    try {
      await remote.reviewStockOrder(orderId: orderId, status: status, hodId: effectiveHodId);
      final idx = remoteStockOrders.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        remoteStockOrders[idx] = remoteStockOrders[idx].copyWith(status: status);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> acknowledgeRemoteTransfer(String transferId) async {
    if (!remoteEnabled) return;
    try {
      await remote.acknowledgeTransfer(transferId: transferId, receivedBy: currentProfile?.email, hodId: effectiveHodId);
      final idx = remoteTransfers.indexWhere((t) => t.id == transferId);
      if (idx >= 0) {
        remoteTransfers[idx] = remoteTransfers[idx].copyWith(status: 'completed');
      }
      try {
        final rows = await remote.stockBalances(thavvuPointId: activeThavvuPointId, hodId: effectiveHodId);
        remoteStockBalances
          ..clear()
          ..addAll(rows.map(_mapStockBalance));
      } catch (_) {}
      notifyListeners();
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> initiateRemoteTransfer({
    required String fromPointId,
    required String fromPoint,
    required String toPointId,
    required String toPoint,
    required String itemName,
    required num quantity,
    required String unit,
    String notes = '',
    String? photoPath,
  }) async {
    if (!remoteEnabled || currentProfile == null || activeSiteId == null) {
      return null;
    }
    try {
      final row = await remote.initiateTransfer(
        siteId: activeSiteId!,
        fromPointId: fromPointId,
        fromPoint: fromPoint,
        toPointId: toPointId,
        toPoint: toPoint,
        itemName: itemName,
        quantity: quantity,
        unit: unit,
        notes: notes,
        photoName: photoPath,
        initiatedBy: currentProfile!.email,
        hodId: effectiveHodId,
        thavvuPointId: activeThavvuPointId,
      );
      if (row != null) {
        remoteTransfers.insert(0, _mapTransfer(row));
        notifyListeners();
      }
      return row;
    } catch (_) {
      return null;
    }
  }

  // ── Photo capture + remote registration ──────────────────────────────────

  /// Captures/picks a photo via [PhotoService] and, when a remote session is
  /// active, best-effort registers it in `app_photo_uploads`. Always returns
  /// the local file path (or null if the user cancelled) regardless of
  /// remote connectivity so forms keep working offline.
  Future<String?> capturePhoto({required String module, required String label}) async {
    final path = await PhotoService.instance.capture(module: module, label: label);
    if (path == null) return null;
    if (remoteEnabled && currentProfile != null) {
      try {
        await remote.registerPhoto(
          module: module,
          label: label,
          localPath: path,
          siteId: activeSiteId,
          thavvuPointId: activeThavvuPointId,
          uploadedBy: currentProfile!.id,
          hodId: effectiveHodId,
        );
      } catch (_) {}
    }
    return path;
  }

  Map<String, dynamic> _toJson() => {
        'users': users.map((e) => e.toJson()).toList(),
        'machines': machines.map((e) => e.toJson()).toList(),
        'dailyLogs': dailyLogs.map((e) => e.toJson()).toList(),
        'workers': workers.map((e) => e.toJson()).toList(),
        'attendance': attendance.map((e) => e.toJson()).toList(),
        'stockPoints': stockPoints.map((e) => e.toJson()).toList(),
        'stockMovements': stockMovements.map((e) => e.toJson()).toList(),
        'stockOrders': stockOrders.map((e) => e.toJson()).toList(),
        'stockReturns': stockReturns.map((e) => e.toJson()).toList(),
        'transfers': transfers.map((e) => e.toJson()).toList(),
        'rentals': rentals.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'reports': reports.map((e) => e.toJson()).toList(),
        'notifications': notifications.map((e) => e.toJson()).toList(),
        'mapLocations': mapLocations.map((e) => e.toJson()).toList(),
      };

  void _loadFromJson(Map<String, dynamic> j) {
    users
      ..clear()
      ..addAll(((j['users'] as List?) ?? [])
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map))));
    machines
      ..clear()
      ..addAll(((j['machines'] as List?) ?? [])
          .map((e) => MachineRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    dailyLogs
      ..clear()
      ..addAll(((j['dailyLogs'] as List?) ?? [])
          .map((e) => DailyLog.fromJson(Map<String, dynamic>.from(e as Map))));
    workers
      ..clear()
      ..addAll(((j['workers'] as List?) ?? [])
          .map((e) => Worker.fromJson(Map<String, dynamic>.from(e as Map))));
    attendance
      ..clear()
      ..addAll(((j['attendance'] as List?) ?? [])
          .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    stockPoints
      ..clear()
      ..addAll(((j['stockPoints'] as List?) ?? [])
          .map((e) => StockPoint.fromJson(Map<String, dynamic>.from(e as Map))));
    stockMovements
      ..clear()
      ..addAll(((j['stockMovements'] as List?) ?? [])
          .map((e) => StockMovement.fromJson(Map<String, dynamic>.from(e as Map))));
    stockOrders
      ..clear()
      ..addAll(((j['stockOrders'] as List?) ?? [])
          .map((e) => StockOrder.fromJson(Map<String, dynamic>.from(e as Map))));
    stockReturns
      ..clear()
      ..addAll(((j['stockReturns'] as List?) ?? [])
          .map((e) => StockReturn.fromJson(Map<String, dynamic>.from(e as Map))));
    transfers
      ..clear()
      ..addAll(((j['transfers'] as List?) ?? [])
          .map((e) => TransferRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    rentals
      ..clear()
      ..addAll(((j['rentals'] as List?) ?? [])
          .map((e) => RentalRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    tasks
      ..clear()
      ..addAll(((j['tasks'] as List?) ?? [])
          .map((e) => AppTask.fromJson(Map<String, dynamic>.from(e as Map))));
    reports
      ..clear()
      ..addAll(((j['reports'] as List?) ?? [])
          .map((e) => ReportRecord.fromJson(Map<String, dynamic>.from(e as Map))));
    notifications
      ..clear()
      ..addAll(((j['notifications'] as List?) ?? [])
          .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map))));
    mapLocations
      ..clear()
      ..addAll(((j['mapLocations'] as List?) ?? [])
          .map((e) => MapLocation.fromJson(Map<String, dynamic>.from(e as Map))));

    if (users.isEmpty || stockPoints.isEmpty) {
      _seed();
    }
  }

  void _seed() {
    users
      ..clear()
      ..add(const AppUser(
        id: 'USR-001',
        name: 'Rajesh Kumar',
        email: 'rajesh@thavvu.com',
        password: 'password',
        role: 'Senior Supervisor',
        empId: 'EMP-001',
        site: 'Site A – Chennai North',
        phone: '+91 98765 43210',
        joinDate: '12 Jan 2022',
      ));

    machines
      ..clear()
      ..addAll([
        MachineRecord(
          id: 'MR-001',
          machineId: 'MCH-001',
          operatorName: 'Suresh',
          vehicleNumber: 'TN-01-AB-1234',
          vehicleType: 'Excavator',
          billingType: 'Hourly',
          workingAmount: 2500,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        MachineRecord(
          id: 'MR-002',
          machineId: 'MCH-002',
          operatorName: 'Anil',
          vehicleNumber: 'TN-02-CD-5678',
          vehicleType: 'Loader',
          billingType: 'Daily',
          workingAmount: 4000,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 8)),
        ),
        MachineRecord(
          id: 'MR-003',
          machineId: 'MCH-003',
          operatorName: 'Vikram',
          vehicleNumber: 'TN-03-EF-9012',
          vehicleType: 'Crane',
          billingType: 'Hourly',
          workingAmount: 3500,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        MachineRecord(
          id: 'MR-004',
          machineId: 'MCH-004',
          operatorName: 'Ravi',
          vehicleNumber: 'TN-04-GH-3456',
          vehicleType: 'Dump Truck',
          billingType: 'Daily',
          workingAmount: 2800,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        MachineRecord(
          id: 'MR-005',
          machineId: 'MCH-005',
          operatorName: 'Kumar',
          vehicleNumber: 'TN-05-IJ-7890',
          vehicleType: 'Compactor',
          billingType: 'Hourly',
          workingAmount: 1800,
          status: 'approved',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ]);

    workers
      ..clear()
      ..addAll(const [
        Worker(id: 'ATT-001', name: 'John Doe', department: 'Operations'),
        Worker(id: 'ATT-002', name: 'Jane Smith', department: 'Maintenance'),
        Worker(id: 'ATT-003', name: 'Robert Johnson', department: 'Logistics'),
        Worker(id: 'ATT-004', name: 'Priya Nair', department: 'Operations'),
        Worker(id: 'OUT-001', name: 'Karthik R', department: 'Contract', type: 'outside', wage: 800),
        Worker(id: 'OUT-002', name: 'Mani S', department: 'Contract', type: 'outside', wage: 750),
      ]);

    stockPoints
      ..clear()
      ..addAll(const [
        StockPoint(id: 'SP-001', name: 'Site A — North', location: 'North Block', batchId: 'B-042', onHand: 450, todayUsage: 12, reorderLevel: 20, totalIn: 750, totalOut: 300),
        StockPoint(id: 'SP-002', name: 'Site B — South', location: 'South Block', batchId: 'B-039', onHand: 200, todayUsage: 8, reorderLevel: 30, totalIn: 400, totalOut: 200),
        StockPoint(id: 'SP-003', name: 'Warehouse Main', location: 'Central Store', batchId: 'B-031', onHand: 18, todayUsage: 5, reorderLevel: 20, totalIn: 600, totalOut: 582),
        StockPoint(id: 'SP-004', name: 'Field Store', location: 'Field Office', batchId: 'B-044', onHand: 120, todayUsage: 20, reorderLevel: 15, totalIn: 300, totalOut: 180),
      ]);

    stockMovements
      ..clear()
      ..addAll([
        StockMovement(id: 'SM-001', type: 'in', item: 'Diesel', quantity: 80, batch: 'B-042', date: 'Today 9:10 AM', by: 'HOD Approved', stockPointId: 'SP-001'),
        StockMovement(id: 'SM-002', type: 'out', item: 'Diesel', quantity: 12, batch: 'B-042', date: 'Today 11:30 AM', by: 'MCH-001', stockPointId: 'SP-001'),
        StockMovement(id: 'SM-003', type: 'in', item: 'Engine Oil', quantity: 20, batch: 'B-041', date: 'Yesterday', by: 'HOD Approved', stockPointId: 'SP-002'),
        StockMovement(id: 'SM-004', type: 'return', item: 'Bolts & Nuts', quantity: 5, batch: 'B-038', date: '12 May', by: 'RET-0089', stockPointId: 'SP-003'),
        StockMovement(id: 'SM-005', type: 'transfer', item: 'Hydraulic Fluid', quantity: 10, batch: 'B-040', date: '11 May', by: 'SP-001→SP-002'),
      ]);

    transfers
      ..clear()
      ..addAll([
        TransferRecord(id: 'TRF-001', item: 'Diesel', fromPoint: 'Site A — North', toPoint: 'Site B — South', quantity: 50, status: 'completed', date: '12 May 2024', createdAt: DateTime.now().subtract(const Duration(days: 2))),
        TransferRecord(id: 'TRF-002', item: 'Engine Oil', fromPoint: 'Warehouse Main', toPoint: 'Field Store', quantity: 10, status: 'completed', date: '11 May 2024', createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ]);

    rentals
      ..clear()
      ..addAll([
        RentalRecord(id: 'RNT-2024-0034', item: 'Excavator', billingMode: 'Per day', rate: 5000, fuel: 1200, startDate: '2024-05-01', createdAt: DateTime.now().subtract(const Duration(days: 12))),
        RentalRecord(id: 'RNT-2024-0035', item: 'Compressor', billingMode: 'Per day', rate: 3000, fuel: 800, startDate: '2024-05-05', createdAt: DateTime.now().subtract(const Duration(days: 8))),
        RentalRecord(id: 'RNT-2024-0036', item: 'Generator', billingMode: 'Per day', rate: 4000, fuel: 1500, startDate: '2024-05-10', createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ]);

    tasks
      ..clear()
      ..addAll(const [
        AppTask(id: 'TSK-001', title: 'Check diesel levels at Site A', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-002', title: 'Update machine log for MCH-003', type: 'Daily', done: true, priority: 'normal', dueDate: 'Yesterday', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-003', title: 'Verify operator attendance photos', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Patel', source: 'checklist'),
        AppTask(id: 'TSK-004', title: 'Submit weekly stock summary', type: 'Weekly', done: false, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-005', title: 'Calibrate equipment at Site B', type: 'Weekly', done: true, priority: 'high', dueDate: 'This Week', assignedBy: 'HOD Mehta', source: 'checklist'),
        AppTask(id: 'TSK-006', title: 'Review rental records', type: 'Monthly', done: false, priority: 'normal', dueDate: 'End of Month', assignedBy: 'HOD Sharma', source: 'checklist'),
        AppTask(id: 'TSK-007', title: 'Conduct safety inspection', type: 'Weekly', done: false, priority: 'high', dueDate: 'Tomorrow', assignedBy: 'HOD Patel', source: 'checklist'),
        AppTask(id: 'TSK-008', title: 'Update stock register', type: 'Daily', done: false, priority: 'normal', dueDate: 'Today', assignedBy: 'HOD Mehta', source: 'checklist'),
        AppTask(id: 'HT-001', title: 'Complete safety inspection at Site A', type: 'Daily', done: false, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Sharma', source: 'hod', description: 'Inspect all safety equipment and submit report', points: 50),
        AppTask(id: 'HT-002', title: 'Submit weekly fuel consumption report', type: 'Weekly', done: false, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Sharma', source: 'hod', description: 'Compile diesel usage data from all machines', points: 30),
        AppTask(id: 'HT-003', title: 'Update machine maintenance log', type: 'Daily', done: true, priority: 'high', dueDate: 'Today', assignedBy: 'HOD Patel', source: 'hod', description: 'Record all maintenance activities for MCH-003', points: 40),
        AppTask(id: 'HT-004', title: 'Monthly stock audit', type: 'Monthly', done: false, priority: 'normal', dueDate: 'End of Month', assignedBy: 'HOD Mehta', source: 'hod', description: 'Verify physical stock with system records', points: 100),
        AppTask(id: 'HT-005', title: 'Site B equipment calibration', type: 'Weekly', done: false, priority: 'high', dueDate: 'Tomorrow', assignedBy: 'HOD Sharma', source: 'hod', description: 'Calibrate all heavy equipment at Site B', points: 75),
        AppTask(id: 'HT-006', title: 'Submit worker attendance summary', type: 'Weekly', done: true, priority: 'normal', dueDate: 'This Week', assignedBy: 'HOD Patel', source: 'hod', description: 'Weekly attendance report for all workers', points: 25),
      ]);

    reports
      ..clear()
      ..addAll([
        ReportRecord(id: 'RPT-001', title: 'Machines Summary', date: DateTime(2024, 5, 13), size: '2.4 MB', type: 'PDF', summary: 'Seed report'),
        ReportRecord(id: 'RPT-002', title: 'Workers Report', date: DateTime(2024, 5, 12), size: '1.8 MB', type: 'PDF', summary: 'Seed report'),
        ReportRecord(id: 'RPT-003', title: 'Diesel Consumption', date: DateTime(2024, 5, 11), size: '1.2 MB', type: 'Excel', summary: 'Seed report'),
        ReportRecord(id: 'RPT-004', title: 'Rental Summary', date: DateTime(2024, 5, 10), size: '892 KB', type: 'PDF', status: 'pending', summary: 'Seed report'),
      ]);

    notifications
      ..clear()
      ..addAll([
        AppNotification(id: 'N-001', title: 'HOD Approval Needed', body: '2 machine entries await HOD review', type: 'warning', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
        AppNotification(id: 'N-002', title: 'Low Stock Alert', body: 'Warehouse Main is below reorder level', type: 'danger', createdAt: DateTime.now().subtract(const Duration(hours: 5))),
        AppNotification(id: 'N-003', title: 'Task Due Today', body: 'Check diesel levels at Site A', type: 'info', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
      ]);

    mapLocations
      ..clear()
      ..addAll(const [
        MapLocation(id: 'LOC-001', title: 'Site A – North', description: 'Main excavation zone', lat: 13.0827, lng: 80.2707, category: 'site'),
        MapLocation(id: 'LOC-002', title: 'Site B – South', description: 'Secondary operations', lat: 13.0500, lng: 80.2500, category: 'site'),
        MapLocation(id: 'LOC-003', title: 'Warehouse Main', description: 'Central store & diesel', lat: 13.1000, lng: 80.2900, category: 'warehouse'),
        MapLocation(id: 'LOC-004', title: 'Field Office', description: 'Supervisor cabin', lat: 13.0700, lng: 80.2600, category: 'office'),
      ]);

    dailyLogs.clear();
    attendance.clear();
    stockOrders.clear();
    stockReturns.clear();
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> login(String email, String password, {bool remember = false}) async {
    // Remote-first: real HOD/Supervisor profiles live in Supabase Postgres
    // (`profiles` + `app_credentials`). Any failure here (network, wrong
    // remote password, unknown email) falls through to the local/demo
    // account check below so the bundled seed data keeps working offline.
    if (remoteEnabled) {
      try {
        final row = await remote.login(email, password);
        if (row != null) {
          final profile = Profile.fromRow(row);
          currentProfile = profile;
          activeSiteId = null;
          activeThavvuPointId = null;
          remoteSites.clear();
          remoteThavvuPoints.clear();
          await hydrateFromRemote();
          currentUser = AppUser(
            id: profile.id,
            name: profile.name.isNotEmpty ? profile.name : profile.email,
            email: profile.email,
            password: '',
            role: profile.isHod ? 'HOD' : 'Supervisor',
            empId: profile.empId,
            site: remoteSites.isNotEmpty ? remoteSites.first.name : '',
            siteId: activeSiteId ?? '',
            phone: profile.phone,
            joinDate: '',
            approved: true,
            rememberMe: remember,
          );
          await _persistRemoteSession();
          if (remember) {
            await _setSession(email.trim());
          } else {
            await _setSession(null);
          }
          notifyListeners();
          return null;
        }
      } catch (_) {
        // Fall through to local/demo login below.
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    AppUser? user;
    try {
      user = users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase() && u.password == password,
      );
    } catch (_) {
      return 'Invalid email or password';
    }
    if (!user.approved) return 'Account pending HOD approval';
    currentUser = user.copyWith(rememberMe: remember);
    if (remember) {
      await _setSession(user.email);
    } else {
      await _setSession(null);
    }
    notifyListeners();
    return null;
  }

  Future<String?> createAccount({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (users.any((u) => u.email.toLowerCase() == email.toLowerCase())) {
      return 'Email already registered';
    }
    final user = AppUser(
      id: _nextId('USR'),
      name: name,
      email: email,
      password: password,
      phone: phone,
      empId: 'EMP-${users.length + 1}'.padLeft(7, '0'),
      joinDate: _fmtDate(DateTime.now()),
      approved: false,
    );
    users.add(user);
    await _addNotification(
      'New Account Request',
      '$name requested supervisor access',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return null;
  }

  Future<String?> requestPasswordReset(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final exists = users.any((u) => u.email.toLowerCase() == email.toLowerCase());
    if (!exists) return 'No account found for that email';
    await _addNotification(
      'Password Reset',
      'Reset link prepared for $email (demo: use password)',
      type: 'info',
    );
    await _persist();
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    currentProfile = null;
    activeSiteId = null;
    activeThavvuPointId = null;
    remoteSites.clear();
    remoteThavvuPoints.clear();
    remoteStockItems.clear();
    remoteStockBalances.clear();
    remoteMachines.clear();
    remoteDailyLogs.clear();
    remoteStockOrders.clear();
    remoteTransfers.clear();
    remoteTasks.clear();
    suppliers.clear();
    supplierPayments.clear();
    await _setSession(null);
    await _persistRemoteSession();
    notifyListeners();
  }

  Future<void> approvePendingUsers() async {
    for (var i = 0; i < users.length; i++) {
      if (!users[i].approved) {
        users[i] = users[i].copyWith(approved: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  // ── Machines ──────────────────────────────────────────────────────────────

  List<MachineRecord> get approvedMachines =>
      machines.where((m) => m.status == 'approved').toList();

  List<MachineRecord> get pendingMachines =>
      machines.where((m) => m.status == 'pending').toList();

  Future<MachineRecord> submitMachine({
    required String machineId,
    required String operatorName,
    required String vehicleNumber,
    required String vehicleType,
    required String billingType,
    required double workingAmount,
    String paymentMode = 'cash',
    double dieselAmount = 0,
    double usedAmount = 0,
    String? dieselInclusion,
    String supplierName = '',
    double supplierAmount = 0,
    String notes = '',
    String? photoPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final record = MachineRecord(
      id: _nextId('MR'),
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
      status: 'pending',
      photoPath: photoPath,
      createdAt: DateTime.now(),
    );
    machines.insert(0, record);
    await _addNotification(
      'Machine Submitted',
      '$machineId ($vehicleType) awaiting HOD approval',
      type: 'warning',
    );
    await _persist();

    if (remoteEnabled && currentProfile != null && activeSiteId != null) {
      try {
        await remote.submitMachine(
          siteId: activeSiteId!,
          machineName: vehicleType,
          vehicleNumber: vehicleNumber,
          vehicleType: vehicleType,
          operatorName: operatorName,
          createdBy: currentProfile!.id,
          hodId: effectiveHodId,
          openingPhotoPath: photoPath,
        );
        final rows = await remote.machines(siteId: activeSiteId, hodId: effectiveHodId);
        remoteMachines
          ..clear()
          ..addAll(rows.map(_mapMachine));
      } catch (_) {}
    }

    notifyListeners();
    return record;
  }

  Future<void> approveMachine(String id) async {
    final idx = machines.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    machines[idx] = machines[idx].copyWith(status: 'approved');
    await _addNotification(
      'Machine Approved',
      '${machines[idx].machineId} is now available for daily logs',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  Future<void> approveAllPendingMachines() async {
    for (var i = 0; i < machines.length; i++) {
      if (machines[i].status == 'pending') {
        machines[i] = machines[i].copyWith(status: 'approved');
      }
    }
    await _persist();
    notifyListeners();
  }

  // ── Daily logs ────────────────────────────────────────────────────────────

  Future<DailyLog> saveDailyLog({
    required String machineId,
    required String machineName,
    required double usedAmount,
    double dieselAmount = 0,
    double betaAmount = 0,
    String notes = '',
    String paymentMode = 'cash',
    List<TimeBlockData> timeBlocks = const [],
    String? photoPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final log = DailyLog(
      id: _nextId('DL'),
      machineId: machineId,
      machineName: machineName,
      usedAmount: usedAmount,
      dieselAmount: dieselAmount,
      betaAmount: betaAmount,
      notes: notes,
      paymentMode: paymentMode,
      timeBlocks: timeBlocks,
      photoPath: photoPath,
      siteId: activeSiteId ?? '',
      thavvuPointId: activeThavvuPointId ?? '',
      createdAt: DateTime.now(),
    );
    dailyLogs.insert(0, log);
    await _addNotification(
      'Daily Log Saved',
      'Log for $machineName recorded',
      type: 'success',
    );
    await _persist();

    if (remoteEnabled && currentProfile != null && activeSiteId != null && activeThavvuPointId != null) {
      try {
        await remote.saveDailyLog(
          siteId: activeSiteId!,
          thavvuPointId: activeThavvuPointId!,
          machineId: machineId,
          supervisorId: currentProfile!.id,
          workingHours: usedAmount,
          betaAmount: betaAmount,
          dieselOption: dieselAmount > 0 ? 'with_diesel' : 'without_diesel',
          notes: notes,
          billFilePath: photoPath,
          hodId: effectiveHodId,
        );
        final rows = await remote.dailyLogs(
          siteId: activeSiteId,
          thavvuPointId: activeThavvuPointId,
          hodId: effectiveHodId,
        );
        remoteDailyLogs
          ..clear()
          ..addAll(rows.map(_mapDailyLog));
      } catch (_) {}
    }

    notifyListeners();
    return log;
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  List<Worker> get regularWorkers =>
      workers.where((w) => w.type == 'regular' && w.approved).toList();

  List<Worker> get outsideWorkers =>
      workers.where((w) => w.type == 'outside' && w.approved).toList();

  int get presentTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Present')
        .length;
  }

  int get absentTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Absent')
        .length;
  }

  int get halfDayTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Half Day')
        .length;
  }

  int get leaveTodayCount {
    final today = DateTime.now();
    return attendance
        .where((a) =>
            a.date.year == today.year &&
            a.date.month == today.month &&
            a.date.day == today.day &&
            a.status == 'Leave')
        .length;
  }

  Future<AttendanceRecord> markAttendance({
    required String workerId,
    required String status,
    bool morning = false,
    bool evening = false,
    String method = 'Manual',
    bool photoCaptured = false,
    String? photoPath,
  }) async {
    final worker = workers.firstWhere((w) => w.id == workerId);
    final record = AttendanceRecord(
      id: _nextId('AT'),
      workerId: workerId,
      workerName: worker.name,
      workerType: worker.type,
      status: status,
      morning: morning,
      evening: evening,
      method: method,
      photoPath: photoPath,
      siteId: activeSiteId ?? '',
      date: DateTime.now(),
      photoCaptured: photoCaptured,
    );
    attendance.insert(0, record);
    await _persist();

    if (remoteEnabled && currentProfile != null && activeSiteId != null && activeThavvuPointId != null) {
      try {
        await remote.markAttendance(
          siteId: activeSiteId!,
          thavvuPointId: activeThavvuPointId!,
          workerId: workerId,
          status: status,
          method: method,
          photoUrl: photoPath,
          markedBy: currentProfile!.id,
          hodId: effectiveHodId,
        );
      } catch (_) {}
    }

    notifyListeners();
    return record;
  }

  Future<Worker> createOutsideWorker({
    required String name,
    required double wage,
    String department = 'Contract',
  }) async {
    final worker = Worker(
      id: _nextId('OUT'),
      name: name,
      department: department,
      type: 'outside',
      wage: wage,
      approved: true, // demo: auto-approve so dropdown updates immediately
    );
    workers.add(worker);
    await _addNotification(
      'Outside Worker Added',
      '$name profile created',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return worker;
  }

  // ── Stock ─────────────────────────────────────────────────────────────────

  Future<StockOrder> raiseStockOrder({
    required String stockPointId,
    required String item,
    required int quantity,
    String? unit,
    String notes = '',
    bool voiceNote = false,
    String? photoPath,
  }) async {
    final point = stockPoints.firstWhere((p) => p.id == stockPointId);
    final resolvedUnit = unit ?? unitForItem(item);
    final order = StockOrder(
      id: _nextId('ORD'),
      stockPointId: stockPointId,
      stockPointName: point.name,
      item: item,
      quantity: quantity,
      unit: resolvedUnit,
      category: StockCatalog.categoryForName(item),
      notes: notes,
      voiceNote: voiceNote,
      photoPath: photoPath,
      siteId: activeSiteId ?? '',
      thavvuPointId: activeThavvuPointId ?? '',
      createdAt: DateTime.now(),
    );
    stockOrders.insert(0, order);
    await _addNotification(
      'Stock Order Raised',
      '$item x$quantity for ${point.name}',
      type: 'warning',
    );
    await _persist();

    if (remoteEnabled && currentProfile != null && activeSiteId != null && activeThavvuPointId != null) {
      try {
        await remote.raiseStockOrder(
          siteId: activeSiteId!,
          thavvuPointId: activeThavvuPointId!,
          stockPointName: point.name,
          itemName: item,
          quantity: quantity,
          unit: resolvedUnit,
          notes: notes,
          placedBy: currentProfile!.email,
          hodId: effectiveHodId,
        );
        final rows = await remote.stockOrders(
          siteId: activeSiteId,
          thavvuPointId: activeThavvuPointId,
          hodId: effectiveHodId,
        );
        remoteStockOrders
          ..clear()
          ..addAll(rows.map(_mapStockOrder));
      } catch (_) {}
    }

    notifyListeners();
    return order;
  }

  Future<void> approveStockOrder(String id) async {
    final idx = stockOrders.indexWhere((o) => o.id == id);
    if (idx < 0) return;
    final order = stockOrders[idx];
    stockOrders[idx] = order.copyWith(status: 'approved');

    final pIdx = stockPoints.indexWhere((p) => p.id == order.stockPointId);
    if (pIdx >= 0) {
      final p = stockPoints[pIdx];
      stockPoints[pIdx] = p.copyWith(
        onHand: p.onHand + order.quantity,
        totalIn: p.totalIn + order.quantity,
      );
      stockMovements.insert(
        0,
        StockMovement(
          id: _nextId('SM'),
          type: 'in',
          item: order.item,
          quantity: order.quantity,
          batch: p.batchId,
          date: 'Just now',
          by: 'HOD Approved',
          stockPointId: p.id,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> approveAllPendingOrders() async {
    final pending = stockOrders.where((o) => o.status == 'pending').map((o) => o.id).toList();
    for (final id in pending) {
      await approveStockOrder(id);
    }
  }

  Future<StockReturn> submitStockReturn({
    required String originalBatchId,
    required String item,
    required int quantity,
    String reason = '',
    String? photoPath,
  }) async {
    final ret = StockReturn(
      id: _nextId('RET'),
      originalBatchId: originalBatchId,
      item: item,
      quantity: quantity,
      reason: reason,
      photoPath: photoPath,
      createdAt: DateTime.now(),
    );
    stockReturns.insert(0, ret);
    await _addNotification(
      'Return Submitted',
      '$item x$quantity return pending approval',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return ret;
  }

  Future<void> approveStockReturn(String id) async {
    final idx = stockReturns.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final ret = stockReturns[idx];
    stockReturns[idx] = ret.copyWith(status: 'approved');
    // Credit first stock point that matches batch, else first warehouse
    var pIdx = stockPoints.indexWhere((p) => p.batchId == ret.originalBatchId);
    if (pIdx < 0) pIdx = 0;
    if (stockPoints.isNotEmpty) {
      final p = stockPoints[pIdx];
      stockPoints[pIdx] = p.copyWith(
        onHand: p.onHand + ret.quantity,
        totalIn: p.totalIn + ret.quantity,
      );
      stockMovements.insert(
        0,
        StockMovement(
          id: _nextId('SM'),
          type: 'return',
          item: ret.item,
          quantity: ret.quantity,
          batch: ret.originalBatchId,
          date: 'Just now',
          by: ret.id,
          stockPointId: p.id,
        ),
      );
    }
    await _persist();
    notifyListeners();
  }

  // ── Transfers ─────────────────────────────────────────────────────────────

  Future<TransferRecord?> initiateTransfer({
    required String fromPoint,
    required String toPoint,
    required String item,
    required int quantity,
    String notes = '',
    String? photoPath,
  }) async {
    if (fromPoint == toPoint) return null;
    final fromIdx = stockPoints.indexWhere((p) => p.name == fromPoint);
    if (fromIdx < 0) return null;
    final from = stockPoints[fromIdx];
    if (from.remaining < quantity) return null;

    stockPoints[fromIdx] = from.copyWith(
      onHand: from.onHand - quantity,
      totalOut: from.totalOut + quantity,
    );

    final record = TransferRecord(
      id: _nextId('TRF'),
      item: item,
      fromPoint: fromPoint,
      toPoint: toPoint,
      quantity: quantity,
      status: 'pending_ack',
      date: _fmtDate(DateTime.now()),
      notes: notes,
      photoPath: photoPath,
      createdAt: DateTime.now(),
    );
    transfers.insert(0, record);
    stockMovements.insert(
      0,
      StockMovement(
        id: _nextId('SM'),
        type: 'transfer',
        item: item,
        quantity: quantity,
        batch: from.batchId,
        date: 'Just now',
        by: '$fromPoint→$toPoint',
        stockPointId: from.id,
      ),
    );
    await _addNotification(
      'Transfer Initiated',
      '$item x$quantity from $fromPoint to $toPoint',
      type: 'info',
    );
    await _persist();

    if (remoteEnabled && currentProfile != null && activeSiteId != null) {
      try {
        final fromRemote = remoteThavvuPoints.firstWhere(
          (p) => p.name.toLowerCase() == fromPoint.toLowerCase(),
          orElse: () => remoteThavvuPoints.isNotEmpty ? remoteThavvuPoints.first : const ThavvuPoint(id: '', siteId: '', name: '', code: ''),
        );
        final toRemote = remoteThavvuPoints.firstWhere(
          (p) => p.name.toLowerCase() == toPoint.toLowerCase(),
          orElse: () => remoteThavvuPoints.isNotEmpty ? remoteThavvuPoints.last : const ThavvuPoint(id: '', siteId: '', name: '', code: ''),
        );
        if (fromRemote.id.isNotEmpty && toRemote.id.isNotEmpty) {
          final row = await remote.initiateTransfer(
            siteId: activeSiteId!,
            fromPointId: fromRemote.id,
            fromPoint: fromPoint,
            toPointId: toRemote.id,
            toPoint: toPoint,
            itemName: item,
            quantity: quantity,
            unit: unitForItem(item),
            notes: notes,
            photoName: photoPath,
            initiatedBy: currentProfile!.email,
            hodId: effectiveHodId,
            thavvuPointId: activeThavvuPointId,
          );
          if (row != null) {
            remoteTransfers.insert(0, _mapTransfer(row));
          }
        }
      } catch (_) {}
    }

    notifyListeners();
    return record;
  }

  Future<void> acknowledgeTransfer(String id) async {
    final idx = transfers.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = transfers[idx];
    if (t.status == 'completed') return;

    final toIdx = stockPoints.indexWhere((p) => p.name == t.toPoint);
    if (toIdx >= 0) {
      final to = stockPoints[toIdx];
      stockPoints[toIdx] = to.copyWith(
        onHand: to.onHand + t.quantity,
        totalIn: to.totalIn + t.quantity,
      );
    }
    transfers[idx] = t.copyWith(status: 'completed');
    await _addNotification(
      'Transfer Completed',
      '${t.item} received at ${t.toPoint}',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  // ── Rentals ───────────────────────────────────────────────────────────────

  List<RentalRecord> get activeRentals =>
      rentals.where((r) => r.status == 'active').toList();

  List<RentalRecord> get closedRentals =>
      rentals.where((r) => r.status == 'closed').toList();

  Future<RentalRecord> openRental({
    required String item,
    required String billingMode,
    required double rate,
    double fuel = 0,
    String notes = '',
    String? photoPath,
  }) async {
    final record = RentalRecord(
      id: 'RNT-${DateTime.now().year}-${(34 + rentals.length).toString().padLeft(4, '0')}',
      item: item,
      billingMode: billingMode,
      rate: rate,
      fuel: fuel,
      notes: notes,
      photoPath: photoPath,
      startDate: DateTime.now().toIso8601String().split('T').first,
      createdAt: DateTime.now(),
    );
    rentals.insert(0, record);
    await _addNotification(
      'Rental Opened',
      '${record.id} · $item',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return record;
  }

  Future<RentalRecord?> closeRental(String rentalId) async {
    final idx = rentals.indexWhere((r) => r.id == rentalId);
    if (idx < 0) return null;
    rentals[idx] = rentals[idx].copyWith(
      status: 'closed',
      endDate: DateTime.now().toIso8601String().split('T').first,
    );
    await _addNotification(
      'Rental Closed',
      '$rentalId closed successfully',
      type: 'info',
    );
    await _persist();
    notifyListeners();
    return rentals[idx];
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  List<AppTask> get checklistTasks =>
      tasks.where((t) => t.source == 'checklist').toList();

  List<AppTask> get hodTasks => tasks.where((t) => t.source == 'hod').toList();

  Future<void> toggleTask(String id) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    tasks[idx] = tasks[idx].copyWith(done: !tasks[idx].done);
    await _persist();
    notifyListeners();
  }

  int get pendingTaskCount => tasks.where((t) => !t.done).length;
  int get completedTaskCount => tasks.where((t) => t.done).length;

  int get hodPoints =>
      hodTasks.where((t) => t.done).fold(0, (sum, t) => sum + t.points);

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<ReportRecord> generateReport({
    required String title,
    required String format,
    required String period,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final summary = _buildReportSummary(title);
    final report = ReportRecord(
      id: _nextId('RPT'),
      title: title,
      date: DateTime.now(),
      size: '${150 + DateTime.now().millisecond % 500} KB',
      type: format,
      period: period,
      summary: summary,
      status: 'completed',
    );
    reports.insert(0, report);
    await _addNotification(
      'Report Generated',
      '$title ($format)',
      type: 'success',
    );
    await _persist();
    notifyListeners();
    return report;
  }

  String _buildReportSummary(String title) {
    switch (title) {
      case 'Machines Summary':
        return 'Machines: ${machines.length} · Approved: ${approvedMachines.length} · Daily logs: ${dailyLogs.length}';
      case 'Workers':
        return 'Workers: ${workers.length} · Present today: $presentTodayCount · Attendance rows: ${attendance.length}';
      case 'Rental':
        return 'Active rentals: ${activeRentals.length} · Closed: ${closedRentals.length}';
      case 'Diesel':
        final dieselMoves = stockMovements.where((m) => m.item == 'Diesel').length;
        return 'Diesel movements: $dieselMoves · Stock points: ${stockPoints.length}';
      case 'Returns':
        return 'Returns submitted: ${stockReturns.length}';
      case 'Site bikes petrol':
        return 'Bike petrol logs: demo summary from site operations';
      default:
        return 'Generated from live store data';
    }
  }

  // ── Maps ──────────────────────────────────────────────────────────────────

  Future<void> syncMapLocations() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _addNotification(
      'Maps Synced',
      'Latest locations refreshed from HOD',
      type: 'success',
    );
    await _persist();
    notifyListeners();
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  int get unreadNotificationCount =>
      notifications.where((n) => !n.read).length;

  Future<void> _addNotification(String title, String body, {String type = 'info'}) async {
    notifications.insert(
      0,
      AppNotification(
        id: _nextId('N'),
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> markNotificationRead(String id) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx < 0) return;
    notifications[idx] = notifications[idx].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(read: true);
    }
    await _persist();
    notifyListeners();
  }

  // ── Overview helpers ──────────────────────────────────────────────────────

  double get pendingAmount {
    final machinePending = pendingMachines.fold<double>(0, (s, m) => s + m.workingAmount);
    final rentalActive = activeRentals.fold<double>(0, (s, r) => s + r.rate);
    return machinePending + rentalActive;
  }

  // ── Settings helpers ──────────────────────────────────────────────────────

  Future<void> resetDemoData() async {
    _seed();
    await _persist();
    notifyListeners();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month)} ${d.year}';

  String _month(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}
