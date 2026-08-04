import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Production repository for the Rental module.
///
/// Mirrors the stock/payments pattern: site-scoped reads, atomic writes,
/// photo uploads to the private `rental-photos` bucket, and realtime
/// subscriptions so the supervisor and HOD screens stay in sync.
class RentalRepository {
  RentalRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const catalogsTable = 'rental_catalogs';
  static const entriesTable = 'rental_entries';
  static const fuelLinesTable = 'rental_fuel_lines';
  static const transfersTable = 'rental_transfers';
  static const returnsTable = 'rental_returns';
  static const paymentsTable = 'rental_payments';
  static const photoBucket = 'rental-photos';

  // ═══════════════════════════════════════════════════════════════════
  // CATALOGS (HOD plans; supervisor selects)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RentalCatalog>> fetchCatalogs({required String siteId}) async {
    final response = await _client
        .from(catalogsTable)
        .select()
        .eq('site_id', siteId)
        .eq('is_active', true)
        .order('name', ascending: true);
    return (response as List)
        .map((row) => RentalCatalog.fromJson(_asMap(row)))
        .toList();
  }

  Future<RentalCatalog> createCatalog({
    required String siteId,
    required String name,
    required String kind,
    String? vehicleNumber,
    required String billingType,
    required double ratePerUnit,
    List<String> thavvuIds = const [],
    List<String> tankIds = const [],
    String? notes,
  }) async {
    final response = await _client
        .from(catalogsTable)
        .insert({
          'site_id': siteId,
          'name': name,
          'kind': kind,
          'vehicle_number': vehicleNumber,
          'billing_type': billingType,
          'rate_per_unit': ratePerUnit,
          'thavvu_ids': thavvuIds,
          'tank_ids': tankIds,
          'notes': notes,
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    return RentalCatalog.fromJson(_asMap(response));
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENTRIES (+ fuel lines)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RentalEntry>> fetchEntries({
    required String siteId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _client
        .from(entriesTable)
        .select('*, fuel_lines:rental_fuel_lines(*)')
        .eq('site_id', siteId);
    if (status != null) {
      query = query.eq('status', status);
    }
    if (fromDate != null) {
      query = query.gte('work_date', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('work_date', toDate.toIso8601String());
    }
    final response = await query
        .order('work_date', ascending: false)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => RentalEntry.fromJson(_asMap(row)))
        .toList();
  }

  Future<RentalEntry> createEntry({
    required String siteId,
    required String entryNo,
    String? catalogId,
    required String vehicleName,
    required String billingType,
    String? thavvuId,
    String? tankId,
    String? fromLocation,
    String? toLocation,
    String? driver,
    required DateTime workDate,
    required double units,
    required double rate,
    double fuelCost = 0,
    double driverBata = 0,
    double loadingCharge = 0,
    String? openingPhotoPath,
    String? billPhotoPath,
    String? notes,
    List<RentalFuelLine> fuelLines = const [],
    String? thavvuPointId,
  }) async {
    final total = units * rate + fuelCost + driverBata + loadingCharge;
    final response = await _client
        .from(entriesTable)
        .insert({
          'entry_no': entryNo,
          'site_id': siteId,
          'thavvu_point_id': thavvuPointId,
          'catalog_id': catalogId,
          'vehicle_name': vehicleName,
          'billing_type': billingType,
          'thavvu_id': thavvuId,
          'tank_id': tankId,
          'from_location': fromLocation,
          'to_location': toLocation,
          'driver_or_operator': driver,
          'work_date': workDate.toIso8601String(),
          'units': units,
          'rate': rate,
          'fuel_cost': fuelCost,
          'driver_bata': driverBata,
          'loading_charge': loadingCharge,
          'total_amount': total,
          'status': 'submitted',
          'opening_photo_path': openingPhotoPath,
          'bill_photo_path': billPhotoPath,
          'notes': notes,
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    final entry = RentalEntry.fromJson(_asMap(response));

    if (fuelLines.isNotEmpty) {
      await _client.from(fuelLinesTable).insert(
            fuelLines
                .map((line) => {
                      'entry_id': entry.id,
                      'fuel_type': line.fuelType,
                      'stock_point': line.stockPoint,
                      'liters': line.liters,
                      'amount': line.amount,
                      'remarks': line.remarks,
                    })
                .toList(),
          );
    }
    return entry;
  }

  Future<bool> updateEntryStatus({
    required String entryId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(entriesTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
        'updated_at': now,
      }).eq('id', entryId);
      return true;
    } catch (e) {
      debugPrint('Error updating rental entry: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRANSFERS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RentalTransfer>> fetchTransfers({required String siteId}) async {
    final response = await _client
        .from(transfersTable)
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => RentalTransfer.fromJson(_asMap(row)))
        .toList();
  }

  Future<RentalTransfer> createTransfer({
    required String siteId,
    required String transferNo,
    required String assetKind,
    required String itemName,
    String? fromThavvuId,
    String? toThavvuId,
    String? driver,
    required DateTime workDate,
    String? photoPath,
    String? notes,
  }) async {
    final response = await _client
        .from(transfersTable)
        .insert({
          'transfer_no': transferNo,
          'site_id': siteId,
          'asset_kind': assetKind,
          'item_name': itemName,
          'from_thavvu_id': fromThavvuId,
          'to_thavvu_id': toThavvuId,
          'driver_or_operator': driver,
          'work_date': workDate.toIso8601String(),
          'status': 'submitted',
          'photo_path': photoPath,
          'notes': notes,
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    return RentalTransfer.fromJson(_asMap(response));
  }

  Future<bool> updateTransferStatus({
    required String transferId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(transfersTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
      }).eq('id', transferId);
      return true;
    } catch (e) {
      debugPrint('Error updating rental transfer: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // RETURNS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RentalReturn>> fetchReturns({required String siteId}) async {
    final response = await _client
        .from(returnsTable)
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => RentalReturn.fromJson(_asMap(row)))
        .toList();
  }

  Future<RentalReturn> createReturn({
    required String siteId,
    required String returnNo,
    String? catalogId,
    required String itemName,
    String? fromThavvuId,
    required DateTime workDate,
    double quantity = 1,
    String? reason,
    String? photoPath,
  }) async {
    final response = await _client
        .from(returnsTable)
        .insert({
          'return_no': returnNo,
          'site_id': siteId,
          'catalog_id': catalogId,
          'item_name': itemName,
          'from_thavvu_id': fromThavvuId,
          'work_date': workDate.toIso8601String(),
          'quantity': quantity,
          'reason': reason,
          'status': 'submitted',
          'photo_path': photoPath,
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    return RentalReturn.fromJson(_asMap(response));
  }

  Future<bool> updateReturnStatus({
    required String returnId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(returnsTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
      }).eq('id', returnId);
      return true;
    } catch (e) {
      debugPrint('Error updating rental return: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PAYMENTS
  // ═══════════════════════════════════════════════════════════════════

  Future<List<RentalPayment>> fetchPayments({required String siteId}) async {
    final response = await _client
        .from(paymentsTable)
        .select()
        .eq('site_id', siteId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((row) => RentalPayment.fromJson(_asMap(row)))
        .toList();
  }

  Future<RentalPayment> createPayment({
    required String siteId,
    required String supplierName,
    required double amount,
    required String mode,
    String? proofPath,
    String? note,
  }) async {
    final response = await _client
        .from(paymentsTable)
        .insert({
          'site_id': siteId,
          'supplier_name': supplierName,
          'amount': amount,
          'mode': mode,
          'status': 'submitted',
          'proof_path': proofPath,
          'note': note,
          'is_demo': false,
          'created_by': _client.auth.currentUser?.id ?? '',
        })
        .select()
        .single();
    return RentalPayment.fromJson(_asMap(response));
  }

  Future<bool> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? hodNote,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from(paymentsTable).update({
        'status': status,
        'hod_id': _client.auth.currentUser?.id,
        'hod_note': hodNote,
        'reviewed_at': now,
      }).eq('id', paymentId);
      return true;
    } catch (e) {
      debugPrint('Error updating rental payment: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PHOTO UPLOAD
  // ═══════════════════════════════════════════════════════════════════

  /// Uploads a captured photo to the private `rental-photos` bucket.
  /// Returns the storage path (e.g. `<uid>/rental/2026-08-03/opening_1234.jpg`)
  /// or null on failure.
  Future<String?> uploadPhoto({
    required Uint8List bytes,
    required String extension,
    required String context,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final now = DateTime.now();
      final day = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final path = '${user.id}/rental/$day/'
          '${context}_${now.millisecondsSinceEpoch}.$extension';
      await _client.storage.from(photoBucket).uploadBinary(path, bytes);
      return path;
    } catch (e) {
      debugPrint('Error uploading rental photo: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // REALTIME
  // ═══════════════════════════════════════════════════════════════════

  RealtimeChannel watchEntries(String siteId, void Function() onChanged) {
    return _client
        .channel('public:$entriesTable:$siteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: entriesTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  RealtimeChannel watchAll(String siteId, void Function() onChanged) {
    return _client
        .channel('public:rental-all:$siteId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: entriesTable,
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: transfersTable,
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: returnsTable,
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: paymentsTable,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  static String _string(Map<String, dynamic> json, String key,
      {String fallback = ''}) {
    final value = json[key];
    return value == null ? fallback : value.toString();
  }

  static double _double(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}

// ═══════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════

class RentalCatalog {
  final String id;
  final String siteId;
  final String name;
  final String kind;
  final String? vehicleNumber;
  final String billingType;
  final double ratePerUnit;
  final List<String> thavvuIds;
  final List<String> tankIds;
  final String? notes;
  final bool isActive;
  final bool isDemo;

  const RentalCatalog({
    required this.id,
    required this.siteId,
    required this.name,
    required this.kind,
    this.vehicleNumber,
    required this.billingType,
    required this.ratePerUnit,
    this.thavvuIds = const [],
    this.tankIds = const [],
    this.notes,
    this.isActive = true,
    this.isDemo = false,
  });

  factory RentalCatalog.fromJson(Map<String, dynamic> json) {
    return RentalCatalog(
      id: RentalRepository._string(json, 'id'),
      siteId: RentalRepository._string(json, 'site_id'),
      name: RentalRepository._string(json, 'name'),
      kind: RentalRepository._string(json, 'kind', fallback: 'vehicle'),
      vehicleNumber: json['vehicle_number'] as String?,
      billingType: RentalRepository._string(json, 'billing_type',
          fallback: 'DAY'),
      ratePerUnit: RentalRepository._double(json, 'rate_per_unit'),
      thavvuIds: RentalRepository._stringList(json, 'thavvu_ids'),
      tankIds: RentalRepository._stringList(json, 'tank_ids'),
      notes: json['notes'] as String?,
      isActive: json['is_active'] != false,
      isDemo: json['is_demo'] == true,
    );
  }
}

class RentalFuelLine {
  final String id;
  final String entryId;
  final String fuelType;
  final String? stockPoint;
  final double liters;
  final double amount;
  final String? remarks;

  const RentalFuelLine({
    required this.id,
    required this.entryId,
    this.fuelType = 'Diesel',
    this.stockPoint,
    this.liters = 0,
    this.amount = 0,
    this.remarks,
  });

  factory RentalFuelLine.fromJson(Map<String, dynamic> json) {
    return RentalFuelLine(
      id: RentalRepository._string(json, 'id'),
      entryId: RentalRepository._string(json, 'entry_id'),
      fuelType:
          RentalRepository._string(json, 'fuel_type', fallback: 'Diesel'),
      stockPoint: json['stock_point'] as String?,
      liters: RentalRepository._double(json, 'liters'),
      amount: RentalRepository._double(json, 'amount'),
      remarks: json['remarks'] as String?,
    );
  }
}

class RentalEntry {
  final String id;
  final String entryNo;
  final String siteId;
  final String? catalogId;
  final String vehicleName;
  final String billingType;
  final String? thavvuId;
  final String? tankId;
  final String? fromLocation;
  final String? toLocation;
  final String? driver;
  final DateTime workDate;
  final double units;
  final double rate;
  final double fuelCost;
  final double driverBata;
  final double loadingCharge;
  final double totalAmount;
  final String status;
  final String? openingPhotoPath;
  final String? billPhotoPath;
  final String? notes;
  final bool isDemo;
  final String? hodNote;
  final List<RentalFuelLine> fuelLines;

  const RentalEntry({
    required this.id,
    required this.entryNo,
    required this.siteId,
    this.catalogId,
    required this.vehicleName,
    required this.billingType,
    this.thavvuId,
    this.tankId,
    this.fromLocation,
    this.toLocation,
    this.driver,
    required this.workDate,
    required this.units,
    required this.rate,
    this.fuelCost = 0,
    this.driverBata = 0,
    this.loadingCharge = 0,
    this.totalAmount = 0,
    this.status = 'submitted',
    this.openingPhotoPath,
    this.billPhotoPath,
    this.notes,
    this.isDemo = false,
    this.hodNote,
    this.fuelLines = const [],
  });

  factory RentalEntry.fromJson(Map<String, dynamic> json) {
    final rawLines = json['fuel_lines'];
    final lines = <RentalFuelLine>[];
    if (rawLines is List) {
      for (final row in rawLines) {
        if (row is Map) {
          lines.add(RentalFuelLine.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v))));
        }
      }
    }
    return RentalEntry(
      id: RentalRepository._string(json, 'id'),
      entryNo: RentalRepository._string(json, 'entry_no'),
      siteId: RentalRepository._string(json, 'site_id'),
      catalogId: json['catalog_id'] as String?,
      vehicleName: RentalRepository._string(json, 'vehicle_name'),
      billingType: RentalRepository._string(json, 'billing_type',
          fallback: 'DAY'),
      thavvuId: json['thavvu_id'] as String?,
      tankId: json['tank_id'] as String?,
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      driver: json['driver_or_operator'] as String?,
      workDate: DateTime.tryParse(
              RentalRepository._string(json, 'work_date')) ??
          DateTime.now(),
      units: RentalRepository._double(json, 'units'),
      rate: RentalRepository._double(json, 'rate'),
      fuelCost: RentalRepository._double(json, 'fuel_cost'),
      driverBata: RentalRepository._double(json, 'driver_bata'),
      loadingCharge: RentalRepository._double(json, 'loading_charge'),
      totalAmount: RentalRepository._double(json, 'total_amount'),
      status: RentalRepository._string(json, 'status', fallback: 'submitted'),
      openingPhotoPath: json['opening_photo_path'] as String?,
      billPhotoPath: json['bill_photo_path'] as String?,
      notes: json['notes'] as String?,
      isDemo: json['is_demo'] == true,
      hodNote: json['hod_note'] as String?,
      fuelLines: lines,
    );
  }

  double get baseAmount => units * rate;
  double get extraAmount => fuelCost + driverBata + loadingCharge;
}

class RentalTransfer {
  final String id;
  final String transferNo;
  final String siteId;
  final String assetKind;
  final String itemName;
  final String? fromThavvuId;
  final String? toThavvuId;
  final String? driver;
  final DateTime workDate;
  final String status;
  final String? photoPath;
  final String? notes;
  final bool isDemo;

  const RentalTransfer({
    required this.id,
    required this.transferNo,
    required this.siteId,
    required this.assetKind,
    required this.itemName,
    this.fromThavvuId,
    this.toThavvuId,
    this.driver,
    required this.workDate,
    this.status = 'submitted',
    this.photoPath,
    this.notes,
    this.isDemo = false,
  });

  factory RentalTransfer.fromJson(Map<String, dynamic> json) {
    return RentalTransfer(
      id: RentalRepository._string(json, 'id'),
      transferNo: RentalRepository._string(json, 'transfer_no'),
      siteId: RentalRepository._string(json, 'site_id'),
      assetKind:
          RentalRepository._string(json, 'asset_kind', fallback: 'material'),
      itemName: RentalRepository._string(json, 'item_name'),
      fromThavvuId: json['from_thavvu_id'] as String?,
      toThavvuId: json['to_thavvu_id'] as String?,
      driver: json['driver_or_operator'] as String?,
      workDate: DateTime.tryParse(
              RentalRepository._string(json, 'work_date')) ??
          DateTime.now(),
      status: RentalRepository._string(json, 'status', fallback: 'submitted'),
      photoPath: json['photo_path'] as String?,
      notes: json['notes'] as String?,
      isDemo: json['is_demo'] == true,
    );
  }
}

class RentalReturn {
  final String id;
  final String returnNo;
  final String siteId;
  final String? catalogId;
  final String itemName;
  final String? fromThavvuId;
  final DateTime workDate;
  final double quantity;
  final String? reason;
  final String status;
  final String? photoPath;
  final bool isDemo;

  const RentalReturn({
    required this.id,
    required this.returnNo,
    required this.siteId,
    this.catalogId,
    required this.itemName,
    this.fromThavvuId,
    required this.workDate,
    this.quantity = 1,
    this.reason,
    this.status = 'submitted',
    this.photoPath,
    this.isDemo = false,
  });

  factory RentalReturn.fromJson(Map<String, dynamic> json) {
    return RentalReturn(
      id: RentalRepository._string(json, 'id'),
      returnNo: RentalRepository._string(json, 'return_no'),
      siteId: RentalRepository._string(json, 'site_id'),
      catalogId: json['catalog_id'] as String?,
      itemName: RentalRepository._string(json, 'item_name'),
      fromThavvuId: json['from_thavvu_id'] as String?,
      workDate: DateTime.tryParse(
              RentalRepository._string(json, 'work_date')) ??
          DateTime.now(),
      quantity: RentalRepository._double(json, 'quantity'),
      reason: json['reason'] as String?,
      status: RentalRepository._string(json, 'status', fallback: 'submitted'),
      photoPath: json['photo_path'] as String?,
      isDemo: json['is_demo'] == true,
    );
  }
}

class RentalPayment {
  final String id;
  final String siteId;
  final String supplierName;
  final double amount;
  final String mode;
  final String status;
  final String? proofPath;
  final String? note;
  final bool isDemo;

  const RentalPayment({
    required this.id,
    required this.siteId,
    required this.supplierName,
    required this.amount,
    required this.mode,
    this.status = 'submitted',
    this.proofPath,
    this.note,
    this.isDemo = false,
  });

  factory RentalPayment.fromJson(Map<String, dynamic> json) {
    return RentalPayment(
      id: RentalRepository._string(json, 'id'),
      siteId: RentalRepository._string(json, 'site_id'),
      supplierName: RentalRepository._string(json, 'supplier_name'),
      amount: RentalRepository._double(json, 'amount'),
      mode: RentalRepository._string(json, 'mode', fallback: 'cash'),
      status: RentalRepository._string(json, 'status', fallback: 'submitted'),
      proofPath: json['proof_path'] as String?,
      note: json['note'] as String?,
      isDemo: json['is_demo'] == true,
    );
  }
}
