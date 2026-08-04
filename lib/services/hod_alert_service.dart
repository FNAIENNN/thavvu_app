import 'package:flutter/material.dart';

import '../models/hod_workflow_models.dart';

class HodAlertViewData {
  final String requestId;
  final String siteId;
  final String siteName;
  final String sitePlace;
  final String module;
  final String title;
  final String message;
  final ApprovalStatus status;
  final DateTime createdAt;
  final IconData icon;
  final Color color;
  final ApprovalRequestRecord request;

  const HodAlertViewData({
    required this.requestId,
    required this.siteId,
    required this.siteName,
    required this.sitePlace,
    required this.module,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.icon,
    required this.color,
    required this.request,
  });
}

/// Alert service boundary with local shared workflow data disabled.
///
/// Connect alerts to the backend repository/API when the real module workflows
/// are implemented.
class HodAlertService {
  const HodAlertService({Object? store});

  Future<List<HodAlertViewData>> alertsForHod(String hodId) async {
    final now = DateTime.now();
    final specs = <_AlertSpec>[
      _AlertSpec(
          'SITE-VJA-001',
          'Vijayawada River Bed',
          'Vijayawada',
          'Machines',
          'Machine entry pending',
          'Supervisor submitted vehicle and diesel details for HOD completion.'),
      _AlertSpec(
          'SITE-VJA-001',
          'Vijayawada River Bed',
          'Vijayawada',
          'Daily Data',
          'Daily machine log review',
          'Advance payment and bill upload are waiting in daily data.'),
      _AlertSpec(
          'SITE-AKV-002',
          'Akividu Canal Line',
          'Akividu',
          'Attendance',
          'Outside worker attendance',
          'Worker details, photo and geo-location are ready for HOD check.'),
      _AlertSpec(
          'SITE-RJM-003',
          'Rajahmundry Lift Point',
          'Rajahmundry',
          'Stock',
          'Stock verification alert',
          'Stock summary, supplier and invoice activity need HOD review.'),
      _AlertSpec(
          'SITE-VJA-001',
          'Vijayawada River Bed',
          'Vijayawada',
          'Rental',
          'Rental machine details',
          'Rental supplier, operator, fare and diesel option are pending.'),
      _AlertSpec('SITE-AKV-002', 'Akividu Canal Line', 'Akividu', 'Cash',
          'Cash request waiting', 'Supervisor cash spend request is ready.'),
      _AlertSpec(
          'SITE-RJM-003',
          'Rajahmundry Lift Point',
          'Rajahmundry',
          'Food',
          'Food count submitted',
          'Breakfast, lunch and snacks shift counts are available.'),
      _AlertSpec(
          'SITE-VJA-001',
          'Vijayawada River Bed',
          'Vijayawada',
          'Tasks',
          'Task proof uploaded',
          'Supervisor uploaded proof for assigned task/checklist.'),
      _AlertSpec(
          'SITE-AKV-002',
          'Akividu Canal Line',
          'Akividu',
          'Reports',
          'Report summary ready',
          'Module-wise reports and payment summaries are available.'),
      _AlertSpec(
          'SITE-RJM-003',
          'Rajahmundry Lift Point',
          'Rajahmundry',
          'Maps',
          'Map update request',
          'Supervisor requested a site map/specification update.'),
    ];

    return [
      for (var index = 0; index < specs.length; index++)
        HodAlertViewData(
          requestId: 'ALERT-${(index + 1).toString().padLeft(3, '0')}',
          siteId: specs[index].siteId,
          siteName: specs[index].siteName,
          sitePlace: specs[index].place,
          module: specs[index].module,
          title: specs[index].title,
          message: specs[index].message,
          status: ApprovalStatus.pending,
          createdAt: now.subtract(Duration(minutes: 12 * index)),
          icon: iconForModule(specs[index].module),
          color: colorForModule(specs[index].module),
          request: ApprovalRequestRecord(
            id: 'REQ-${(index + 1).toString().padLeft(3, '0')}',
            module: specs[index].module,
            title: specs[index].title,
            siteId: specs[index].siteId,
            supervisorId: 'SUP-${(index + 1).toString().padLeft(3, '0')}',
            status: ApprovalStatus.pending,
            createdAt: now.subtract(Duration(minutes: 12 * index)),
            payload: {'detail': specs[index].message},
          ),
        ),
    ];
  }

  static IconData iconForModule(String module) {
    switch (module) {
      case 'Machines':
      case 'New Machine':
        return Icons.construction_rounded;
      case 'Daily Data':
        return Icons.edit_calendar_rounded;
      case 'Attendance':
        return Icons.fingerprint_rounded;
      case 'Stock':
        return Icons.inventory_2_outlined;
      case 'Rental':
        return Icons.key_outlined;
      case 'Food':
        return Icons.restaurant_menu_outlined;
      case 'Cash':
        return Icons.account_balance_wallet_outlined;
      case 'Tasks':
        return Icons.task_alt_outlined;
      case 'Reports':
        return Icons.bar_chart_rounded;
      case 'Maps':
        return Icons.map_outlined;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  static Color colorForModule(String module) {
    switch (module) {
      case 'Machines':
      case 'New Machine':
        return const Color(0xFFD97706);
      case 'Daily Data':
      case 'Maps':
        return const Color(0xFF1976D2);
      case 'Attendance':
      case 'Cash':
      case 'Tasks':
        return const Color(0xFF0FA37A);
      case 'Stock':
      case 'Reports':
        return const Color(0xFF9C27B0);
      case 'Rental':
        return const Color(0xFFE53935);
      case 'Food':
        return const Color(0xFFE6A817);
      default:
        return const Color(0xFF1565C0);
    }
  }
}

class _AlertSpec {
  final String siteId;
  final String siteName;
  final String place;
  final String module;
  final String title;
  final String message;

  const _AlertSpec(
    this.siteId,
    this.siteName,
    this.place,
    this.module,
    this.title,
    this.message,
  );
}
