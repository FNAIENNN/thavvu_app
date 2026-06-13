import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/photo_capture_card.dart';
import '../widgets/advance_payment_request.dart';
import '../widgets/diesel_consumption_table.dart';

class MachinesEntryScreen extends StatefulWidget {
  final bool isHOD;

  const MachinesEntryScreen({super.key, required this.isHOD});

  @override
  State<MachinesEntryScreen> createState() => _MachinesEntryScreenState();
}

class _MachinesEntryScreenState extends State<MachinesEntryScreen> {
  // Supervisor fields
  final TextEditingController _vehicleNumberController =
      TextEditingController();
  final TextEditingController _dieselLitersController = TextEditingController();
  final TextEditingController _dieselAmountController = TextEditingController();
  String? _selectedFuelType;
  String? _selectedStockPoint;
  bool _isSubmitting = false;

  // For plus symbol - additional diesel entries
  bool _showAdditionalDieselForm = false;
  List<Map<String, dynamic>> _additionalDieselEntries = [];

  // Temporary controllers for additional entry
  String? _tempFuelType;
  String? _tempStockPoint;
  final TextEditingController _tempLitersController = TextEditingController();
  final TextEditingController _tempAmountController = TextEditingController();

  // For diesel history
  double _totalDieselDeficit = 0.0;
  List<Map<String, dynamic>> _dieselHistory = [];

  // HOD fields
  final TextEditingController _machineIdController = TextEditingController();
  final TextEditingController _operatorNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _usedAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedVehicleType;
  String? _selectedBillingType;
  String? _selectedDieselInclusion;
  String? _selectedSupplierName;
  String? _selectedSupplierType;
  bool _showDieselTable = false;
  String? _selectedPaymentMethod;
  String? _selectedUsedPaymentMethod;
  String? _selectedAdvanceMode;
  String? _selectedEntryMethod;
  String? _selectedUsedAdvanceMode;
  String? _selectedUsedEntryMethod;
  double _cashLimit = 50000.0;
  double _dieselRemainingStock = 1250.0;

  final List<Map<String, dynamic>> _suppliers = [
    {
      'name': 'ABC Suppliers',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.5
    },
    {
      'name': 'XYZ Traders',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.2
    },
    {
      'name': 'Global Machinery',
      'type': 'temporary',
      'validUntil': '2024-12-31',
      'rating': 3.8
    },
    {
      'name': 'Local Parts Co.',
      'type': 'temporary',
      'validUntil': '2024-06-30',
      'rating': 4.0
    },
    {
      'name': 'Industrial Supplies',
      'type': 'permanent',
      'validUntil': null,
      'rating': 4.7
    },
    {
      'name': 'Metro Equipment',
      'type': 'temporary',
      'validUntil': '2024-09-15',
      'rating': 3.5
    },
  ];

  final List<String> _vehicleTypes = [
    'Poclain',
    'Tractor',
    'Dozer',
    'Excavator',
    'Loader',
    'Crane',
    'Backhoe',
    'Grader',
    'Roller',
    'Dumper',
    'Forklift',
    'Bulldozer'
  ];
  final List<String> _billingTypes = ['Hourly', 'Daily', 'Weekly', 'Per Trip'];
  final List<String> _fuelTypes = ['Diesel', 'Petrol', 'CNG', 'Electric'];
  final List<String> _stockPoints = [
    'Main Depot',
    'Site A',
    'Site B',
    'Warehouse 1',
    'Fuel Station 3'
  ];

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _dieselLitersController.dispose();
    _dieselAmountController.dispose();
    _tempLitersController.dispose();
    _tempAmountController.dispose();
    _machineIdController.dispose();
    _operatorNameController.dispose();
    _amountController.dispose();
    _usedAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showAdditionalDieselFormFields() {
    setState(() {
      _showAdditionalDieselForm = true;
    });
  }

  void _cancelAdditionalDieselForm() {
    setState(() {
      _showAdditionalDieselForm = false;
      _clearTempFields();
    });
  }

  void _clearTempFields() {
    _tempFuelType = null;
    _tempStockPoint = null;
    _tempLitersController.clear();
    _tempAmountController.clear();
  }

  void _addAdditionalDieselEntry() {
    if (_tempFuelType == null) {
      _showSnackbar('Please select fuel type', AppTheme.warning);
      return;
    }
    if (_tempStockPoint == null) {
      _showSnackbar('Please select stock point', AppTheme.warning);
      return;
    }
    if (_tempLitersController.text.isEmpty) {
      _showSnackbar('Please enter liters', AppTheme.danger);
      return;
    }
    if (_tempAmountController.text.isEmpty) {
      _showSnackbar('Please enter amount', AppTheme.danger);
      return;
    }

    setState(() {
      _additionalDieselEntries.add({
        'fuelType': _tempFuelType,
        'stockPoint': _tempStockPoint,
        'liters': double.tryParse(_tempLitersController.text) ?? 0,
        'amount': double.tryParse(_tempAmountController.text) ?? 0,
        'date': DateTime.now().toString().substring(0, 16),
      });
      _clearTempFields();
      _showAdditionalDieselForm = false;
    });
    _showSnackbar('Additional diesel entry added', AppTheme.success);
  }

  void _removeAdditionalDieselEntry(int index) {
    setState(() {
      _additionalDieselEntries.removeAt(index);
    });
  }

  double get _totalAdditionalDieselLiters {
    double total = 0;
    for (var entry in _additionalDieselEntries) {
      total += entry['liters'];
    }
    return total;
  }

  double get _totalAdditionalDieselAmount {
    double total = 0;
    for (var entry in _additionalDieselEntries) {
      total += entry['amount'];
    }
    return total;
  }

  void _addDieselToHistory(
      double billed, double received, String vehicleNumber) {
    setState(() {
      _dieselHistory.insert(0, {
        'billed': billed,
        'received': received,
        'vehicleNumber': vehicleNumber,
        'date': DateTime.now().toString().substring(0, 16),
      });
    });
  }

  Future<void> _submitSupervisorForm() async {
    if (_vehicleNumberController.text.isEmpty) {
      _showSnackbar('Please enter Vehicle Number', AppTheme.danger);
      return;
    }
    if (_selectedFuelType == null) {
      _showSnackbar('Please select Type of Fuel', AppTheme.warning);
      return;
    }
    if (_selectedStockPoint == null) {
      _showSnackbar('Please select Stock Point', AppTheme.warning);
      return;
    }
    if (_dieselLitersController.text.isEmpty) {
      _showSnackbar('Please enter Number of Liters', AppTheme.danger);
      return;
    }
    if (_dieselAmountController.text.isEmpty) {
      _showSnackbar('Please enter Amount', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));

    double billed = double.tryParse(_dieselLitersController.text) ?? 0;
    double received = billed;
    _addDieselToHistory(billed, received, _vehicleNumberController.text);

    setState(() => _isSubmitting = false);
    _showSnackbar('Diesel entry submitted successfully!', AppTheme.success);
    _clearSupervisorForm();
  }

  void _clearSupervisorForm() {
    _vehicleNumberController.clear();
    _dieselLitersController.clear();
    _dieselAmountController.clear();
    setState(() {
      _selectedFuelType = null;
      _selectedStockPoint = null;
    });
  }

  void _submitHODForm() {
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
    if (_selectedSupplierName == null) {
      _showSnackbar('Please select Supplier Name', AppTheme.warning);
      return;
    }
    if (_selectedBillingType == null) {
      _showSnackbar('Please select Billing Type', AppTheme.warning);
      return;
    }
    if (_selectedDieselInclusion == null) {
      _showSnackbar('Please select Diesel Inclusion', AppTheme.warning);
      return;
    }
    if (_selectedPaymentMethod == null) {
      _showSnackbar(
          'Please select Fair Amount payment method', AppTheme.warning);
      return;
    }
    if (_selectedPaymentMethod == 'cash' && _amountController.text.isEmpty) {
      _showSnackbar('Please enter Fair Amount', AppTheme.danger);
      return;
    }

    if (_selectedPaymentMethod == 'cash') {
      double amount = double.tryParse(_amountController.text) ?? 0;
      if (amount > _cashLimit) {
        _showSnackbar(
            'Amount exceeds HOD limit of ₹${_cashLimit.toStringAsFixed(0)}',
            AppTheme.danger);
        return;
      }
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _showSnackbar('Machine submitted for HOD approval!', AppTheme.success);
      _clearHODForm();
    });
  }

  void _clearHODForm() {
    _machineIdController.clear();
    _operatorNameController.clear();
    _vehicleNumberController.clear();
    _amountController.clear();
    _usedAmountController.clear();
    _notesController.clear();
    setState(() {
      _selectedVehicleType = null;
      _selectedBillingType = null;
      _selectedDieselInclusion = null;
      _selectedSupplierName = null;
      _selectedSupplierType = null;
      _selectedPaymentMethod = null;
      _selectedUsedPaymentMethod = null;
      _selectedAdvanceMode = null;
      _selectedEntryMethod = null;
      _selectedUsedAdvanceMode = null;
      _selectedUsedEntryMethod = null;
      _showDieselTable = false;
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

  // ---------- Supervisor UI ----------
  Widget _buildSupervisorUI() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Machine Entry'),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
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
            _buildSupervisorHeader(),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Number Field
                    const Text('1. Enter Vehicle Number',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _vehicleNumberController,
                      decoration: InputDecoration(
                        hintText: 'e.g., MH-01-AB-1234',
                        prefixIcon: const Icon(Icons.directions_car),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Diesel Details Header (without stock indicator)
                    const Text('2. Diesel Information',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),

                    // Main Diesel Entry Fields
                    DropdownButtonFormField<String>(
                      value: _selectedFuelType,
                      decoration: InputDecoration(
                        labelText: 'Type of Fuel',
                        prefixIcon: const Icon(Icons.local_gas_station),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _fuelTypes
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedFuelType = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedStockPoint,
                      decoration: InputDecoration(
                        labelText: 'Stock Point',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _stockPoints
                          .map((point) => DropdownMenuItem(
                              value: point, child: Text(point)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedStockPoint = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dieselLitersController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Number of Liters',
                        prefixIcon: const Icon(Icons.straighten),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _dieselAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    // Plus Symbol Button at the bottom of Diesel Details
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showAdditionalDieselFormFields,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primary, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add,
                                color: AppTheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text('Add Another Diesel Entry',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),

                    // Additional Diesel Form (appears when plus is clicked)
                    if (_showAdditionalDieselForm) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.warning.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('NEW ENTRY',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                                const Spacer(),
                                Text('Additional Diesel Entry',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.warning)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _tempFuelType,
                              decoration: InputDecoration(
                                labelText: 'Type of Fuel',
                                prefixIcon: const Icon(Icons.local_gas_station,
                                    size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _fuelTypes
                                  .map((type) => DropdownMenuItem(
                                      value: type, child: Text(type)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _tempFuelType = value),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _tempStockPoint,
                              decoration: InputDecoration(
                                labelText: 'Stock Point',
                                prefixIcon:
                                    const Icon(Icons.location_on, size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _stockPoints
                                  .map((point) => DropdownMenuItem(
                                      value: point, child: Text(point)))
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => _tempStockPoint = value),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tempLitersController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Number of Liters',
                                prefixIcon:
                                    const Icon(Icons.straighten, size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _tempAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount (₹)',
                                prefixIcon:
                                    const Icon(Icons.currency_rupee, size: 18),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _cancelAdditionalDieselForm,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                    ),
                                    child: const Text('Cancel',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addAdditionalDieselEntry,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.warning),
                                    child: const Text('Add Entry'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Display added additional diesel entries
                    if (_additionalDieselEntries.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.list,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                    'Additional Entries (${_additionalDieselEntries.length})',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text(
                                    'Total: ${_totalAdditionalDieselLiters.toStringAsFixed(1)}L',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _additionalDieselEntries.length,
                              itemBuilder: (context, index) {
                                final entry = _additionalDieselEntries[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color:
                                              AppTheme.warning.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.local_gas_station,
                                            size: 16,
                                            color: AppTheme.warning),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(entry['fuelType'],
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                '${entry['liters']}L - ₹${entry['amount']}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            _removeAdditionalDieselEntry(index),
                                        child: const Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSupervisorForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Diesel Entry',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupervisorHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.warning.withOpacity(0.15),
              AppTheme.warning.withOpacity(0.05)
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('⛽', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quick Diesel Entry',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Supervisor: Enter vehicle number and diesel details below',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- HOD UI ----------
  Widget _buildHODUI() {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Machine Entry'),
        backgroundColor: const Color(0xFF0F3460),
        elevation: 0,
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
            _buildDieselRemainingStockCard(),
            const SizedBox(height: 16),
            _buildStepCard('1', 'Machine ID', _buildMachineIdField(),
                color: AppTheme.warning),
            const SizedBox(height: 12),
            _buildStepCard('2', 'Supplier Name', _buildSupplierNameField(),
                color: AppTheme.info),
            const SizedBox(height: 12),
            _buildStepCard('3', 'Operator Name', _buildOperatorField(),
                color: AppTheme.success),
            const SizedBox(height: 12),
            _buildStepCard('4', 'Vehicle Details', _buildVehicleDetails(),
                color: AppTheme.primary),
            const SizedBox(height: 12),
            _buildStepCard('5', 'Billing Mode', _buildBillingMode(),
                color: AppTheme.warning),
            const SizedBox(height: 12),
            _buildStepCard('6', 'Diesel Inclusion', _buildDieselInclusion(),
                color: AppTheme.info),
            const SizedBox(height: 12),
            if (_showDieselTable) ...[
              _buildStepCard('6a', 'Diesel Consumption Details',
                  _buildDieselConsumptionTable(),
                  color: AppTheme.warning),
              const SizedBox(height: 12),
            ],
            _buildStepCard('7', 'Fair Amount', _buildFairAmount(),
                color: AppTheme.success),
            const SizedBox(height: 12),
            _buildStepCard('8', 'Advance Payments', _buildAdvancePayments(),
                color: AppTheme.danger),
            const SizedBox(height: 12),
            _buildStepCard('9', 'Additional Notes', _buildNotesField(),
                color: AppTheme.success),
            const SizedBox(height: 12),
            _buildStepCard('10', 'Opening Photo', _buildPhotoCard(),
                color: AppTheme.warning),
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
            gradient: LinearGradient(colors: [
              AppTheme.warning.withOpacity(0.15),
              AppTheme.warning.withOpacity(0.05)
            ]),
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
              Text('New Machine Registration',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Register a new machine — pending HOD approval',
                  style:
                      TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
              _buildProgressStep('2', 'Supplier', 2),
              _buildProgressLine(),
              _buildProgressStep('3', 'Operator', 3),
              _buildProgressLine(),
              _buildProgressStep('4', 'Vehicle', 4),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStep('5', 'Billing', 5),
              _buildProgressLine(),
              _buildProgressStep('6', 'Diesel', 6),
              _buildProgressLine(),
              _buildProgressStep('7', 'Fair Amt', 7),
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
            shape: BoxShape.circle,
            color: isActive ? AppTheme.warning : AppTheme.surface,
            border: Border.all(
                color: isActive ? AppTheme.warning : AppTheme.border),
          ),
          alignment: Alignment.center,
          child: Text(number,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppTheme.textMuted)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isActive ? AppTheme.warning : AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildProgressLine() {
    return Expanded(child: Container(height: 2, color: AppTheme.border));
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.warningBg, AppTheme.warningBg]),
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
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.info_outline,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Updated Workflow',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning)),
                SizedBox(height: 4),
                Text(
                    'ID · Supplier · Operator · Vehicle · Billing · Diesel · Fair Amt · Advance · Notes · Photo',
                    style: TextStyle(fontSize: 11, color: AppTheme.warning)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDieselRemainingStockCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppTheme.info.withOpacity(0.1), AppTheme.infoBg]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.local_gas_station,
                color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Diesel Remaining Stock',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    '${_dieselRemainingStock.toStringAsFixed(1)} litres available',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.info)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _dieselRemainingStock < 100
                  ? AppTheme.dangerBg
                  : AppTheme.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _dieselRemainingStock < 100 ? 'Low Stock' : 'Available',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _dieselRemainingStock < 100
                      ? AppTheme.danger
                      : AppTheme.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step, String title, Widget child,
      {required Color color}) {
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
                    gradient:
                        LinearGradient(colors: [color, color.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMachineIdField() {
    return Column(
      children: [
        _buildTextField('Enter unique serial number (temp ID)',
            controller: _machineIdController),
        const SizedBox(height: 10),
        const HodApprovalBadge(),
      ],
    );
  }

  Widget _buildSupplierNameField() {
    final filteredSuppliers = _suppliers.where((s) {
      if (_selectedSupplierType == 'permanent') return s['type'] == 'permanent';
      if (_selectedSupplierType == 'temporary') return s['type'] == 'temporary';
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Text('Supplier Type: ',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              _buildSupplierTypeChip('All', null),
              const SizedBox(width: 6),
              _buildSupplierTypeChip('Permanent', 'permanent'),
              const SizedBox(width: 6),
              _buildSupplierTypeChip('Temporary', 'temporary'),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: DropdownButtonFormField<String>(
            value: _selectedSupplierName,
            decoration: InputDecoration(
              hintText: 'Select supplier',
              prefixIcon: Icon(
                  _selectedSupplierType == 'temporary'
                      ? Icons.access_time
                      : Icons.business,
                  size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: filteredSuppliers.map((supplier) {
              final isTemp = supplier['type'] == 'temporary';
              return DropdownMenuItem<String>(
                value: supplier['name'],
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier['name'],
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          if (isTemp && supplier['validUntil'] != null)
                            Text('Valid until: ${supplier['validUntil']}',
                                style: TextStyle(
                                    fontSize: 10, color: AppTheme.warning)),
                        ],
                      ),
                    ),
                    if (isTemp)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppTheme.warningBg,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('TEMP',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning)),
                      ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppTheme.warning),
                        const SizedBox(width: 2),
                        Text(supplier['rating'].toString(),
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSupplierName = value;
                final supplier = _suppliers.firstWhere(
                    (s) => s['name'] == value,
                    orElse: () => {'type': 'permanent'});
                _selectedSupplierType = supplier['type'];
              });
            },
          ),
        ),
        if (_selectedSupplierName != null) ...[
          const SizedBox(height: 12),
          _buildSupplierDetailsCard(),
        ],
        const SizedBox(height: 8),
        const HodApprovalBadge(text: 'Supplier list managed by HOD'),
      ],
    );
  }

  Widget _buildSupplierTypeChip(String label, String? type) {
    final isSelected = _selectedSupplierType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSupplierType = type;
          _selectedSupplierName = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (type == 'temporary' ? AppTheme.warning : AppTheme.info)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? (type == 'temporary' ? AppTheme.warning : AppTheme.info)
                  : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }

  Widget _buildSupplierDetailsCard() {
    final supplier = _suppliers.firstWhere(
        (s) => s['name'] == _selectedSupplierName,
        orElse: () => {});
    if (supplier.isEmpty) return const SizedBox.shrink();
    final isTemp = supplier['type'] == 'temporary';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTemp ? AppTheme.warningBg : AppTheme.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                (isTemp ? AppTheme.warning : AppTheme.info).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(isTemp ? Icons.access_time : Icons.verified,
                  size: 18, color: isTemp ? AppTheme.warning : AppTheme.info),
              const SizedBox(width: 8),
              Text(isTemp ? 'Temporary Supplier' : 'Permanent Supplier',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isTemp ? AppTheme.warning : AppTheme.info)),
            ],
          ),
          if (isTemp && supplier['validUntil'] != null) ...[
            const SizedBox(height: 4),
            Text('Valid until: ${supplier['validUntil']}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: AppTheme.warning),
              const SizedBox(width: 4),
              Text('Rating: ${supplier['rating']}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorField() {
    return _buildTextField('Enter full operator name',
        controller: _operatorNameController);
  }

  Widget _buildVehicleDetails() {
    return Column(
      children: [
        _buildTextField('Vehicle number e.g. TS09AB1234',
            controller: _vehicleNumberController),
        const SizedBox(height: 12),
        const Text('Vehicle Type',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: DropdownButtonFormField<String>(
            value: _selectedVehicleType,
            decoration: const InputDecoration(
              hintText: 'Select vehicle type',
              prefixIcon: Icon(Icons.agriculture, size: 18),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _vehicleTypes.map((type) {
              IconData icon;
              switch (type) {
                case 'Poclain':
                  icon = Icons.construction;
                  break;
                case 'Tractor':
                  icon = Icons.agriculture;
                  break;
                case 'Dozer':
                  icon = Icons.landscape;
                  break;
                case 'Excavator':
                  icon = Icons.build;
                  break;
                case 'Loader':
                  icon = Icons.inventory;
                  break;
                case 'Crane':
                  icon = Icons.upgrade;
                  break;
                default:
                  icon = Icons.precision_manufacturing;
              }
              return DropdownMenuItem(
                  value: type,
                  child: Row(children: [
                    Icon(icon, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(type)
                  ]));
            }).toList(),
            onChanged: (value) => setState(() => _selectedVehicleType = value),
          ),
        ),
      ],
    );
  }

  Widget _buildBillingMode() {
    return Column(
      children: [
        const Text('Billing Type',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
          child: DropdownButtonFormField<String>(
            value: _selectedBillingType,
            decoration: const InputDecoration(
              hintText: 'Select billing type',
              prefixIcon: Icon(Icons.receipt_long, size: 18),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _billingTypes.map((type) {
              IconData icon;
              Color color;
              switch (type) {
                case 'Hourly':
                  icon = Icons.access_time;
                  color = AppTheme.info;
                  break;
                case 'Daily':
                  icon = Icons.calendar_today;
                  color = AppTheme.success;
                  break;
                case 'Weekly':
                  icon = Icons.date_range;
                  color = AppTheme.warning;
                  break;
                case 'Per Trip':
                  icon = Icons.local_shipping;
                  color = AppTheme.primary;
                  break;
                default:
                  icon = Icons.receipt;
                  color = AppTheme.textSecondary;
              }
              return DropdownMenuItem(
                  value: type,
                  child: Row(children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(type)
                  ]));
            }).toList(),
            onChanged: (value) => setState(() => _selectedBillingType = value),
          ),
        ),
      ],
    );
  }

  Widget _buildDieselInclusion() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedDieselInclusion = 'With diesel';
              _showDieselTable = true;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedDieselInclusion == 'With diesel'
                    ? AppTheme.success
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _selectedDieselInclusion == 'With diesel'
                        ? AppTheme.success
                        : AppTheme.border),
              ),
              child: Column(children: [
                Icon(Icons.local_gas_station,
                    size: 24,
                    color: _selectedDieselInclusion == 'With diesel'
                        ? Colors.white
                        : AppTheme.textSecondary),
                const SizedBox(height: 4),
                Text('With Diesel',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedDieselInclusion == 'With diesel'
                            ? Colors.white
                            : AppTheme.textSecondary)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedDieselInclusion = 'Without diesel';
              _showDieselTable = true;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _selectedDieselInclusion == 'Without diesel'
                    ? AppTheme.danger
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _selectedDieselInclusion == 'Without diesel'
                        ? AppTheme.danger
                        : AppTheme.border),
              ),
              child: Column(children: [
                Icon(Icons.ev_station,
                    size: 24,
                    color: _selectedDieselInclusion == 'Without diesel'
                        ? Colors.white
                        : AppTheme.textSecondary),
                const SizedBox(height: 4),
                Text('Without Diesel',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedDieselInclusion == 'Without diesel'
                            ? Colors.white
                            : AppTheme.textSecondary)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDieselConsumptionTable() {
    return DieselConsumptionTable(
      fuelTypes: _fuelTypes,
      stockPoints: _stockPoints,
      onChanged: (data) => debugPrint('Diesel consumption data: $data'),
    );
  }

  Widget _buildFairAmount() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedPaymentMethod = 'cash';
            _selectedAdvanceMode = null;
            _selectedEntryMethod = null;
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedPaymentMethod == 'cash'
                  ? AppTheme.info.withOpacity(0.1)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedPaymentMethod == 'cash'
                      ? AppTheme.info
                      : AppTheme.border,
                  width: _selectedPaymentMethod == 'cash' ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.money,
                    color: _selectedPaymentMethod == 'cash'
                        ? AppTheme.info
                        : AppTheme.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Cash Payment',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Direct cash payment with HOD limit',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                if (_selectedPaymentMethod == 'cash')
                  const Icon(Icons.check_circle,
                      color: AppTheme.info, size: 24),
              ],
            ),
          ),
        ),
        if (_selectedPaymentMethod == 'cash') ...[
          const SizedBox(height: 12),
          _buildTextField('Fair Amount (₹)',
              keyboardType: TextInputType.number,
              controller: _amountController),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.info),
              const SizedBox(width: 8),
              Text('HOD Cash Limit: ₹${_cashLimit.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.info))
            ]),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() {
            _selectedPaymentMethod = 'advance';
            _amountController.clear();
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedPaymentMethod == 'advance'
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedPaymentMethod == 'advance'
                      ? AppTheme.success
                      : AppTheme.border,
                  width: _selectedPaymentMethod == 'advance' ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.request_quote,
                    color: _selectedPaymentMethod == 'advance'
                        ? AppTheme.success
                        : AppTheme.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Request for Advance',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Send request to Finance Department',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                if (_selectedPaymentMethod == 'advance')
                  const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 24),
              ],
            ),
          ),
        ),
        if (_selectedPaymentMethod == 'advance') ...[
          const SizedBox(height: 16),
          AdvancePaymentRequest(
            onMethodSelected: (mode, entryMethod) => setState(() {
              _selectedAdvanceMode = mode;
              _selectedEntryMethod = entryMethod;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancePayments() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _selectedUsedPaymentMethod = 'cash';
            _selectedUsedAdvanceMode = null;
            _selectedUsedEntryMethod = null;
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedUsedPaymentMethod == 'cash'
                  ? AppTheme.info.withOpacity(0.1)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedUsedPaymentMethod == 'cash'
                      ? AppTheme.info
                      : AppTheme.border,
                  width: _selectedUsedPaymentMethod == 'cash' ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.money,
                    color: _selectedUsedPaymentMethod == 'cash'
                        ? AppTheme.info
                        : AppTheme.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Advance Cash Payment',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Used amount payment with HOD limit',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                if (_selectedUsedPaymentMethod == 'cash')
                  const Icon(Icons.check_circle,
                      color: AppTheme.info, size: 24),
              ],
            ),
          ),
        ),
        if (_selectedUsedPaymentMethod == 'cash') ...[
          const SizedBox(height: 12),
          _buildTextField('Used Amount (₹)',
              keyboardType: TextInputType.number,
              controller: _usedAmountController),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.info),
              const SizedBox(width: 8),
              Text(
                  'HOD Advance Limit: ₹${(_cashLimit * 0.7).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.info))
            ]),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() {
            _selectedUsedPaymentMethod = 'advance';
            _usedAmountController.clear();
          }),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedUsedPaymentMethod == 'advance'
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _selectedUsedPaymentMethod == 'advance'
                      ? AppTheme.success
                      : AppTheme.border,
                  width: _selectedUsedPaymentMethod == 'advance' ? 2 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.payments,
                    color: _selectedUsedPaymentMethod == 'advance'
                        ? AppTheme.success
                        : AppTheme.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Request Advance from Finance',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Finance department will process payment',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                if (_selectedUsedPaymentMethod == 'advance')
                  const Icon(Icons.check_circle,
                      color: AppTheme.success, size: 24),
              ],
            ),
          ),
        ),
        if (_selectedUsedPaymentMethod == 'advance') ...[
          const SizedBox(height: 16),
          AdvancePaymentRequest(
            onMethodSelected: (mode, entryMethod) => setState(() {
              _selectedUsedAdvanceMode = mode;
              _selectedUsedEntryMethod = entryMethod;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesField() {
    return _buildTextField('Any remarks about this entry',
        maxLines: 3, controller: _notesController);
  }

  Widget _buildPhotoCard() {
    return const PhotoCaptureCard(
        label: 'Driver + vehicle opening photo', mandatory: true);
  }

  Widget _buildSummaryCard() {
    double fairAmt = _selectedPaymentMethod == 'cash'
        ? (double.tryParse(_amountController.text) ?? 0)
        : 0;
    double mainDieselQty = double.tryParse(_dieselLitersController.text) ?? 0;
    double usedAmt = _selectedUsedPaymentMethod == 'cash'
        ? (double.tryParse(_usedAmountController.text) ?? 0)
        : 0;
    double mainDieselCost = mainDieselQty * 100;
    double totalDieselCost = mainDieselCost + _totalAdditionalDieselAmount;
    double total = fairAmt + totalDieselCost + usedAmt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('Financial Summary',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem('Fair Amt', '₹${fairAmt.toStringAsFixed(0)}',
                  Icons.monetization_on),
              const SizedBox(width: 8),
              _buildSummaryItem(
                  'Diesel (${(mainDieselQty + _totalAdditionalDieselLiters).toStringAsFixed(1)} L)',
                  '₹${totalDieselCost.toStringAsFixed(0)}',
                  Icons.local_gas_station),
              const SizedBox(width: 8),
              _buildSummaryItem(
                  'Advance', '₹${usedAmt.toStringAsFixed(0)}', Icons.payments),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ]),
          if (_additionalDieselEntries.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Additional Entries',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text('${_additionalDieselEntries.length} entries',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitHODForm,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.send_outlined, size: 20),
                SizedBox(width: 10),
                Text('Submit for HOD Approval',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
              ]),
      ),
    );
  }

  Widget _buildTextField(String hint,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      TextEditingController? controller}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isHOD ? _buildHODUI() : _buildSupervisorUI();
  }
}
