import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  String? _fromPoint;
  String? _toPoint;
  String? _selectedItem;
  String _transferStatus = '';
  bool _isInitiating = false;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, String>> _stockPoints = [
    {'id': 'SP-001', 'name': 'Site A — North', 'location': 'North Block'},
    {'id': 'SP-002', 'name': 'Site B — South', 'location': 'South Block'},
    {'id': 'SP-003', 'name': 'Warehouse Main', 'location': 'Central Store'},
    {'id': 'SP-004', 'name': 'Field Store', 'location': 'Field Office'},
  ];

  final List<Map<String, dynamic>> _items = [
    {'name': 'Diesel', 'icon': Icons.local_gas_station, 'unit': 'Liters', 'available': 500},
    {'name': 'Engine Oil', 'icon': Icons.oil_barrel, 'unit': 'Quarts', 'available': 120},
    {'name': 'Hydraulic Fluid', 'icon': Icons.water_drop, 'unit': 'Gallons', 'available': 80},
    {'name': 'Bolts & Nuts', 'icon': Icons.build, 'unit': 'Pieces', 'available': 1000},
    {'name': 'Grease', 'icon': Icons.cleaning_services, 'unit': 'Tubes', 'available': 50},
    {'name': 'Coolant', 'icon': Icons.ac_unit, 'unit': 'Liters', 'available': 200},
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initiateTransfer() {
    // Validation
    if (_fromPoint == null) {
      _showSnackbar('Please select source stock point', AppTheme.danger);
      return;
    }
    if (_toPoint == null) {
      _showSnackbar('Please select destination stock point', AppTheme.danger);
      return;
    }
    if (_fromPoint == _toPoint) {
      _showSnackbar('Source and destination cannot be the same', AppTheme.danger);
      return;
    }
    if (_selectedItem == null) {
      _showSnackbar('Please select an item to transfer', AppTheme.danger);
      return;
    }
    if (_quantityController.text.isEmpty) {
      _showSnackbar('Please enter quantity', AppTheme.danger);
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showSnackbar('Please enter a valid quantity', AppTheme.warning);
      return;
    }

    // Check available stock
    final selectedItemData = _items.firstWhere((item) => item['name'] == _selectedItem);
    if (quantity > selectedItemData['available']) {
      _showSnackbar('Insufficient stock! Only ${selectedItemData['available']} ${selectedItemData['unit']} available', AppTheme.danger);
      return;
    }

    setState(() => _isInitiating = true);
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isInitiating = false);
      _showSnackbar(
        'Transfer initiated from $_fromPoint to $_toPoint. Stock deducted from source.',
        AppTheme.success,
      );
      _clearForm();
    });
  }

  void _clearForm() {
    setState(() {
      _fromPoint = null;
      _toPoint = null;
      _selectedItem = null;
      _transferStatus = '';
      _quantityController.clear();
      _notesController.clear();
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

  String? _getItemAvailabilityMessage() {
    if (_selectedItem == null) return null;
    final item = _items.firstWhere((item) => item['name'] == _selectedItem);
    return 'Available: ${item['available']} ${item['unit']}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Internal Transfers'),
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
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildStepCard(
              step: 1,
              title: 'Source & Destination',
              color: AppTheme.danger,
              child: _buildSourceDestination(),
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              step: 2,
              title: 'Item & Quantity',
              color: AppTheme.warning,
              child: _buildItemQuantity(),
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              step: 3,
              title: 'Initiate Transfer',
              color: AppTheme.info,
              child: _buildInitiateWarning(),
            ),
            const SizedBox(height: 16),
            _buildStepCard(
              step: 4,
              title: 'Receiver Acknowledgment',
              color: AppTheme.success,
              child: _buildAcknowledgement(),
            ),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 16),
            const NoteBox(
              title: 'Two-way confirmation',
              content: 'The transfer flow is a handshake — supervisor initiates, receiver confirms. Both sides must act for stock counts to update on both ends.',
            ),
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
          child: const Text('🔄', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Internal Transfers',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'Move stock between stock points with confirmation',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                  'Two-Way Handshake Process',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                SizedBox(height: 4),
                Text(
                  'You initiate the transfer, and the destination must confirm receipt before stock updates on both sides.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required Color color,
    required Widget child,
  }) {
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
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('$step', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSourceDestination() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            value: _fromPoint,
            hint: const Text('From — source stock point'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.arrow_circle_up_outlined, size: 18, color: AppTheme.danger),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _stockPoints.map((point) => DropdownMenuItem(
              value: point['name'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(point['location']!, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            )).toList(),
            onChanged: (value) => setState(() => _fromPoint = value),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.info.withOpacity(0.3)),
          ),
          child: const Icon(Icons.keyboard_double_arrow_down, color: AppTheme.info, size: 22),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            value: _toPoint,
            hint: const Text('To — destination stock point'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.arrow_circle_down_outlined, size: 18, color: AppTheme.success),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _stockPoints.map((point) => DropdownMenuItem(
              value: point['name'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(point['location']!, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            )).toList(),
            onChanged: (value) => setState(() => _toPoint = value),
          ),
        ),
      ],
    );
  }

  Widget _buildItemQuantity() {
    final selectedItemData = _items.firstWhere(
      (item) => item['name'] == _selectedItem,
      orElse: () => {'name': '', 'icon': Icons.help, 'unit': '', 'available': 0},
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedItem,
            hint: const Text('Select item to transfer'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _items.map((item) {
              return DropdownMenuItem(
                value: item['name'],
                child: Row(
                  children: [
                    Icon(item['icon'], size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text('${item['available']} ${item['unit']} available', 
                              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedItem = value),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Quantity to transfer',
            hintText: 'Enter quantity',
            prefixIcon: const Icon(Icons.numbers, size: 18),
            suffixText: selectedItemData['unit'] != '' ? selectedItemData['unit'] : null,
            helperText: _getItemAvailabilityMessage(),
            helperStyle: TextStyle(
              color: _selectedItem != null && int.tryParse(_quantityController.text) != null &&
                      int.tryParse(_quantityController.text)! > (selectedItemData['available'] ?? 0)
                  ? AppTheme.danger
                  : AppTheme.textMuted,
            ),
            errorText: _selectedItem != null && _quantityController.text.isNotEmpty &&
                int.tryParse(_quantityController.text) != null &&
                int.tryParse(_quantityController.text)! > (selectedItemData['available'] ?? 0)
                ? 'Exceeds available stock'
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Transfer notes (optional)',
            hintText: 'Reason or special instructions...',
            prefixIcon: const Icon(Icons.notes_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInitiateWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.warningBg, AppTheme.warningBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_outlined, color: AppTheme.warning, size: 20),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Stock is immediately deducted from the source point when transfer is initiated. This action cannot be undone.',
              style: TextStyle(fontSize: 12, color: AppTheme.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 18, color: AppTheme.info),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'The destination stock point receives a notification to confirm receipt.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.infoBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Pending', style: TextStyle(fontSize: 10, color: AppTheme.info)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatusButton(
                label: 'Received',
                icon: Icons.check_circle_outline,
                color: AppTheme.success,
                status: 'Received',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusButton(
                label: 'Pending',
                icon: Icons.hourglass_empty_outlined,
                color: AppTheme.warning,
                status: 'Pending',
              ),
            ),
          ],
        ),
        if (_transferStatus == 'Received') ...[
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Stock has been updated at the destination point. Transfer completed successfully.',
                    style: TextStyle(fontSize: 12, color: AppTheme.success),
                  ),
                ),
                Icon(Icons.verified, color: AppTheme.success, size: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required String status,
  }) {
    final isSelected = _transferStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _transferStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)])
              : null,
          color: isSelected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected ? AppTheme.subtleShadow : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textMuted, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
            if (isSelected && label == 'Received') ...[
              const SizedBox(width: 6),
              Icon(Icons.check, color: color, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _fromPoint != null && 
                    _toPoint != null && 
                    _selectedItem != null && 
                    _quantityController.text.isNotEmpty &&
                    int.tryParse(_quantityController.text) != null &&
                    int.tryParse(_quantityController.text)! > 0;
    
    final selectedItemData = _items.firstWhere(
      (item) => item['name'] == _selectedItem,
      orElse: () => {'available': 0},
    );
    
    final hasStock = _selectedItem == null || 
                     int.tryParse(_quantityController.text) == null ||
                     int.tryParse(_quantityController.text)! <= (selectedItemData['available'] ?? 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isInitiating || !isValid || !hasStock ? null : _initiateTransfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.info,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isInitiating
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.send_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Initiate Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}