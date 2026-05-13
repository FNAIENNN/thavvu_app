import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class TransferRecord {
  final String id, item, fromPoint, toPoint, status, date;
  final int quantity;
  
  const TransferRecord({
    required this.id,
    required this.item,
    required this.fromPoint,
    required this.toPoint,
    required this.quantity,
    required this.status,
    required this.date,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class InternalTransferScreen extends StatefulWidget {
  const InternalTransferScreen({super.key});
  
  @override
  State<InternalTransferScreen> createState() => _InternalTransferScreenState();
}

class _InternalTransferScreenState extends State<InternalTransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'New Transfer', icon: Icon(Icons.send_outlined)),
            Tab(text: 'Transfer History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          NewTransferTab(),
          TransferHistoryTab(),
        ],
      ),
    );
  }
}

// ─── New Transfer Tab ─────────────────────────────────────────────────────────
class NewTransferTab extends StatefulWidget {
  const NewTransferTab({super.key});

  @override
  State<NewTransferTab> createState() => _NewTransferTabState();
}

class _NewTransferTabState extends State<NewTransferTab> {
  String? _fromPoint;
  String? _toPoint;
  String? _selectedItem;
  String _receiverStatus = '';
  bool _initiated = false;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _stockPoints = [
    'Site A — North',
    'Site B — South',
    'Warehouse Main',
    'Field Store',
  ];

  final List<Map<String, dynamic>> _items = [
    {'name': 'Diesel', 'icon': Icons.local_gas_station, 'unit': 'Liters'},
    {'name': 'Engine Oil', 'icon': Icons.oil_barrel, 'unit': 'Quarts'},
    {'name': 'Hydraulic Fluid', 'icon': Icons.water_drop, 'unit': 'Gallons'},
    {'name': 'Bolts & Nuts', 'icon': Icons.build, 'unit': 'Pieces'},
    {'name': 'Grease', 'icon': Icons.cleaning_services, 'unit': 'Tubes'},
    {'name': 'Coolant', 'icon': Icons.ac_unit, 'unit': 'Liters'},
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleInitiate() {
    if (_fromPoint == null || _toPoint == null || _selectedItem == null || _quantityController.text.isEmpty) {
      _showSnackbar('Please fill all required fields', AppTheme.danger);
      return;
    }
    if (_fromPoint == _toPoint) {
      _showSnackbar('Source and destination cannot be the same', AppTheme.danger);
      return;
    }
    if (int.tryParse(_quantityController.text) == null) {
      _showSnackbar('Please enter a valid quantity', AppTheme.warning);
      return;
    }

    setState(() => _initiated = true);
    _showSnackbar(
      'Transfer initiated from $_fromPoint to $_toPoint. Stock deducted from source.',
      AppTheme.success,
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildStepCard(
            step: '1',
            title: 'Source & Destination',
            color: AppTheme.danger,
            child: _buildSourceDestination(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Item & Quantity',
            color: AppTheme.warning,
            child: _buildItemQuantity(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Notes & Initiate',
            color: AppTheme.info,
            child: _buildNotesAndInitiate(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '4',
            title: 'Receiver Acknowledgment',
            color: AppTheme.success,
            child: _buildAcknowledgement(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
        ],
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
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Move stock between stock points with confirmation',
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
                  'Two-Way Handshake Process',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
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
    required String step,
    required String title,
    required Color color,
    required Widget child,
  }) {
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
            items: _stockPoints.map((p) => DropdownMenuItem<String>(
              value: p,
              child: Text(p, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _fromPoint = v),
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
            items: _stockPoints.map((p) => DropdownMenuItem<String>(
              value: p,
              child: Text(p, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (v) => setState(() => _toPoint = v),
          ),
        ),
      ],
    );
  }

  Widget _buildItemQuantity() {
    final selectedItemData = _items.firstWhere(
      (item) => item['name'] == _selectedItem,
      orElse: () => {'name': '', 'icon': Icons.help, 'unit': ''},
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
              return DropdownMenuItem<String>(
                value: item['name'] as String,
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData, size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Text(item['name'] as String, style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      item['unit'] as String,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedItem = v),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity to transfer',
            hintText: 'Enter quantity',
            prefixIcon: const Icon(Icons.numbers, size: 18),
            suffixText: selectedItemData['unit'] != '' ? selectedItemData['unit'] : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesAndInitiate() {
    return Column(
      children: [
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
        const SizedBox(height: 14),
        Container(
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
                  'Stock is immediately deducted from the source point when transfer is initiated.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
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
                child: const Text(
                  'Pending',
                  style: TextStyle(fontSize: 10, color: AppTheme.info),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAcknowledgeButton(
                label: 'Received',
                icon: Icons.check_circle_outline,
                color: AppTheme.success,
                isSelected: _receiverStatus == 'received',
                onTap: () => setState(() => _receiverStatus = 'received'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAcknowledgeButton(
                label: 'Pending',
                icon: Icons.hourglass_empty_outlined,
                color: AppTheme.warning,
                isSelected: _receiverStatus == 'pending',
                onTap: () => setState(() => _receiverStatus = 'pending'),
              ),
            ),
          ],
        ),
        if (_receiverStatus == 'received') ...[
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
                    'Stock has been updated at the destination point.',
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

  Widget _buildAcknowledgeButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
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
            if (isSelected && label == 'Received')
              const SizedBox(width: 6),
            if (isSelected && label == 'Received')
              Icon(Icons.check, color: color, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _initiated ? null : _handleInitiate,
        style: ElevatedButton.styleFrom(
          backgroundColor: _initiated ? AppTheme.success : AppTheme.info,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_initiated ? Icons.check_circle : Icons.send_outlined, size: 20),
            const SizedBox(width: 10),
            Text(
              _initiated ? 'Transfer Initiated ✓' : 'Initiate Transfer',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transfer History Tab ─────────────────────────────────────────────────────
class TransferHistoryTab extends StatelessWidget {
  const TransferHistoryTab({super.key});

  static const List<TransferRecord> _history = [
    TransferRecord(
      id: 'TRF-0041',
      item: 'Diesel',
      fromPoint: 'Site A — North',
      toPoint: 'Site B — South',
      quantity: 50,
      status: 'completed',
      date: '13 May, 9:00 AM',
    ),
    TransferRecord(
      id: 'TRF-0040',
      item: 'Engine Oil',
      fromPoint: 'Warehouse Main',
      toPoint: 'Field Store',
      quantity: 10,
      status: 'pending',
      date: '13 May, 8:30 AM',
    ),
    TransferRecord(
      id: 'TRF-0039',
      item: 'Hydraulic Fluid',
      fromPoint: 'Site B — South',
      toPoint: 'Site A — North',
      quantity: 5,
      status: 'completed',
      date: '12 May, 4:00 PM',
    ),
    TransferRecord(
      id: 'TRF-0038',
      item: 'Bolts & Nuts',
      fromPoint: 'Warehouse Main',
      toPoint: 'Site A — North',
      quantity: 100,
      status: 'rejected',
      date: '12 May, 11:00 AM',
    ),
    TransferRecord(
      id: 'TRF-0037',
      item: 'Grease',
      fromPoint: 'Field Store',
      toPoint: 'Warehouse Main',
      quantity: 8,
      status: 'completed',
      date: '11 May, 2:00 PM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          ..._history.map((record) => _buildHistoryTile(record)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final completedCount = _history.where((r) => r.status == 'completed').length;
    final pendingCount = _history.where((r) => r.status == 'pending').length;

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Recent Transfers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.successBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Completed: $completedCount',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.warningBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Pending: $pendingCount',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warning),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(TransferRecord record) {
    final Color statusColor = record.status == 'completed'
        ? AppTheme.success
        : record.status == 'pending'
            ? AppTheme.warning
            : AppTheme.danger;
    final Color statusBg = record.status == 'completed'
        ? AppTheme.successBg
        : record.status == 'pending'
            ? AppTheme.warningBg
            : AppTheme.dangerBg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.infoBg, AppTheme.info.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.compare_arrows, color: AppTheme.info, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.quantity} units • ${record.id}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      record.status == 'completed'
                          ? Icons.check_circle
                          : record.status == 'pending'
                              ? Icons.hourglass_empty
                              : Icons.cancel,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.status[0].toUpperCase() + record.status.substring(1),
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.arrow_upward, size: 12, color: AppTheme.danger),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  record.fromPoint,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 12, color: AppTheme.textMuted),
              ),
              const Icon(Icons.arrow_downward, size: 12, color: AppTheme.success),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  record.toPoint,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  record.date,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
