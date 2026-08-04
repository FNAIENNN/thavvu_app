// lib/services/realtime_service.dart
//
// Unified Supabase Realtime service for the Thavvu app.
// Subscribes to attendance and food tables and pushes change callbacks
// to the UI layer. Each feature screen creates a subscription on mount
// and cancels it on dispose — no global singleton required.

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:supabase_flutter/supabase_flutter.dart';

enum RealtimeTable {
  workers,
  attendanceRecords,
  attendanceBatches,
  attendanceBatchWorkers,
  foodRequests,
  foodSubmissions,
  supplierBills,
  supplierPaymentRequests,
  paymentAccounts,
  paymentLedger,
}

extension _TableName on RealtimeTable {
  String get name {
    switch (this) {
      case RealtimeTable.workers:
        return 'workers';
      case RealtimeTable.attendanceRecords:
        return 'attendance_records';
      case RealtimeTable.attendanceBatches:
        return 'attendance_batches';
      case RealtimeTable.attendanceBatchWorkers:
        return 'attendance_batch_workers';
      case RealtimeTable.foodRequests:
        return 'food_requests';
      case RealtimeTable.foodSubmissions:
        return 'food_submissions';
      case RealtimeTable.supplierBills:
        return 'supplier_bills';
      case RealtimeTable.supplierPaymentRequests:
        return 'supplier_payment_requests';
      case RealtimeTable.paymentAccounts:
        return 'payment_accounts';
      case RealtimeTable.paymentLedger:
        return 'payment_ledger';
    }
  }
}

/// A single-channel Realtime subscription.
///
/// Usage:
/// ```dart
/// late final AttendanceRealtimeSubscription _sub;
///
/// @override
/// void initState() {
///   super.initState();
///   _sub = RealtimeService.subscribeAttendance(
///     siteId: _siteId,
///     onAnyChange: () => _loadFromBackend(),
///   );
/// }
///
/// @override
/// void dispose() {
///   _sub.cancel();
///   super.dispose();
/// }
/// ```
class AttendanceRealtimeSubscription {
  final RealtimeChannel _channel;
  AttendanceRealtimeSubscription._(this._channel);

  Future<void> cancel() async {
    await Supabase.instance.client.removeChannel(_channel);
  }
}

class FoodRealtimeSubscription {
  final RealtimeChannel _channel;
  FoodRealtimeSubscription._(this._channel);

  Future<void> cancel() async {
    await Supabase.instance.client.removeChannel(_channel);
  }
}

class PaymentsRealtimeSubscription {
  final RealtimeChannel _channel;
  PaymentsRealtimeSubscription._(this._channel);

  Future<void> cancel() async {
    await Supabase.instance.client.removeChannel(_channel);
  }
}

class RealtimeService {
  RealtimeService._();

  static SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Attendance subscription
  // ---------------------------------------------------------------------------

  /// Subscribe to all attendance tables for a given site.
  ///
  /// [onAnyChange] fires on any INSERT/UPDATE/DELETE across
  /// workers, attendance_records, attendance_batches, and
  /// attendance_batch_workers.  Callers should debounce if needed
  /// (typical: just reload the full list, not per-row updates).
  ///
  /// [siteId] is used as a filter where the schema supports it.
  static AttendanceRealtimeSubscription subscribeAttendance({
    String? siteId,
    required VoidCallback onAnyChange,
  }) {
    final channelName =
        'attendance-${siteId ?? 'all'}-${DateTime.now().millisecondsSinceEpoch}';

    final channel = _client.channel(channelName);

    // Workers table — changes affect enrollment / face data shown in mark tab
    _addTableListener(
      channel,
      RealtimeTable.workers,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    // Attendance records (regular workers)
    _addTableListener(
      channel,
      RealtimeTable.attendanceRecords,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    // Outside worker batches
    _addTableListener(
      channel,
      RealtimeTable.attendanceBatches,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    // Batch workers (no top-level site filter — filtered via batch join)
    _addTableListener(
      channel,
      RealtimeTable.attendanceBatchWorkers,
      filter: null,
      onEvent: onAnyChange,
    );

    channel.subscribe();

    return AttendanceRealtimeSubscription._(channel);
  }

  // ---------------------------------------------------------------------------
  // Food subscription
  // ---------------------------------------------------------------------------

  /// Subscribe to food_requests and food_submissions for a given site.
  static FoodRealtimeSubscription subscribeFood({
    String? siteId,
    required VoidCallback onAnyChange,
  }) {
    final channelName =
        'food-${siteId ?? 'all'}-${DateTime.now().millisecondsSinceEpoch}';

    final channel = _client.channel(channelName);

    _addTableListener(
      channel,
      RealtimeTable.foodRequests,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    _addTableListener(
      channel,
      RealtimeTable.foodSubmissions,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    channel.subscribe();

    return FoodRealtimeSubscription._(channel);
  }

  // ---------------------------------------------------------------------------
  // Payments subscription (Supplier Bills + Payments tabs)
  // ---------------------------------------------------------------------------

  /// Subscribe to supplier_bills, supplier_payment_requests,
  /// payment_accounts, and payment_ledger for a given site.
  static PaymentsRealtimeSubscription subscribePayments({
    String? siteId,
    required VoidCallback onAnyChange,
  }) {
    final channelName =
        'payments-${siteId ?? 'all'}-${DateTime.now().millisecondsSinceEpoch}';

    final channel = _client.channel(channelName);

    _addTableListener(
      channel,
      RealtimeTable.supplierBills,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    _addTableListener(
      channel,
      RealtimeTable.supplierPaymentRequests,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    _addTableListener(
      channel,
      RealtimeTable.paymentAccounts,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    _addTableListener(
      channel,
      RealtimeTable.paymentLedger,
      filter: siteId != null ? 'site_id=eq.$siteId' : null,
      onEvent: onAnyChange,
    );

    channel.subscribe();

    return PaymentsRealtimeSubscription._(channel);
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static void _addTableListener(
    RealtimeChannel channel,
    RealtimeTable table, {
    String? filter,
    required VoidCallback onEvent,
  }) {
    // Parse "column=eq.value" filter string into typed filter if provided
    PostgresChangeFilter? pgFilter;
    if (filter != null) {
      final parts = filter.split('=eq.');
      if (parts.length == 2) {
        pgFilter = PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: parts[0],
          value: parts[1],
        );
      }
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table.name,
      filter: pgFilter,
      callback: (_) => onEvent(),
    );
  }
}

/// Simple debouncer to avoid calling reload too many times when multiple
/// realtime events arrive in quick succession (e.g., batch insert of workers).
class RealtimeDebouncer {
  final Duration delay;
  RealtimeDebouncer({this.delay = const Duration(milliseconds: 600)});

  DateTime? _lastCall;
  bool _scheduled = false;
  VoidCallback? _pendingAction;

  void call(VoidCallback action) {
    _pendingAction = action;
    final now = DateTime.now();
    if (_lastCall == null ||
        now.difference(_lastCall!) > delay) {
      _lastCall = now;
      action();
      return;
    }
    if (!_scheduled) {
      _scheduled = true;
      Future.delayed(delay, () {
        _scheduled = false;
        _lastCall = DateTime.now();
        _pendingAction?.call();
      });
    }
  }
}
