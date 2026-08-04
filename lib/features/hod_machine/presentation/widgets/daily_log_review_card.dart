import 'package:flutter/material.dart';

import '../../domain/models/machine_daily_log.dart';
import 'machine_status_chip.dart';

/// Card for HOD review of a single daily machine log.
///
/// Displays machine info, hours, diesel, payment preview,
/// review actions (approve / reject / request revision),
/// and shows HOD note if previously reviewed.
class DailyLogReviewCard extends StatelessWidget {
  final MachineDailyLog log;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRequestRevision;
  final VoidCallback? onTap;

  const DailyLogReviewCard({
    super.key,
    required this.log,
    this.showActions = true,
    this.onApprove,
    this.onReject,
    this.onRequestRevision,
    this.onTap,
  });

  IconData _machineIcon(String? machineType) {
    switch (machineType?.toLowerCase()) {
      case 'heavy':
      case 'excavator':
      case 'dozer':
      case 'crane':
        return Icons.precision_manufacturing_rounded;
      case 'medium':
      case 'loader':
      case 'tractor':
        return Icons.agriculture_rounded;
      default:
        return Icons.construction_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(log.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(22)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          _machineIcon(log.location),
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.machineId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2340),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${log.location ?? 'Site'} • ${log.logDate.toString().substring(0, 10)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      MachineStatusChip(
                        label: log.status.displayLabel,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _metric('Hours', '${log.workingHours.toStringAsFixed(1)} h',
                          const Color(0xFF1565C0)),
                      const SizedBox(width: 8),
                      _metric('Diesel',
                          '${log.dieselLiters.toStringAsFixed(1)} L',
                          const Color(0xFFD97706)),
                      const SizedBox(width: 8),
                      _metric('Workers', '${log.workerCount}',
                          const Color(0xFF0FA37A)),
                    ],
                  ),
                  if (log.dieselAmount > 0 || log.betaAmount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E4F0)),
                      ),
                      child: Row(
                        children: [
                          if (log.dieselAmount > 0)
                            _paymentItem('Diesel',
                                '₹${log.dieselAmount.toStringAsFixed(0)}'),
                          if (log.betaAmount > 0) ...[
                            const SizedBox(width: 12),
                            _paymentItem('Beta',
                                '₹${log.betaAmount.toStringAsFixed(0)}'),
                          ],
                          if (log.extraBetaAmount > 0) ...[
                            const SizedBox(width: 12),
                            _paymentItem('Extra',
                                '₹${log.extraBetaAmount.toStringAsFixed(0)}'),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (log.hodNote != null && log.hodNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFD97706).withOpacity(0.2)),
                      ),
                      child: Text(
                        'HOD note: ${log.hodNote}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7A5C00),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showActions && log.status == DailyLogStatus.submitted) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRequestRevision,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Revision'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        side: const BorderSide(color: Color(0xFFE53935)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.verified_rounded, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0FA37A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(DailyLogStatus status) {
    switch (status) {
      case DailyLogStatus.draft:
        return const Color(0xFF64748B);
      case DailyLogStatus.submitted:
        return const Color(0xFF1565C0);
      case DailyLogStatus.approved:
        return const Color(0xFF0FA37A);
      case DailyLogStatus.revisionRequested:
        return const Color(0xFFD97706);
      case DailyLogStatus.rejected:
        return const Color(0xFFE53935);
    }
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentItem(String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(Icons.currency_rupee_rounded,
              size: 15, color: const Color(0xFF1565C0)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A2340),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
