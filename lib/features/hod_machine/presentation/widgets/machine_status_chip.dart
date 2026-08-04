import 'package:flutter/material.dart';

/// A small colored pill that displays a workflow status label.
class MachineStatusChip extends StatelessWidget {
  final String label;
  final Color? customColor;
  final double fontSize;

  const MachineStatusChip({
    super.key,
    required this.label,
    this.customColor,
    this.fontSize = 10,
  });

  Color _resolveColor() {
    if (customColor != null) return customColor!;
    final lower = label.toLowerCase();
    if (lower.contains('approve') || lower.contains('paid')) {
      return const Color(0xFF0FA37A);
    }
    if (lower.contains('reject') || lower.contains('revision')) {
      return const Color(0xFFE53935);
    }
    if (lower.contains('submitted') || lower.contains('finance')) {
      return const Color(0xFF1565C0);
    }
    if (lower.contains('pending') || lower.contains('draft')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
