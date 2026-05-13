import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/payment_mode_selector.dart';
import '../widgets/photo_capture_card.dart';

class MachinesEntryScreen extends StatefulWidget {
  const MachinesEntryScreen({super.key});

  @override
  State<MachinesEntryScreen> createState() => _MachinesEntryScreenState();
}

class _MachinesEntryScreenState extends State<MachinesEntryScreen> {
  // Controllers
  final TextEditingController _machineIdController = TextEditingController();
  final TextEditingController _operatorNameController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dieselController = TextEditingController();
  final TextEditingController _usedAmountController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();
  final TextEditingController _supplierAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Selection variables
  String? _selectedVehicleType;
  String? _selectedBillingType;
  String? _selectedDieselInclusion;
  bool _isSubmitting = false;

  final List<String> _vehicleTypes = ['Poclain', 'Tractor', 'Dozer', 'Excavator', 'Loader'];
  final List<String> _billingTypes = ['Hourly', 'Daily', 'Weekly'];
  final List<String> _dieselOptions = ['With diesel', 'Without diesel'];

  @override
  void dispose() {
    _machineIdController.dispose();
    _operatorNameController.dispose();
    _vehicleNumberController.dispose();
    _amountController.dispose();
    _dieselController.dispose();
    _usedAmountController.dispose();
    _supplierNameController.dispose();
    _supplierAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitForm() {
    // Validation
    if (_machineIdController.text.isEmpty) {
      _showSnackbar('Please enter Machine ID', AppTheme.danger);
      return;
    }
    if (_operatorNameController.text.isEmpty) {
      _showSnackbar('Please enter Operator Name', AppTheme.danger);
      return;
    }
    if (_vehicleNumberController.text.isEmpty) {
      _showSnackbar('Please enter Vehicle Number', AppTheme.danger);
      return;
    }
    if (_selectedVehicleType == null) {
      _showSnackbar('Please select Vehicle Type', AppTheme.warning);
      return;
    }
    if (_selectedBillingType == null) {
      _showSnackbar('Please select Billing Type', AppTheme.warning);
      return;
    }
    if (_amountController.text.isEmpty) {
      _showSnackbar('Please enter Working Amount', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _showSnackbar('Machine submitted for HOD approval!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _machineIdController.clear();
    _operatorNameController.clear();
    _vehicleNumberController.clear();
    _amountController.clear();
    _dieselController.clear();
    _usedAmountController.clear();
    _supplierNameController.clear();
    _supplierAmountController.clear();
    _notesController.clear();
    setState(() {
      _selectedVehicleType = null;
      _selectedBillingType = null;
      _selectedDieselInclusion = null;
    });
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
        title: const Text('New Machines Entry'),
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
            _buildProgressIndicator(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildStepCard('1', 'Machine ID', _buildMachineIdField(), color: AppTheme.warning),
            const SizedBox(height: 12),
            _buildStepCard('2', 'Operator Name', _buildOperatorField(), color: AppTheme.info),
            const SizedBox(height: 12),
            _buildStepCard('3', 'Vehicle Details', _buildVehicleDetails(), color: AppTheme.success),
            const SizedBox(height: 12),
            _buildStepCard('4', 'Billing Mode', _buildBillingMode(), color: AppTheme.warning),
            const SizedBox(height: 12),
            _buildStepCard('5', 'Working Amount & Payment', _buildWorkingAmount(), color: AppTheme.info),
            const SizedBox(height: 12),
            _buildStepCard('6', 'Diesel Amount', _buildDieselField(), color: AppTheme.warning),
            const SizedBox(height: 12),
            _buildStepCard('7', 'Used Amount & Payment', _buildUsedAmount(), color: AppTheme.danger),
            const SizedBox(height: 12),
            _buildStepCard('8', 'Supplier Details', _buildSupplierDetails(), color: AppTheme.info),
            const SizedBox(height: 12),
            _buildStepCard('9', 'Additional Notes', _buildNotesField(), color: AppTheme.success),
            const SizedBox(height: 12),
            _buildStepCard('10', 'Opening Photo', _buildPhotoCard(), color: AppTheme.warning),
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
              colors: [AppTheme.warning.withOpacity(0.15), AppTheme.warning.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('🚜', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Machine Entry',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Register a new machine — pending HOD approval',
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

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStep('1', 'ID', 1),
              _buildProgressLine(),
              _buildProgressStep('2', 'Operator', 2),
              _buildProgressLine(),
              _buildProgressStep('3', 'Vehicle', 3),
              _buildProgressLine(),
              _buildProgressStep('4', 'Billing', 4),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStep('5', 'Working', 5),
              _buildProgressLine(),
              _buildProgressStep('6', 'Diesel', 6),
              _buildProgressLine(),
              _buildProgressStep('7', 'Used', 7),
              _buildProgressLine(),
              _buildProgressStep('8-10', 'More', 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String number, String label, int step) {
    final isActive = step <= 8;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.warning : AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? AppTheme.warning : AppTheme.border),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AppTheme.warning : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine() {
    return Expanded(
      child: Container(
        height: 2,
        color: AppTheme.border,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warningBg, AppTheme.warningBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.info_outline, color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '10-Step Workflow',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warning,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Machine ID · Operator · Vehicle · Billing · Working Amt · Diesel · Used Amt · Supplier · Notes · Photo',
                  style: TextStyle(fontSize: 11, color: AppTheme.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, Widget child, {required Color color}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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

  Widget _buildTextField(String hint, {TextInputType keyboardType = TextInputType.text, int maxLines = 1, TextEditingController? controller}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildMachineIdField() {
    return Column(
      children: [
        _buildTextField('Enter unique serial number (temp ID)', controller: _machineIdController),
        const SizedBox(height: 10),
        const HodApprovalBadge(),
      ],
    );
  }

  Widget _buildOperatorField() {
    return _buildTextField('Enter full operator name', controller: _operatorNameController);
  }

  Widget _buildVehicleDetails() {
    return Column(
      children: [
        _buildTextField('Vehicle number e.g. TS09AB1234', controller: _vehicleNumberController),
        const SizedBox(height: 12),
        const Text('Vehicle Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _vehicleTypes.map((type) {
            final isSelected = _selectedVehicleType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedVehicleType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.success : AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppTheme.success : AppTheme.border,
                    width: isSelected ? 0 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type == 'Poclain' ? Icons.construction : 
                      type == 'Tractor' ? Icons.agriculture : 
                      Icons.build,
                      size: 16,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBillingMode() {
    return Column(
      children: [
        const Text('Billing Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _billingTypes.map((type) {
            final isSelected = _selectedBillingType == type;
            return GestureDetector(
              onTap: () => setState(() => _selectedBillingType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.info : AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppTheme.info : AppTheme.border,
                    width: isSelected ? 0 : 0.8,
                  ),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildTextField('Amount (₹)', keyboardType: TextInputType.number, controller: _amountController),
        const SizedBox(height: 12),
        const Text('Diesel Inclusion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _dieselOptions.map((opt) {
            final isSelected = _selectedDieselInclusion == opt;
            return GestureDetector(
              onTap: () => setState(() => _selectedDieselInclusion = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.warning : AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppTheme.warning : AppTheme.border,
                    width: isSelected ? 0 : 0.8,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkingAmount() {
    return Column(
      children: [
        _buildTextField('Working amount (₹)', keyboardType: TextInputType.number, controller: _amountController),
        const SizedBox(height: 12),
        const PaymentModeSelector(label: 'Payment Mode'),
      ],
    );
  }

  Widget _buildDieselField() {
    return _buildTextField('Diesel amount (₹)', keyboardType: TextInputType.number, controller: _dieselController);
  }

  Widget _buildUsedAmount() {
    return Column(
      children: [
        _buildTextField('Used amount (₹)', keyboardType: TextInputType.number, controller: _usedAmountController),
        const SizedBox(height: 12),
        const PaymentModeSelector(label: 'Payment Mode'),
      ],
    );
  }

  Widget _buildSupplierDetails() {
    return Column(
      children: [
        _buildTextField('Supplier name', controller: _supplierNameController),
        const SizedBox(height: 10),
        _buildTextField('Supplier amount (₹)', keyboardType: TextInputType.number, controller: _supplierAmountController),
        const SizedBox(height: 12),
        const PaymentModeSelector(label: 'Supplier Payment Mode'),
      ],
    );
  }

  Widget _buildNotesField() {
    return _buildTextField('Any remarks about this entry', maxLines: 3, controller: _notesController);
  }

  Widget _buildPhotoCard() {
    return const PhotoCaptureCard(
      label: 'Driver + vehicle opening photo',
      mandatory: true,
    );
  }

  Widget _buildSummaryCard() {
    double workingAmt = double.tryParse(_amountController.text) ?? 0;
    double dieselAmt = double.tryParse(_dieselController.text) ?? 0;
    double usedAmt = double.tryParse(_usedAmountController.text) ?? 0;
    double supplierAmt = double.tryParse(_supplierAmountController.text) ?? 0;
    double total = workingAmt + dieselAmt + usedAmt + supplierAmt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.8)],
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
            'Financial Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem('Working', '₹${workingAmt.toStringAsFixed(0)}', Icons.work),
              const SizedBox(width: 8),
              _buildSummaryItem('Diesel', '₹${dieselAmt.toStringAsFixed(0)}', Icons.local_gas_station),
              const SizedBox(width: 8),
              _buildSummaryItem('Used', '₹${usedAmt.toStringAsFixed(0)}', Icons.shopping_cart),
              const SizedBox(width: 8),
              _buildSummaryItem('Supplier', '₹${supplierAmt.toStringAsFixed(0)}', Icons.business),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
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
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
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
                  Icon(Icons.send_outlined, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Submit for HOD Approval',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}