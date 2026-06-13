// File: lib/widgets/advance_payment_request.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AdvancePaymentRequest extends StatefulWidget {
  final Function(String mode, String entryMethod)? onMethodSelected;

  const AdvancePaymentRequest({
    super.key,
    this.onMethodSelected,
  });

  @override
  State<AdvancePaymentRequest> createState() => _AdvancePaymentRequestState();
}

class _AdvancePaymentRequestState extends State<AdvancePaymentRequest> {
  String? _selectedMode; // 'upi' or 'bank'
  String? _selectedEntryMethod; // 'manual', 'photo', 'voice'
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _voiceNoteController = TextEditingController();

  void _notifyParent() {
    if (_selectedMode != null && _selectedEntryMethod != null) {
      widget.onMethodSelected?.call(_selectedMode!, _selectedEntryMethod!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment Mode Selection
          const Text(
            'Select Payment Mode',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPaymentModeCard(
                  'UPI',
                  Icons.qr_code,
                  'upi',
                  AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentModeCard(
                  'Bank Transfer',
                  Icons.account_balance,
                  'bank',
                  AppTheme.info,
                ),
              ),
            ],
          ),

          if (_selectedMode != null) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Entry Method Selection
            const Text(
              'Select Entry Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildEntryMethodChip('Manual', Icons.edit, 'manual'),
                const SizedBox(width: 8),
                _buildEntryMethodChip('Photo', Icons.camera_alt, 'photo'),
                const SizedBox(width: 8),
                _buildEntryMethodChip('Voice', Icons.mic, 'voice'),
              ],
            ),

            if (_selectedEntryMethod != null) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              _buildEntryForm(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeCard(String title, IconData icon, String mode, Color color) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _selectedEntryMethod = null;
        });
        _notifyParent();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppTheme.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryMethodChip(String label, IconData icon, String method) {
    final isSelected = _selectedEntryMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedEntryMethod = method;
          });
          _notifyParent();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.warning : AppTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppTheme.warning : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedEntryMethod?.toUpperCase()} Entry',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          if (_selectedEntryMethod == 'manual') _buildManualEntry(),
          if (_selectedEntryMethod == 'photo') _buildPhotoEntry(),
          if (_selectedEntryMethod == 'voice') _buildVoiceEntry(),

          const SizedBox(height: 16),

          // Submit Request Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showSnackbar('Advance request sent to Finance Department', AppTheme.success);
                widget.onMethodSelected?.call(_selectedMode!, _selectedEntryMethod!);
              },
              icon: const Icon(Icons.send),
              label: const Text('Send to Finance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Column(
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount (₹)',
            prefixIcon: const Icon(Icons.currency_rupee),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedMode == 'upi') ...[
          TextField(
            controller: _upiIdController,
            decoration: InputDecoration(
              labelText: 'UPI ID',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        if (_selectedMode == 'bank') ...[
          TextField(
            controller: _accountNumberController,
            decoration: InputDecoration(
              labelText: 'Account Number',
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ifscController,
            decoration: InputDecoration(
              labelText: 'IFSC Code',
              prefixIcon: const Icon(Icons.code),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoEntry() {
    return Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 48,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Capture Payment Screenshot',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Implement camera capture
                  },
                  icon: const Icon(Icons.camera),
                  label: const Text('Take Photo'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '✓ Auto-extracts: Amount, UPI ID, Transaction ID',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceEntry() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  // Implement voice recording
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.danger.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap to Record',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Speak: Amount, Payment Mode, and Reference',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_voiceNoteController.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voice note recorded successfully',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _upiIdController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _voiceNoteController.dispose();
    super.dispose();
  }
}