import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Read-only aggregation repository for the Reports screen.
///
/// Pulls live numbers from every module's tables instead of seeds:
/// attendance, food, stock, machines, rental, cash.
class ReportsRepository {
  ReportsRepository({SupabaseClient? client}) : _providedClient = client;

  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  /// Today's attendance summary for a site.
  Future<Map<String, int>> attendanceSummary(String siteId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final rows = await _client
          .from('attendance_records')
          .select('status')
          .eq('site_id', siteId)
          .gte('date', today)
          .lte('date', today);
      final summary = <String, int>{'present': 0, 'absent': 0, 'late': 0, 'leave': 0};
      for (final row in rows as List) {
        final status = (row as Map)['status']?.toString() ?? 'present';
        summary[status] = (summary[status] ?? 0) + 1;
      }
      return summary;
    } catch (_) {
      return const {'present': 0, 'absent': 0, 'late': 0, 'leave': 0};
    }
  }

  /// Food requests for today (meals planned).
  Future<int> foodRequests(String siteId) async {
    try {
      final rows = await _client
          .from('food_requests')
          .select('id')
          .eq('site_id', siteId)
          .limit(1000);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Stock summary: active items, low-stock batches, total on-hand qty.
  Future<Map<String, double>> stockSummary(String siteId) async {
    try {
      final items = await _client
          .from('stock_items')
          .select('id')
          .eq('is_active', true)
          .limit(1000);
      final balances = await _client
          .from('stock_batch_balances')
          .select('available_qty, reorder_level')
          .gt('available_qty', 0)
          .limit(1000);
      var low = 0;
      var totalQty = 0.0;
      for (final row in balances as List) {
        final map = row as Map;
        final qty = _toDouble(map['available_qty']);
        totalQty += qty;
        if (map['reorder_level'] != null && qty <= _toDouble(map['reorder_level'])) {
          low++;
        }
      }
      return {
        'items': (items as List).length.toDouble(),
        'low': low.toDouble(),
        'totalQty': totalQty,
      };
    } catch (_) {
      return const {'items': 0, 'low': 0, 'totalQty': 0};
    }
  }

  /// Diesel issued this month (litres) from stock movements.
  Future<double> dieselIssued(String siteId) async {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    try {
      final rows = await _client
          .from('stock_movements')
          .select('quantity')
          .eq('movement_type', 'issue')
          .gte('created_at', monthStart.toIso8601String())
          .limit(1000);
      var total = 0.0;
      for (final row in rows as List) {
        total += _toDouble((row as Map)['quantity']);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Machine logs submitted this month.
  Future<int> machineLogs(String siteId) async {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    try {
      final rows = await _client
          .from('machine_daily_logs')
          .select('id')
          .eq('site_id', siteId)
          .gte('log_date', monthStart.toIso8601String())
          .limit(1000);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Rental entries this month (count + total amount).
  Future<Map<String, double>> rentalSummary(String siteId) async {
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
    try {
      final rows = await _client
          .from('rental_entries')
          .select('total_amount')
          .eq('site_id', siteId)
          .gte('work_date', monthStart.toIso8601String())
          .limit(1000);
      var total = 0.0;
      for (final row in rows as List) {
        total += _toDouble((row as Map)['total_amount']);
      }
      return {'count': (rows as List).length.toDouble(), 'total': total};
    } catch (_) {
      return const {'count': 0, 'total': 0};
    }
  }

  /// Cash spent (approved/paid transactions) for a site.
  Future<double> cashSpent(String siteId) async {
    try {
      final rows = await _client
          .from('cash_transactions')
          .select('amount')
          .eq('site_id', siteId)
          .inFilter('status', ['approved', 'paid'])
          .limit(1000);
      var total = 0.0;
      for (final row in rows as List) {
        total += _toDouble((row as Map)['amount']);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Per-Thavvu-Point summary for a site — the enterprise key: every module's
  /// rows scoped by thavvu_point_id. Returns a map of pointId → module totals.
  Future<Map<String, Map<String, double>>> pointSummary(String siteId) async {
    final result = <String, Map<String, double>>{};
    Future<void> addRows(
      String table,
      String valueColumn,
      String keyName,
    ) async {
      try {
        final rows = await _client
            .from(table)
            .select('thavvu_point_id, $valueColumn')
            .eq('site_id', siteId)
            .limit(5000);
        for (final row in rows as List) {
          final map = row as Map;
          final pointId = map['thavvu_point_id']?.toString();
          if (pointId == null || pointId.isEmpty) continue;
          final bucket = result.putIfAbsent(pointId, () => <String, double>{
                'count': 0,
                'value': 0,
                'attendance': 0,
                'food': 0,
                'stock': 0,
                'diesel': 0,
                'machines': 0,
                'rental': 0,
                'cash': 0,
                'tasks': 0,
              });
          bucket['count'] = (bucket['count'] ?? 0) + 1;
          bucket['value'] = (bucket['value'] ?? 0) + _toDouble(map[valueColumn]);
          bucket[keyName] = (bucket[keyName] ?? 0) + 1;
        }
      } catch (_) {}
    }

    await addRows('rental_entries', 'total_amount', 'rental');
    await addRows('cash_transactions', 'amount', 'cash');
    await addRows('tasks', 'id', 'tasks');
    await addRows('stock_consumption', 'quantity', 'stock');
    await addRows('machine_daily_logs', 'id', 'machines');
    await addRows('attendance_records', 'id', 'attendance');
    await addRows('food_requests', 'id', 'food');
    return result;
  }

  /// Latest update timestamp across all module tables for a point.
  Future<DateTime?> pointLastUpdated(String pointId) async {
    DateTime? latest;
    Future<void> check(String table, String timeColumn) async {
      try {
        final rows = await _client
            .from(table)
            .select(timeColumn)
            .eq('thavvu_point_id', pointId)
            .order(timeColumn, ascending: false)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          final at = DateTime.tryParse(
              (rows.first as Map)[timeColumn]?.toString() ?? '');
          if (at != null) {
            final current = latest;
            if (current == null || at.isAfter(current)) {
              latest = at;
            }
          }
        }
      } catch (_) {}
    }

    await check('attendance_records', 'created_at');
    await check('cash_transactions', 'created_at');
    await check('rental_entries', 'created_at');
    await check('stock_consumption', 'created_at');
    await check('machine_daily_logs', 'log_date');
    await check('food_requests', 'created_at');
    return latest;
  }

  /// Recent site activity across every module — attendance, food, stock
  /// consumption, machines, rental, cash — with the timestamp of each event
  /// so the HOD site detail can show when things happened.
  Future<List<SiteActivityEntry>> recentSiteActivity(
    String siteId, {
    int perModule = 5,
  }) async {
    final entries = <SiteActivityEntry>[];
    try {
      final attendance = await _client
          .from('attendance_records')
          .select('attendance_date, status, check_in_time')
          .eq('site_id', siteId)
          .order('attendance_date', ascending: false)
          .limit(perModule);
      for (final row in attendance as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Attendance',
          icon: Icons.people_outline,
          color: AppTheme.primary,
          title: '${map['status'] ?? 'Marked'} attendance',
          subtitle: map['check_in_time'] != null
              ? 'Check-in ${(map['check_in_time'] as String)}'
              : 'Attendance record',
          at: DateTime.tryParse(map['attendance_date']?.toString() ?? '') ??
              DateTime.tryParse(map['check_in_time']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    try {
      final food = await _client
          .from('food_requests')
          .select('attendance_date, category, created_at')
          .eq('site_id', siteId)
          .order('created_at', ascending: false)
          .limit(perModule);
      for (final row in food as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Food',
          icon: Icons.restaurant_outlined,
          color: AppTheme.success,
          title: 'Food request — ${map['category'] ?? 'meal'}',
          subtitle: 'Meal planned',
          at: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.tryParse(map['attendance_date']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    try {
      final consumption = await _client
          .from('stock_consumption')
          .select('item_name, quantity, uom, reason, created_at')
          .eq('site_id', siteId)
          .order('created_at', ascending: false)
          .limit(perModule);
      for (final row in consumption as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Stock',
          icon: Icons.outbox_outlined,
          color: AppTheme.warning,
          title: 'Consumed ${map['item_name'] ?? 'item'}',
          subtitle:
              '${map['quantity'] ?? 0} ${map['uom'] ?? ''} • ${map['reason'] ?? ''}',
          at: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    try {
      final machines = await _client
          .from('machine_daily_logs')
          .select('log_date, machine_name, diesel_litres')
          .eq('site_id', siteId)
          .order('log_date', ascending: false)
          .limit(perModule);
      for (final row in machines as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Machines',
          icon: Icons.precision_manufacturing_outlined,
          color: AppTheme.secondary,
          title: 'Machine log — ${map['machine_name'] ?? 'machine'}',
          subtitle: map['diesel_litres'] != null
              ? '${map['diesel_litres']} L diesel'
              : 'Daily log',
          at: DateTime.tryParse(map['log_date']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    try {
      final rental = await _client
          .from('rental_entries')
          .select('work_date, total_amount, item_name')
          .eq('site_id', siteId)
          .order('work_date', ascending: false)
          .limit(perModule);
      for (final row in rental as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Rental',
          icon: Icons.handyman_outlined,
          color: AppTheme.textSecondary,
          title: 'Rental — ${map['item_name'] ?? 'equipment'}',
          subtitle: '₹${_toDouble(map['total_amount']).toStringAsFixed(0)}',
          at: DateTime.tryParse(map['work_date']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    try {
      final cash = await _client
          .from('cash_transactions')
          .select('txn_no, type, amount, status, created_at')
          .eq('site_id', siteId)
          .order('created_at', ascending: false)
          .limit(perModule);
      for (final row in cash as List) {
        final map = row as Map;
        entries.add(SiteActivityEntry(
          source: 'Cash',
          icon: Icons.payments_outlined,
          color: AppTheme.danger,
          title: '${map['type'] ?? 'expense'} — ₹${_toDouble(map['amount']).toStringAsFixed(0)}',
          subtitle: '${map['txn_no'] ?? ''} • ${map['status'] ?? ''}',
          at: DateTime.tryParse(map['created_at']?.toString() ?? ''),
        ));
      }
    } catch (_) {}

    entries.sort((a, b) {
      final ad = a.at;
      final bd = b.at;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return entries;
  }

  /// Registry counts: active suppliers, workers, machines, catalog items.
  Future<Map<String, int>> registrySummary(String siteId) async {
    try {
      final suppliers = await _client
          .from('suppliers')
          .select('id')
          .eq('active', true)
          .limit(1000);
      final workers = await _client
          .from('workers')
          .select('id')
          .eq('site_id', siteId)
          .eq('status', 'active')
          .limit(1000);
      final machines = await _client
          .from('machine_assets')
          .select('id')
          .eq('site_id', siteId)
          .eq('is_active', true)
          .limit(1000);
      final items = await _client
          .from('stock_items')
          .select('id')
          .eq('is_active', true)
          .limit(1000);
      return {
        'suppliers': (suppliers as List).length,
        'workers': (workers as List).length,
        'machines': (machines as List).length,
        'items': (items as List).length,
      };
    } catch (_) {
      return const {'suppliers': 0, 'workers': 0, 'machines': 0, 'items': 0};
    }
  }

  /// Stock order lifecycle counts (placed / received / added_to_stock).
  Future<Map<String, int>> ordersSummary(String siteId) async {
    final summary = {'placed': 0, 'received': 0, 'added': 0};
    try {
      final rows = await _client
          .from('stock_orders')
          .select('status')
          .eq('site_id', siteId)
          .limit(1000);
      for (final row in rows as List) {
        final status = (row as Map)['status']?.toString() ?? 'placed';
        if (status == 'placed') {
          summary['placed'] = (summary['placed'] ?? 0) + 1;
        } else if (status == 'received') {
          summary['received'] = (summary['received'] ?? 0) + 1;
        } else if (status == 'added_to_stock') {
          summary['added'] = (summary['added'] ?? 0) + 1;
        }
      }
    } catch (_) {}
    return summary;
  }

  /// GIN lifecycle counts (pending / approved / rejected / added).
  Future<Map<String, int>> ginSummary(String siteId) async {
    final summary = {'pending': 0, 'approved': 0, 'rejected': 0, 'added': 0};
    try {
      final rows = await _client
          .from('gin_bills')
          .select('hod_status,status')
          .eq('site_id', siteId)
          .limit(1000);
      for (final row in rows as List) {
        final map = row as Map;
        final hod = map['hod_status']?.toString() ?? 'pending';
        if (hod == 'approved') {
          summary['approved'] = (summary['approved'] ?? 0) + 1;
        } else if (hod == 'rejected') {
          summary['rejected'] = (summary['rejected'] ?? 0) + 1;
        } else if ((map['status']?.toString() ?? '') == 'added_to_stock') {
          summary['added'] = (summary['added'] ?? 0) + 1;
        } else {
          summary['pending'] = (summary['pending'] ?? 0) + 1;
        }
      }
    } catch (_) {}
    return summary;
  }

  /// Stock movement + task counts (all entries land in Reports).
  Future<Map<String, int>> flowSummary(String siteId) async {
    try {
      final movements = await _client
          .from('stock_movements')
          .select('id')
          .limit(1000);
      final transfers = await _client
          .from('stock_transfers')
          .select('id')
          .eq('site_id', siteId)
          .limit(1000);
      final tasks = await _client
          .from('tasks')
          .select('status')
          .eq('site_id', siteId)
          .limit(1000);
      var done = 0;
      for (final row in tasks as List) {
        if ((row as Map)['status']?.toString() == 'approved') done++;
      }
      return {
        'movements': (movements as List).length,
        'transfers': (transfers as List).length,
        'tasks': (tasks as List).length,
        'tasksDone': done,
      };
    } catch (_) {
      return const {'movements': 0, 'transfers': 0, 'tasks': 0, 'tasksDone': 0};
    }
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// One event in a site's recent activity timeline.
class SiteActivityEntry {
  final String source;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime? at;

  const SiteActivityEntry({
    required this.source,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.at,
  });
}
