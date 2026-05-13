import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PaymentMode { cash, upi, bank }

class PaymentModeSelector extends StatefulWidget {
  final PaymentMode? initialMode;
  final Function(PaymentMode)? onChanged;
  final String label;

  const PaymentModeSelector({
    super.key,
    this.initialMode,
    this.onChanged,
    this.label = 'Payment mode',
  });

  @override
  State<PaymentModeSelector> createState() => _PaymentModeSelectorState();
}

class _PaymentModeSelectorState extends State<PaymentModeSelector> {
  late PaymentMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode ?? PaymentMode.cash;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildModeButton(PaymentMode.cash, 'Cash', AppTheme.success),
            const SizedBox(width: 8),
            _buildModeButton(PaymentMode.upi, 'UPI', AppTheme.info),
            const SizedBox(width: 8),
            _buildModeButton(PaymentMode.bank, 'Bank', AppTheme.warning),
          ],
        ),
      ],
    );
  }

  Widget _buildModeButton(PaymentMode mode, String label, Color color) {
    final bool isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedMode = mode);
          widget.onChanged?.call(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : AppTheme.border,
              width: 0.8,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
