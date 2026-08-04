import 'package:flutter/material.dart';

import '../../domain/models/machine_daily_log.dart';
import 'machine_status_chip.dart';

/// Full-detail bottom sheet for HOD review of a daily machine log.
///
/// Displays all fields: machine info, shift details, diesel lines,
/// beta amounts, worker count, notes, and a review action bar.
class DailyLogDetailSheet extends StatelessWidget {
  final MachineDailyLog log;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestRevision;

  const DailyLogDetailSheet({
    super.key,
    required this.log,
    this.onApprove,
    this.onReject,
    this.onRequestRevision,
  });

  static void show({
    required BuildContext context,
    required MachineDailyLog log,
    VoidCallback? onApprove,
    VoidCallback? onReject,
    VoidCallback? onRequestRevision,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyLogDetailSheet(
        log: log,
        onApprove: onApprove,
        onReject: onReject,
        onRequestRevision: onRequestRevision,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = log.status == DailyLogStatus.submitted;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F6FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _header(context),
            const SizedBox(height: 16),
            _section('Machine Details', [
              _row('Machine ID', log.machineId),
              if (log.location != null) _row('Location', log.location!),
              _row('Date', log.logDate.toString().substring(0, 10)),
              _row('Working Hours',
                  '${log.workingHours.toStringAsFixed(2)} h'),
              _row('Worker Count', '${log.workerCount}'),
            ]),
            const SizedBox(height: 12),
            if (log.dieselLines.isNotEmpty) ...[
              _section('Diesel Usage', [
                ...log.dieselLines.map((dl) => _row(
                      '${dl.fuelType}${dl.stockPoint != null ? ' (${dl.stockPoint})' : ''}',
                      '${dl.liters.toStringAsFixed(1)} L · ₹${dl.amount.toStringAsFixed(0)}',
                    )),
                _row('Total Diesel',
                    '₹${log.dieselAmount.toStringAsFixed(0)}'),
              ]),
              const SizedBox(height: 12),
            ],
            _section('Beta & Payments', [
              _row('Beta Amount',
                  '₹${log.betaAmount.toStringAsFixed(0)}'),
              if (log.extraBetaAmount > 0)
                _row('Extra Beta',
                    '₹${log.extraBetaAmount.toStringAsFixed(0)}'),
            ]),
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section('Notes', [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    log.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ),
              ]),
            ],
            if (log.hodNote != null && log.hodNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section('HOD Review', [
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 6),
                  child: Text(
                    log.hodNote!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A5C00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 20),
            if (isPending) _reviewActions(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0F3460)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.article_outlined,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Log Detail',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A2340),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                log.machineId,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        MachineStatusChip(label: log.status.displayLabel),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2340),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRequestRevision?.call();
            },
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Revision'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD97706),
              side: const BorderSide(color: Color(0xFFD97706)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onReject?.call();
            },
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE53935),
              side: const BorderSide(color: Color(0xFFE53935)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onApprove?.call();
            },
            icon: const Icon(Icons.verified_rounded, size: 20),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0FA37A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
