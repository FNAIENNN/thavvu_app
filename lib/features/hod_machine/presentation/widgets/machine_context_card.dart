import 'package:flutter/material.dart';

/// Displays the current HOD workspace context: site, Thavvu Point, supervisor.
class MachineContextCard extends StatelessWidget {
  final String siteName;
  final String? siteId;
  final String? thavvuPointName;
  final String? supervisorName;
  final String? hodId;

  const MachineContextCard({
    super.key,
    required this.siteName,
    this.siteId,
    this.thavvuPointName,
    this.supervisorName,
    this.hodId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_outlined,
                  size: 16, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  siteName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2340),
                  ),
                ),
              ),
              if (hodId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hodId!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
            ],
          ),
          if (thavvuPointName != null || supervisorName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (thavvuPointName != null) ...[
                  _buildInfoChip(Icons.account_tree_outlined, thavvuPointName!),
                  const SizedBox(width: 8),
                ],
                if (supervisorName != null)
                  _buildInfoChip(Icons.person_outline, supervisorName!),
              ],
            ),
          ],
          if (siteId != null) ...[
            const SizedBox(height: 8),
            Text(
              siteId!,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF64748B).withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF1565C0)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2340),
            ),
          ),
        ],
      ),
    );
  }
}
