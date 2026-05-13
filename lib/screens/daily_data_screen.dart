import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/payment_mode_selector.dart';

class DailyDataScreen extends StatefulWidget {
  const DailyDataScreen({super.key});

  @override
  State<DailyDataScreen> createState() => _DailyDataScreenState();
}

class _DailyDataScreenState extends State<DailyDataScreen> {
  String? _selectedMachine;
  final List<TimeBlock> _timeBlocks = [];
  final TextEditingController _usedAmountController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _betaController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, String>> _machines = [
    {'id': 'MCH-001', 'name': 'Excavator', 'type': 'Heavy', 'location': 'Site A'},
    {'id': 'MCH-002', 'name': 'Loader', 'type': 'Medium', 'location': 'Site A'},
    {'id': 'MCH-003', 'name': 'Crane', 'type': 'Heavy', 'location': 'Site B'},
    {'id': 'MCH-004', 'name': 'Dump Truck', 'type': 'Medium', 'location': 'Site B'},
    {'id': 'MCH-005', 'name': 'Compactor', 'type': 'Light', 'location': 'Site C'},
  ];

  @override
  void initState() {
    super.initState();
    // Add default time block
    _timeBlocks.add(TimeBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: TimeOfDay(hour: 8, minute: 0),
      endTime: TimeOfDay(hour: 17, minute: 0),
    ));
  }

  void _addTimeBlock() {
    setState(() {
      _timeBlocks.add(TimeBlock(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 13, minute: 0),
      ));
    });
  }

  void _removeTimeBlock(String id) {
    setState(() {
      _timeBlocks.removeWhere((block) => block.id == id);
    });
  }

  Future<void> _selectTime(BuildContext context, TimeBlock block, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? block.startTime : block.endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          block.startTime = picked;
        } else {
          block.endTime = picked;
        }
      });
    }
  }

  void _submitLog() {
    if (_selectedMachine == null) {
      _showSnackbar('Please select a machine', AppTheme.danger);
      return;
    }
    if (_usedAmountController.text.isEmpty) {
      _showSnackbar('Please enter used amount', AppTheme.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _showSnackbar('Daily log saved successfully!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _usedAmountController.clear();
    _dieselController.clear();
    _betaController.clear();
    _notesController.clear();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Daily Machines Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildStepCard(
              '1',
              'Select Machine ID',
              _buildMachineDropdown(),
              color: AppTheme.info,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '2',
              'Starting & Ending Time',
              _buildTimeBlocksSection(),
              color: AppTheme.warning,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '3',
              'Used Amount & Payment',
              _buildUsedAmount(),
              color: AppTheme.success,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '4',
              'Verify Payment Account',
              _buildVerification(),
              color: AppTheme.info,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '5',
              'Diesel Consumption',
              _buildDieselField(),
              color: AppTheme.warning,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '6',
              'Beta (Advance / Incentive)',
              _buildBetaAmount(),
              color: AppTheme.success,
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              '7',
              'Additional Notes',
              _buildNotesField(),
              color: AppTheme.info,
            ),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.info.withOpacity(0.15), AppTheme.info.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('📋', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Machines Data',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Log every machine\'s daily activity, hours & payments',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.info.withOpacity(0.1), AppTheme.infoBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.info_outline, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Log Entry',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Record machine hours, fuel consumption, and payments for accurate tracking.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, Widget child, {required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMachineDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedMachine,
        decoration: const InputDecoration(
          hintText: 'Select a machine',
          prefixIcon: Icon(Icons.construction_outlined),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: _machines.map((machine) {
          return DropdownMenuItem(
            value: machine['id'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${machine['name']} (${machine['id']})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${machine['type']} • ${machine['location']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedMachine = value),
      ),
    );
  }

  Widget _buildTimeBlocksSection() {
    return Column(
      children: [
        ..._timeBlocks.asMap().entries.map((entry) {
          return _buildTimeBlockCard(entry.value, entry.key);
        }),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _addTimeBlock,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Shift Block'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.warning,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeBlockCard(TimeBlock block, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Shift Block',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_timeBlocks.length > 1)
                IconButton(
                  onPressed: () => _removeTimeBlock(block.id),
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerField(
                  'Start Time',
                  block.startTime,
                  () => _selectTime(context, block, true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, size: 18, color: AppTheme.textMuted),
              ),
              Expanded(
                child: _buildTimePickerField(
                  'End Time',
                  block.endTime,
                  () => _selectTime(context, block, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerField(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsedAmount() {
    return Column(
      children: [
        TextField(
          controller: _usedAmountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Used Amount',
            hintText: 'Enter amount in ₹',
            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        const PaymentModeSelector(label: 'Payment Mode'),
      ],
    );
  }

  Widget _buildVerification() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 20, color: AppTheme.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Saved Account',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                    Text(
                      '****7890 | UPI ID: machine@bank',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, size: 16, color: AppTheme.success),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppTheme.success),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Auto-saved from last entry. Verify before confirming.',
                  style: TextStyle(fontSize: 11, color: AppTheme.success),
                ),
              ),
              GestureDetector(
                onTap: () => _showSnackbar('Account verified!', AppTheme.success),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Verify',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDieselField() {
    return TextField(
      controller: _dieselController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Diesel (₹)',
        hintText: 'Enter diesel amount consumed today',
        prefixIcon: const Icon(Icons.local_gas_station_outlined, size: 18),
        suffixText: '₹',
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildBetaAmount() {
    return Column(
      children: [
        TextField(
          controller: _betaController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Beta Amount',
            hintText: 'Advance or incentive payment',
            prefixIcon: const Icon(Icons.attach_money, size: 18),
            suffixText: '₹',
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        const PaymentModeSelector(label: 'Beta Payment Mode'),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Notes',
        hintText: 'Any special events or remarks for today...',
        prefixIcon: const Icon(Icons.notes_outlined, size: 18),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSummaryCard() {
    double usedAmount = double.tryParse(_usedAmountController.text) ?? 0;
    double dieselAmount = double.tryParse(_dieselController.text) ?? 0;
    double betaAmount = double.tryParse(_betaController.text) ?? 0;
    double total = usedAmount + dieselAmount + betaAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem('Used', '₹${usedAmount.toStringAsFixed(0)}', Icons.shopping_cart),
              const SizedBox(width: 12),
              _buildSummaryItem('Diesel', '₹${dieselAmount.toStringAsFixed(0)}', Icons.local_gas_station),
              const SizedBox(width: 12),
              _buildSummaryItem('Beta', '₹${betaAmount.toStringAsFixed(0)}', Icons.attach_money),
              const SizedBox(width: 12),
              _buildSummaryItem('Total', '₹${total.toStringAsFixed(0)}', Icons.calculate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitLog,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.info,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Save Daily Log',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

// Helper class for time blocks
class TimeBlock {
  final String id;
  TimeOfDay startTime;
  TimeOfDay endTime;

  TimeBlock({
    required this.id,
    required this.startTime,
    required this.endTime,
  });
}