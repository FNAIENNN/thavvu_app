import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_client.dart';
import 'db_client.dart';

/// Remote data access against the live Thavvu Supabase schema.
/// All operations are scoped by site_id / thavvu_point_id / hod_id where relevant.
///
/// On web, read/auth traffic goes through [ApiClient] (`/api` Vercel proxy)
/// because browsers cannot open raw Postgres TCP sockets.
class RemoteRepository {
  RemoteRepository({DbClient? client, ApiClient? api})
      : _db = client ?? DbClient.instance,
        _api = api ?? ApiClient();

  final DbClient _db;
  final ApiClient _api;
  bool available = false;
  String? lastError;

  bool get _useHttp => kIsWeb || !_db.supportsDirectPostgres;

  Future<bool> ping() async {
    try {
      if (_useHttp) {
        available = await _api.ping();
      } else {
        await _db.query('select 1');
        available = true;
      }
      lastError = available ? null : 'ping failed';
      return available;
    } catch (e) {
      available = false;
      lastError = e.toString();
      return false;
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> login(String email, String password) async {
    if (_useHttp) {
      return _api.login(email, password);
    }
    final row = await _db.mapOne(
      '''
      select p.id, p.emp_id, p.full_name, p.email, p.phone, p.role, p.is_active, p.hod_id,
             c.password_hash
      from profiles p
      join app_credentials c on c.profile_id = p.id
      where lower(p.email) = lower(@email) and p.is_active = true
      limit 1
      ''',
      parameters: {'email': email.trim()},
    );
    if (row == null) return null;
    final hash = (row['password_hash'] as String?) ?? '';
    final ok = hash == 'plain:$password' || hash == password;
    if (!ok) return null;
    return row;
  }

  Future<List<Map<String, dynamic>>> siteMemberships(String profileId) async {
    return _db.maps(
      '''
      select sm.site_id, sm.role, sm.is_active, s.name as site_name, s.place
      from site_memberships sm
      join sites s on s.id = sm.site_id
      where sm.profile_id = @pid::uuid and sm.is_active = true
      order by s.name
      ''',
      parameters: {'pid': profileId},
    );
  }

  Future<List<Map<String, dynamic>>> thavvuPointsForSite(String siteId) async {
    if (_useHttp) {
      return _api.getList('/thavvu-points', query: {'site_id': siteId});
    }
    return _db.maps(
      '''
      select id, site_id, point_name, assigned_acres, status, hod_id
      from thavvu_points
      where site_id = @sid
      order by point_name
      ''',
      parameters: {'sid': siteId},
    );
  }

  Future<List<Map<String, dynamic>>> pointsForSupervisor(String profileId) async {
    return _db.maps(
      '''
      select tp.id, tp.site_id, tp.point_name, tp.status, tp.hod_id, s.name as site_name
      from thavvu_point_assignments tpa
      join thavvu_points tp on tp.id = tpa.thavvu_point_id
      join sites s on s.id = tp.site_id
      where tpa.supervisor_id = @pid::uuid and tpa.is_active = true
      order by s.name, tp.point_name
      ''',
      parameters: {'pid': profileId},
    );
  }

  Future<List<Map<String, dynamic>>> allSites({String? hodId}) async {
    if (_useHttp) {
      return _api.getList('/sites');
    }
    if (hodId != null && hodId.isNotEmpty) {
      return _db.maps(
        'select * from sites where hod_id = @hid::uuid or id in (select site_id from site_memberships where profile_id = @hid::uuid) order by name',
        parameters: {'hid': hodId},
      );
    }
    return _db.maps('select * from sites order by name');
  }

  // ── Stock catalog & balances ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> stockItems() async {
    if (_useHttp) {
      return _api.getList('/stock-items');
    }
    return _db.maps('''
      select id, code, name, item_name, category, group_name, uom, primary_uom, reorder_level, is_active
      from stock_items
      where coalesce(is_active, true) = true
      order by category, coalesce(item_name, name)
    ''');
  }

  Future<List<Map<String, dynamic>>> stockBalances({
    String? siteId,
    String? thavvuPointId,
    String? hodId,
  }) async {
    if (_useHttp) {
      return _api.getList(
        '/stock-balances',
        query: {
          if (thavvuPointId != null && thavvuPointId.isNotEmpty)
            'thavvu_point_id': thavvuPointId,
        },
      );
    }
    final filters = <String>[];
    final params = <String, Object?>{};
    if (thavvuPointId != null && thavvuPointId.isNotEmpty) {
      filters.add('stock_point_id = @tp');
      params['tp'] = thavvuPointId;
    }
    if (hodId != null && hodId.isNotEmpty) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      '''
      select id, item_id, item_name, item_code, stock_point_id, stock_point_name,
             location, batch_id, batch_code, available_qty, loose_qty, updated_at, hod_id
      from stock_batch_balances
      $where
      order by stock_point_name, item_name
      ''',
      parameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> stockOrders({
    String? siteId,
    String? thavvuPointId,
    String? hodId,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('thavvu_point_id = @tp');
      params['tp'] = thavvuPointId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from stock_orders $where order by created_at desc limit 200',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>> raiseStockOrder({
    required String siteId,
    required String thavvuPointId,
    required String stockPointName,
    required String itemName,
    required num quantity,
    required String unit,
    String? notes,
    String? placedBy,
    String? hodId,
  }) async {
    final rows = await _db.maps(
      '''
      insert into stock_orders (
        order_no, site_id, stock_point_id, stock_point_name, item_name, quantity, unit,
        status, notes, placed_by, thavvu_point_id, hod_id
      ) values (
        'ORD-' || to_char(now(), 'YYYYMMDD-HH24MISS'),
        @sid, @tp, @spn, @item, @qty, @unit,
        'pending', @notes, @by, @tp, @hid::uuid
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'tp': thavvuPointId,
        'spn': stockPointName,
        'item': itemName,
        'qty': quantity,
        'unit': unit,
        'notes': notes ?? '',
        'by': placedBy ?? 'supervisor',
        'hid': hodId,
      },
    );
    await logActivity(
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      module: 'stock',
      action: 'raise_order',
      summary: 'Ordered $quantity $unit of $itemName at $stockPointName',
      quantity: quantity,
      unit: unit,
      hodId: hodId,
    );
    return rows.first;
  }

  Future<void> reviewStockOrder({
    required String orderId,
    required String status,
    String? hodId,
  }) async {
    await _db.query(
      '''
      update stock_orders
      set status = @status, hod_id = coalesce(hod_id, @hid::uuid)
      where id = @id::uuid
      ''',
      parameters: {'status': status, 'hid': hodId, 'id': orderId},
    );
    await logActivity(
      module: 'stock',
      action: 'order_$status',
      summary: 'Stock order $status',
      entityId: orderId,
      hodId: hodId,
    );
  }

  Future<List<Map<String, dynamic>>> stockTransfers({
    String? siteId,
    String? thavvuPointId,
    String? hodId,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('(thavvu_point_id = @tp or from_thavvu_point_id = @tp or to_thavvu_point_id = @tp)');
      params['tp'] = thavvuPointId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from stock_transfers $where order by initiated_at desc nulls last limit 200',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>?> initiateTransfer({
    required String siteId,
    required String fromPointId,
    required String fromPoint,
    required String toPointId,
    required String toPoint,
    required String itemName,
    required num quantity,
    required String unit,
    String? notes,
    String? photoName,
    String? initiatedBy,
    String? hodId,
    String? thavvuPointId,
  }) async {
    // Deduct from source balance when possible
    await _db.query(
      '''
      update stock_batch_balances
      set available_qty = available_qty - @qty, updated_at = now()
      where stock_point_id = @fp
        and lower(item_name) = lower(@item)
        and available_qty >= @qty
      ''',
      parameters: {'qty': quantity, 'fp': fromPointId, 'item': itemName},
    );

    final rows = await _db.maps(
      '''
      insert into stock_transfers (
        transfer_no, site_id, from_point_id, from_point, to_point_id, to_point,
        item_name, quantity, unit, status, notes, photo_name, initiated_by,
        initiated_at, thavvu_point_id, from_thavvu_point_id, from_thavvu_point,
        to_thavvu_point_id, to_thavvu_point, hod_id
      ) values (
        'TRF-' || to_char(now(), 'YYYYMMDD-HH24MISS'),
        @sid, @fp, @fpn, @tp, @tpn,
        @item, @qty, @unit, 'pending_ack', @notes, @photo, @by,
        now(), @ctx, @fp, @fpn, @tp, @tpn, @hid::uuid
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'fp': fromPointId,
        'fpn': fromPoint,
        'tp': toPointId,
        'tpn': toPoint,
        'item': itemName,
        'qty': quantity,
        'unit': unit,
        'notes': notes ?? '',
        'photo': photoName,
        'by': initiatedBy ?? 'supervisor',
        'ctx': thavvuPointId ?? fromPointId,
        'hid': hodId,
      },
    );
    if (rows.isEmpty) return null;
    await logActivity(
      siteId: siteId,
      thavvuPointId: thavvuPointId ?? fromPointId,
      module: 'transfer',
      action: 'initiate',
      summary: 'Transfer $quantity $unit $itemName: $fromPoint → $toPoint',
      quantity: quantity,
      unit: unit,
      entityId: rows.first['id']?.toString(),
      hodId: hodId,
    );
    return rows.first;
  }

  Future<void> acknowledgeTransfer({
    required String transferId,
    String? receivedBy,
    String? hodId,
  }) async {
    final t = await _db.mapOne(
      'select * from stock_transfers where id = @id::uuid',
      parameters: {'id': transferId},
    );
    if (t == null) return;

    await _db.query(
      '''
      update stock_transfers
      set status = 'completed', received_by = @by, received_at = now(),
          received_quantity = quantity
      where id = @id::uuid
      ''',
      parameters: {'id': transferId, 'by': receivedBy ?? 'receiver'},
    );

    // Credit destination
    await _db.query(
      '''
      insert into stock_batch_balances (
        item_name, item_code, stock_point_id, stock_point_name, location,
        batch_id, batch_code, available_qty, loose_qty, updated_at, hod_id
      ) values (
        @item, lower(@item), @tp, @tpn, @tpn,
        @batch, @batch, @qty, 0, now(), @hid::uuid
      )
      on conflict do nothing
      ''',
      parameters: {
        'item': t['item_name'],
        'tp': t['to_point_id'] ?? t['to_thavvu_point_id'],
        'tpn': t['to_point'] ?? t['to_thavvu_point'],
        'batch': 'TRF-${t['transfer_no'] ?? transferId}',
        'qty': t['quantity'],
        'hid': hodId ?? t['hod_id']?.toString(),
      },
    );

    // If insert skipped due to conflict absence, try update/add
    await _db.query(
      '''
      update stock_batch_balances
      set available_qty = available_qty + @qty, updated_at = now()
      where stock_point_id = @tp and lower(item_name) = lower(@item)
      ''',
      parameters: {
        'qty': t['quantity'],
        'tp': t['to_point_id'] ?? t['to_thavvu_point_id'],
        'item': t['item_name'],
      },
    );

    await logActivity(
      siteId: t['site_id']?.toString(),
      thavvuPointId: t['to_thavvu_point_id']?.toString() ?? t['to_point_id']?.toString(),
      module: 'transfer',
      action: 'acknowledge',
      summary: 'Received ${t['quantity']} ${t['unit']} ${t['item_name']} at ${t['to_point']}',
      quantity: t['quantity'] as num?,
      unit: t['unit']?.toString(),
      entityId: transferId,
      hodId: hodId ?? t['hod_id']?.toString(),
    );
  }

  Future<List<Map<String, dynamic>>> stockConsumption({
    String? siteId,
    String? thavvuPointId,
    DateTime? from,
    DateTime? to,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('thavvu_point_id = @tp');
      params['tp'] = thavvuPointId;
    }
    if (from != null) {
      filters.add('created_at >= @from');
      params['from'] = from.toUtc();
    }
    if (to != null) {
      filters.add('created_at < @to');
      params['to'] = to.toUtc();
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from stock_consumption $where order by created_at desc limit 500',
      parameters: params,
    );
  }

  // ── Machines / daily logs ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> machines({String? siteId, String? hodId}) async {
    final filters = <String>['coalesce(is_active, true) = true'];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    return _db.maps(
      'select * from machine_assets where ${filters.join(' and ')} order by machine_name',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>> submitMachine({
    required String siteId,
    required String machineName,
    required String vehicleNumber,
    required String vehicleType,
    required String operatorName,
    String? operatorPhone,
    String? createdBy,
    String? hodId,
    String? openingPhotoPath,
  }) async {
    final id = 'MCH-${DateTime.now().millisecondsSinceEpoch}';
    final rows = await _db.maps(
      '''
      insert into machine_assets (
        id, site_id, machine_name, vehicle_number, vehicle_type, operator_name,
        operator_phone, is_active, created_by, hod_id
      ) values (
        @id, @sid, @name, @vn, @vt, @op, @phone, true, @by::uuid, @hid::uuid
      )
      returning *
      ''',
      parameters: {
        'id': id,
        'sid': siteId,
        'name': machineName,
        'vn': vehicleNumber,
        'vt': vehicleType,
        'op': operatorName,
        'phone': operatorPhone,
        'by': createdBy,
        'hid': hodId,
      },
    );
    if (openingPhotoPath != null && openingPhotoPath.isNotEmpty) {
      await registerPhoto(
        module: 'machines',
        label: 'opening',
        localPath: openingPhotoPath,
        siteId: siteId,
        uploadedBy: createdBy,
        hodId: hodId,
        storageBucket: 'machine-opening-photos',
      );
      await _db.query(
        '''
        insert into machine_attachments (
          reference_type, reference_id, file_type, file_path, file_name, uploaded_by, hod_id
        ) values (
          'machine_asset', @id, 'image', @path, @name, @by::uuid, @hid::uuid
        )
        ''',
        parameters: {
          'id': id,
          'path': openingPhotoPath,
          'name': openingPhotoPath.split('/').last,
          'by': createdBy,
          'hid': hodId,
        },
      );
    }
    await logActivity(
      siteId: siteId,
      module: 'machines',
      action: 'submit',
      summary: 'Machine $machineName ($vehicleNumber) submitted',
      entityId: id,
      hodId: hodId,
      actorId: createdBy,
    );
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> dailyLogs({
    String? siteId,
    String? thavvuPointId,
    String? supervisorId,
    String? hodId,
    DateTime? from,
    DateTime? to,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('thavvu_point_id = @tp');
      params['tp'] = thavvuPointId;
    }
    if (supervisorId != null) {
      filters.add('supervisor_id = @sup::uuid');
      params['sup'] = supervisorId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    if (from != null) {
      filters.add('log_date >= @from::date');
      params['from'] = from.toIso8601String().split('T').first;
    }
    if (to != null) {
      filters.add('log_date <= @to::date');
      params['to'] = to.toIso8601String().split('T').first;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from machine_daily_logs $where order by log_date desc, created_at desc limit 500',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>> saveDailyLog({
    required String siteId,
    required String thavvuPointId,
    required String machineId,
    required String supervisorId,
    double? workingHours,
    double? betaAmount,
    String? dieselOption,
    String? notes,
    String? billFilePath,
    String? hodId,
    String status = 'submitted',
  }) async {
    final rows = await _db.maps(
      '''
      insert into machine_daily_logs (
        log_date, site_id, thavvu_point_id, supervisor_id, machine_id,
        diesel_option, working_hours, beta_amount, notes, bill_file_path,
        status, hod_id, submitted_at
      ) values (
        current_date, @sid, @tp, @sup::uuid, @mid,
        @diesel, @hours, @beta, @notes, @bill,
        @status, @hid::uuid, now()
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'tp': thavvuPointId,
        'sup': supervisorId,
        'mid': machineId,
        'diesel': dieselOption,
        'hours': workingHours,
        'beta': betaAmount,
        'notes': notes,
        'bill': billFilePath,
        'status': status,
        'hid': hodId,
      },
    );
    await logActivity(
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      actorId: supervisorId,
      module: 'daily_data',
      action: 'save_log',
      summary: 'Daily log for $machineId submitted',
      entityId: rows.first['id']?.toString(),
      hodId: hodId,
    );
    return rows.first;
  }

  Future<void> reviewDailyLog({
    required String logId,
    required String status,
    String? hodNote,
    String? hodId,
  }) async {
    await _db.query(
      '''
      update machine_daily_logs
      set status = @status, hod_note = @note, reviewed_at = now(), hod_id = coalesce(hod_id, @hid::uuid)
      where id = @id::uuid
      ''',
      parameters: {'status': status, 'note': hodNote, 'hid': hodId, 'id': logId},
    );
  }

  // ── Suppliers & payments ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> suppliers({String? siteId, String? hodId}) async {
    if (_useHttp) {
      return _api.getList(
        '/suppliers',
        query: {
          if (siteId != null) 'site_id': siteId,
        },
      );
    }
    final filters = <String>['coalesce(active, true) = true'];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('(site_id = @sid or site_id is null)');
      params['sid'] = siteId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    return _db.maps(
      'select * from suppliers where ${filters.join(' and ')} order by name',
      parameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> supplierPaymentRequests({
    String? siteId,
    String? hodId,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from supplier_payment_requests $where order by created_at desc limit 200',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>> requestSupplierPayment({
    required String siteId,
    required String supplierName,
    required num amount,
    num? billAmount,
    num? usedAmount,
    String method = 'upi',
    String requestType = 'payment',
    String? paymentProof,
    String? hodId,
  }) async {
    if (_useHttp) {
      final row = await _api.post('/supplier-payments', {
        'site_id': siteId,
        'supplier_name': supplierName,
        'amount': amount,
        'bill_amount': billAmount ?? amount,
        'used_amount': usedAmount ?? 0,
        'method': method,
        'request_type': requestType,
        'payment_proof': paymentProof,
        'hod_id': hodId,
      });
      return row;
    }
    final rows = await _db.maps(
      '''
      insert into supplier_payment_requests (
        site_id, supplier_name, amount, bill_amount, used_amount,
        request_type, method, status, payment_proof, requested_at, hod_id
      ) values (
        @sid, @name, @amt, @bill, @used,
        @rtype, @method, 'pending', @proof, now(), @hid::uuid
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'name': supplierName,
        'amt': amount,
        'bill': billAmount ?? amount,
        'used': usedAmount ?? 0,
        'rtype': requestType,
        'method': method,
        'proof': paymentProof,
        'hid': hodId,
      },
    );
    await logActivity(
      siteId: siteId,
      module: 'supplier',
      action: 'payment_request',
      summary: 'Payment request ₹$amount for $supplierName ($method)',
      quantity: amount,
      unit: 'INR',
      entityId: rows.first['id']?.toString(),
      hodId: hodId,
    );
    return rows.first;
  }

  Future<void> reviewSupplierPayment({
    required String requestId,
    required String status,
    String? hodId,
  }) async {
    await _db.query(
      '''
      update supplier_payment_requests
      set status = @status, hod_id = coalesce(hod_id, @hid::uuid)
      where id = @id::uuid
      ''',
      parameters: {'status': status, 'hid': hodId, 'id': requestId},
    );
    await logActivity(
      module: 'supplier',
      action: 'payment_$status',
      summary: 'Supplier payment $status',
      entityId: requestId,
      hodId: hodId,
    );
  }

  Future<Map<String, dynamic>> addSupplierBill({
    required String siteId,
    required String supplier,
    required num amount,
    String? photoPath,
    String? createdBy,
    String? hodId,
  }) async {
    final rows = await _db.maps(
      '''
      insert into supplier_bills (site_id, supplier, photo_path, amount, bill_date, created_by, hod_id)
      values (@sid, @sup, @photo, @amt, current_date, @by::uuid, @hid::uuid)
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'sup': supplier,
        'photo': photoPath,
        'amt': amount,
        'by': createdBy,
        'hid': hodId,
      },
    );
    return rows.first;
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> workers({
    String? siteId,
    String? thavvuPointId,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('(thavvu_point_id = @tp or thavvu_point_id is null)');
      params['tp'] = thavvuPointId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from workers $where order by name',
      parameters: params,
    );
  }

  Future<Map<String, dynamic>> markAttendance({
    required String siteId,
    required String thavvuPointId,
    required String workerId,
    required String status,
    String? method,
    String? photoUrl,
    String? markedBy,
    String? hodId,
  }) async {
    final rows = await _db.maps(
      '''
      insert into attendance_records (
        site_id, thavvu_point_id, worker_id, attendance_date, status,
        check_in_method, check_in_photo_url, marked_by, hod_id, hod_approval_status
      ) values (
        @sid, @tp, @wid::uuid, current_date, @status,
        @method, @photo, @by::uuid, @hid::uuid, 'pending'
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'tp': thavvuPointId,
        'wid': workerId,
        'status': status,
        'method': method ?? 'Manual',
        'photo': photoUrl,
        'by': markedBy,
        'hid': hodId,
      },
    );
    await logActivity(
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      actorId: markedBy,
      module: 'attendance',
      action: 'mark',
      summary: 'Attendance $status',
      entityId: rows.first['id']?.toString(),
      hodId: hodId,
    );
    return rows.first;
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> tasks({
    String? siteId,
    String? thavvuPointId,
    String? supervisorId,
    String? hodId,
  }) async {
    final filters = <String>[];
    final params = <String, Object?>{};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('(thavvu_point_id = @tp or thavvu_id = @tp)');
      params['tp'] = thavvuPointId;
    }
    if (supervisorId != null) {
      filters.add('(assigned_supervisor_id = @sup or assigned_supervisor_id is null)');
      params['sup'] = supervisorId;
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from tasks $where order by created_at desc limit 300',
      parameters: params,
    );
  }

  Future<void> setTaskStatus({
    required String taskId,
    required String status,
    Map<String, dynamic>? proof,
  }) async {
    await _db.query(
      '''
      update tasks
      set status = @status,
          proof = coalesce(@proof::jsonb, proof),
          submitted_at = case when @status = 'completed' then now() else submitted_at end,
          updated_at = now()
      where id = @id::uuid
      ''',
      parameters: {
        'status': status,
        'proof': proof == null ? null : _encodeJson(proof),
        'id': taskId,
      },
    );
  }

  // ── Activity / reports ────────────────────────────────────────────────────

  Future<void> logActivity({
    String? siteId,
    String? thavvuPointId,
    String? actorId,
    String? actorRole,
    required String module,
    required String action,
    String? entityType,
    String? entityId,
    String? summary,
    num? quantity,
    String? unit,
    String? hodId,
    Map<String, dynamic>? meta,
  }) async {
    await _db.query(
      '''
      insert into app_activity_events (
        site_id, thavvu_point_id, actor_id, actor_role, module, action,
        entity_type, entity_id, summary, quantity, unit, meta, hod_id
      ) values (
        @sid, @tp, @actor::uuid, @role, @module, @action,
        @etype, @eid, @summary, @qty, @unit, coalesce(@meta::jsonb, '{}'::jsonb), @hid::uuid
      )
      ''',
      parameters: {
        'sid': siteId,
        'tp': thavvuPointId,
        'actor': actorId,
        'role': actorRole,
        'module': module,
        'action': action,
        'etype': entityType,
        'eid': entityId,
        'summary': summary,
        'qty': quantity,
        'unit': unit,
        'meta': meta == null ? null : _encodeJson(meta),
        'hid': hodId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> activityReport({
    String? siteId,
    String? thavvuPointId,
    String? module,
    DateTime? from,
    DateTime? to,
    String? hodId,
    int limit = 500,
  }) async {
    if (_useHttp) {
      return _api.getList(
        '/activity',
        query: {
          if (siteId != null) 'site_id': siteId,
          if (module != null) 'module': module,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String().split('T').first,
        },
      );
    }
    final filters = <String>[];
    final params = <String, Object?>{'lim': limit};
    if (siteId != null) {
      filters.add('site_id = @sid');
      params['sid'] = siteId;
    }
    if (thavvuPointId != null) {
      filters.add('thavvu_point_id = @tp');
      params['tp'] = thavvuPointId;
    }
    if (module != null && module != 'all') {
      filters.add('module = @module');
      params['module'] = module;
    }
    if (from != null) {
      filters.add('created_at >= @from');
      params['from'] = from.toUtc();
    }
    if (to != null) {
      filters.add('created_at < @to');
      params['to'] = to.toUtc().add(const Duration(days: 1));
    }
    if (hodId != null) {
      filters.add('(hod_id = @hid::uuid or hod_id is null)');
      params['hid'] = hodId;
    }
    final where = filters.isEmpty ? '' : 'where ${filters.join(' and ')}';
    return _db.maps(
      'select * from app_activity_events $where order by created_at desc limit @lim',
      parameters: params,
    );
  }

  Future<List<Map<String, dynamic>>> consumptionTable({
    required String siteId,
    String? thavvuPointId,
    DateTime? from,
    DateTime? to,
  }) async {
    return stockConsumption(
      siteId: siteId,
      thavvuPointId: thavvuPointId,
      from: from,
      to: to,
    );
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerPhoto({
    required String module,
    required String label,
    required String localPath,
    String? siteId,
    String? thavvuPointId,
    String? uploadedBy,
    String? hodId,
    String? storageBucket,
    String? storagePath,
  }) async {
    final rows = await _db.maps(
      '''
      insert into app_photo_uploads (
        site_id, thavvu_point_id, module, label, file_name, local_path,
        storage_bucket, storage_path, uploaded_by, hod_id
      ) values (
        @sid, @tp, @module, @label, @fname, @local,
        @bucket, @spath, @by::uuid, @hid::uuid
      )
      returning *
      ''',
      parameters: {
        'sid': siteId,
        'tp': thavvuPointId,
        'module': module,
        'label': label,
        'fname': localPath.split('/').last,
        'local': localPath,
        'bucket': storageBucket,
        'spath': storagePath ?? localPath,
        'by': uploadedBy,
        'hid': hodId,
      },
    );
    return rows.first;
  }

  String _encodeJson(Map<String, dynamic> map) {
    // Minimal JSON encoder for simple maps of primitives.
    final parts = <String>[];
    map.forEach((k, v) {
      final val = v is String
          ? '"${v.replaceAll('"', '\\"')}"'
          : v == null
              ? 'null'
              : '$v';
      parts.add('"$k":$val');
    });
    return '{${parts.join(',')}}';
  }
}
