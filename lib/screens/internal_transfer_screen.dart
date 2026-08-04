import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class TransferRecord {
  final String id;
  final String internalNumber;
  final String itemName;
  final int quantity;
  final String quality;
  final String fromPoint;
  final String toPoint;
  final String status;
  final String date;
  final String? photoPath;
  final String? deliveredBy;
  final String? receivedBy;

  const TransferRecord({
    required this.id,
    required this.internalNumber,
    required this.itemName,
    required this.quantity,
    required this.quality,
    required this.fromPoint,
    required this.toPoint,
    required this.status,
    required this.date,
    this.photoPath,
    this.deliveredBy,
    this.receivedBy,
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
    _tabController = TabController(length: 3, vsync: this);
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Internal Transfers',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'New Transfer'),
              Tab(text: 'Delivering'),
              Tab(text: 'Receiving'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            NewTransferTab(),
            const DeliveringTab(),
            const ReceivingTab(),
          ],
        ),
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
  String? _selectedQuality;
  bool _initiated = false;
  String? _photoPath;

  final TextEditingController _transferIdController = TextEditingController();
  final TextEditingController _internalNumberController =
      TextEditingController();
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

  final List<String> _qualityOptions = [
    'Premium',
    'Standard',
    'Economy',
    'Certified',
    'Refurbished',
  ];

  @override
  void initState() {
    super.initState();
    _transferIdController.text =
        'TRF-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}';
    _internalNumberController.text =
        'INT-${DateTime.now().millisecondsSinceEpoch % 90000 + 10000}';
  }

  @override
  void dispose() {
    _transferIdController.dispose();
    _internalNumberController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleInitiate() {
    if (_fromPoint == null ||
        _toPoint == null ||
        _selectedItem == null ||
        _selectedQuality == null ||
        _quantityController.text.isEmpty) {
      _showSnackbar('Please fill all required fields', AppTheme.danger);
      return;
    }
    if (_fromPoint == _toPoint) {
      _showSnackbar(
          'Source and destination cannot be the same', AppTheme.danger);
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
    final selectedItemData = _items.firstWhere(
      (item) => item['name'] == _selectedItem,
      orElse: () => {'name': '', 'icon': Icons.help, 'unit': ''},
    );

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
            title: 'Transfer Identification',
            color: AppTheme.primary,
            child: _buildIdentificationFields(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Source & Destination',
            color: AppTheme.danger,
            child: _buildSourceDestination(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Item Details',
            color: AppTheme.warning,
            child: _buildItemDetails(selectedItemData),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '4',
            title: 'Photo Upload (Optional)',
            color: AppTheme.info,
            child: _buildPhotoUpload(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '5',
            title: 'Notes & Initiate',
            color: AppTheme.success,
            child: _buildNotesAndInitiate(),
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
              colors: [
                AppTheme.info.withValues(alpha: 0.15),
                AppTheme.info.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
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
                'Move stock between stock points with delivery confirmation',
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
          colors: [AppTheme.info.withValues(alpha: 0.1), AppTheme.infoBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.info_outline, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering & Receiving Process',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Create transfer with ID, internal number, item details. Use Delivering/Receiving tabs to track status.',
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
                    colors: [color, color.withValues(alpha: 0.8)],
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

  Widget _buildIdentificationFields() {
    return Column(
      children: [
        TextField(
          controller: _transferIdController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Transfer ID (Auto-generated)',
            prefixIcon: const Icon(Icons.tag, size: 20),
            suffixIcon: const Icon(Icons.auto_fix_high, color: AppTheme.info),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _internalNumberController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Internal Number (Auto-generated)',
            prefixIcon: const Icon(Icons.numbers, size: 20),
            suffixIcon: const Icon(Icons.auto_fix_high, color: AppTheme.info),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transfer ID and Internal Number are auto-generated for tracking',
                  style: TextStyle(fontSize: 11, color: AppTheme.info),
                ),
              ),
            ],
          ),
        ),
      ],
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
            initialValue: _fromPoint,
            hint: const Text('From — source stock point'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.arrow_circle_up_outlined,
                  size: 18, color: AppTheme.danger),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _stockPoints
                .map((p) => DropdownMenuItem<String>(
                      value: p,
                      child: Text(p, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
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
            border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.keyboard_double_arrow_down,
              color: AppTheme.info, size: 22),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _toPoint,
            hint: const Text('To — destination stock point'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.arrow_circle_down_outlined,
                  size: 18, color: AppTheme.success),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _stockPoints
                .map((p) => DropdownMenuItem<String>(
                      value: p,
                      child: Text(p, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _toPoint = v),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDetails(Map<String, dynamic> selectedItemData) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedItem,
            hint: const Text('Select item to transfer'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _items.map((item) {
              return DropdownMenuItem<String>(
                value: item['name'] as String,
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData,
                        size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Text(item['name'] as String,
                        style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Text(
                      item['unit'] as String,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
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
            suffixText: selectedItemData['unit'] != ''
                ? selectedItemData['unit']
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedQuality,
            hint: const Text('Select quality grade'),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.verified, size: 18),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _qualityOptions.map((quality) {
              return DropdownMenuItem<String>(
                value: quality,
                child: Row(
                  children: [
                    Icon(
                      quality == 'Premium' || quality == 'Certified'
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: quality == 'Premium' || quality == 'Certified'
                          ? AppTheme.warning
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(quality, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedQuality = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoUpload() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _photoPath = _photoPath == null ? 'captured_photo.jpg' : null;
            });
            _showSnackbar(
              _photoPath != null
                  ? 'Photo captured successfully'
                  : 'Photo removed',
              _photoPath != null ? AppTheme.success : AppTheme.info,
            );
          },
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _photoPath != null ? AppTheme.success : AppTheme.border,
                width: _photoPath != null ? 2 : 1,
                style:
                    _photoPath != null ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            child: _photoPath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: AppTheme.success, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Photo Captured',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to remove or retake',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: AppTheme.subtleShadow,
                          ),
                          child: const Icon(Icons.refresh,
                              size: 16, color: AppTheme.info),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.info.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 32, color: AppTheme.info),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload Item Photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Optional - Tap to capture',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_photoPath != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                SizedBox(width: 6),
                Text(
                  'Photo attached to transfer record',
                  style: TextStyle(fontSize: 11, color: AppTheme.success),
                ),
              ],
            ),
          ),
        ],
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.warningBg, AppTheme.warningBg],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_outlined,
                    color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Stock is immediately deducted from the source point when transfer is initiated. Use Delivering/Receiving tabs to track.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.warning, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
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
            Icon(_initiated ? Icons.check_circle : Icons.send_outlined,
                size: 20),
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

// ─── Delivering Tab ───────────────────────────────────────────────────────────
class DeliveringTab extends StatefulWidget {
  const DeliveringTab({super.key});

  @override
  State<DeliveringTab> createState() => _DeliveringTabState();
}

class _DeliveringTabState extends State<DeliveringTab> {
  String? _selectedTransfer;
  String _deliveryStatus = '';

  final List<Map<String, dynamic>> _pendingDeliveries = [
    {
      'id': 'TRF-0041',
      'internalNumber': 'INT-10041',
      'item': 'Diesel',
      'quantity': 50,
      'quality': 'Premium',
      'from': 'Site A — North',
      'to': 'Site B — South',
      'date': '13 May, 9:00 AM',
    },
    {
      'id': 'TRF-0042',
      'internalNumber': 'INT-10042',
      'item': 'Engine Oil',
      'quantity': 10,
      'quality': 'Standard',
      'from': 'Warehouse Main',
      'to': 'Field Store',
      'date': '14 May, 10:30 AM',
    },
    {
      'id': 'TRF-0043',
      'internalNumber': 'INT-10043',
      'item': 'Hydraulic Fluid',
      'quantity': 25,
      'quality': 'Certified',
      'from': 'Warehouse Main',
      'to': 'Site A — North',
      'date': '14 May, 2:00 PM',
    },
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
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildPendingDeliveriesList(),
          const SizedBox(height: 20),
          if (_selectedTransfer != null) ...[
            _buildDeliveryConfirmationCard(),
            const SizedBox(height: 20),
          ],
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
              colors: [
                AppTheme.warning.withValues(alpha: 0.15),
                AppTheme.warning.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('📦', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivering Stock',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Confirm deliveries from source stock points',
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
          colors: [AppTheme.warning.withValues(alpha: 0.1), AppTheme.warningBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_shipping,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Confirmation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Select a transfer and confirm delivery status. Updates stock records.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDeliveriesList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Deliveries',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          ..._pendingDeliveries.map((delivery) => _buildDeliveryTile(delivery)),
        ],
      ),
    );
  }

  Widget _buildDeliveryTile(Map<String, dynamic> delivery) {
    final isSelected = _selectedTransfer == delivery['id'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTransfer = isSelected ? null : delivery['id'];
        _deliveryStatus = '';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.warningBg : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.warning : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.local_shipping,
                      color: AppTheme.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery['item'],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${delivery['id']} • ${delivery['internalNumber']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDetailChip(
                    Icons.inventory_2, '${delivery['quantity']} units'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.verified, delivery['quality']),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.calendar_today, delivery['date']),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.arrow_upward,
                    size: 12, color: AppTheme.danger),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    delivery['from'],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
                const Icon(Icons.arrow_forward,
                    size: 12, color: AppTheme.textMuted),
                const Icon(Icons.arrow_downward,
                    size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    delivery['to'],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDeliveryConfirmationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Delivery Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  label: 'In Transit',
                  icon: Icons.local_shipping,
                  color: AppTheme.info,
                  isSelected: _deliveryStatus == 'In Transit',
                  onTap: () => setState(() => _deliveryStatus = 'In Transit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusButton(
                  label: 'Delivered',
                  icon: Icons.check_circle,
                  color: AppTheme.success,
                  isSelected: _deliveryStatus == 'Delivered',
                  onTap: () => setState(() => _deliveryStatus = 'Delivered'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  label: 'Delayed',
                  icon: Icons.warning,
                  color: AppTheme.warning,
                  isSelected: _deliveryStatus == 'Delayed',
                  onTap: () => setState(() => _deliveryStatus = 'Delayed'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusButton(
                  label: 'Cancelled',
                  icon: Icons.cancel,
                  color: AppTheme.danger,
                  isSelected: _deliveryStatus == 'Cancelled',
                  onTap: () => setState(() => _deliveryStatus = 'Cancelled'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
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
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? color : AppTheme.textMuted, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
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
        onPressed: _selectedTransfer != null && _deliveryStatus.isNotEmpty
            ? () {
                _showSnackbar(
                  'Delivery status updated to: $_deliveryStatus',
                  AppTheme.success,
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping, size: 20),
            SizedBox(width: 10),
            Text(
              'Update Delivery Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
}

// ─── Receiving Tab ────────────────────────────────────────────────────────────
class ReceivingTab extends StatefulWidget {
  const ReceivingTab({super.key});

  @override
  State<ReceivingTab> createState() => _ReceivingTabState();
}

class _ReceivingTabState extends State<ReceivingTab> {
  String? _selectedTransfer;
  String _receiveStatus = '';
  String? _receiverName;

  final List<Map<String, dynamic>> _pendingReceiving = [
    {
      'id': 'TRF-0041',
      'internalNumber': 'INT-10041',
      'item': 'Diesel',
      'quantity': 50,
      'quality': 'Premium',
      'from': 'Site A — North',
      'to': 'Site B — South',
      'date': '13 May, 9:00 AM',
    },
    {
      'id': 'TRF-0044',
      'internalNumber': 'INT-10044',
      'item': 'Bolts & Nuts',
      'quantity': 100,
      'quality': 'Standard',
      'from': 'Warehouse Main',
      'to': 'Field Store',
      'date': '15 May, 11:00 AM',
    },
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
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildPendingReceivingList(),
          const SizedBox(height: 20),
          if (_selectedTransfer != null) ...[
            _buildReceiveConfirmationCard(),
            const SizedBox(height: 20),
          ],
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
              colors: [
                AppTheme.success.withValues(alpha: 0.15),
                AppTheme.success.withValues(alpha: 0.05)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('📥', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receiving Stock',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Confirm receipt at destination stock points',
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
          colors: [AppTheme.success.withValues(alpha: 0.1), AppTheme.successBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child:
                const Icon(Icons.inventory, color: AppTheme.success, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receiving Confirmation',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Confirm received items and update stock at destination.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReceivingList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Receipts',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          ..._pendingReceiving.map((receipt) => _buildReceivingTile(receipt)),
        ],
      ),
    );
  }

  Widget _buildReceivingTile(Map<String, dynamic> receipt) {
    final isSelected = _selectedTransfer == receipt['id'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTransfer = isSelected ? null : receipt['id'];
        _receiveStatus = '';
        _receiverName = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.successBg : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.success : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.inventory,
                      color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt['item'],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${receipt['id']} • ${receipt['internalNumber']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Awaiting',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDetailChip(
                    Icons.inventory_2, '${receipt['quantity']} units'),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.verified, receipt['quality']),
                const SizedBox(width: 8),
                _buildDetailChip(Icons.calendar_today, receipt['date']),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.arrow_upward,
                    size: 12, color: AppTheme.danger),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    receipt['from'],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
                const Icon(Icons.arrow_forward,
                    size: 12, color: AppTheme.textMuted),
                const Icon(Icons.arrow_downward,
                    size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    receipt['to'],
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildReceiveConfirmationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Receipt',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Receiver Name',
              hintText: 'Enter name of person receiving',
              prefixIcon: const Icon(Icons.person, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => _receiverName = value,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  label: 'Received',
                  icon: Icons.check_circle,
                  color: AppTheme.success,
                  isSelected: _receiveStatus == 'Received',
                  onTap: () => setState(() => _receiveStatus = 'Received'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusButton(
                  label: 'Partial',
                  icon: Icons.hourglass_empty,
                  color: AppTheme.warning,
                  isSelected: _receiveStatus == 'Partial',
                  onTap: () => setState(() => _receiveStatus = 'Partial'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusButton(
                  label: 'Damaged',
                  icon: Icons.broken_image,
                  color: AppTheme.danger,
                  isSelected: _receiveStatus == 'Damaged',
                  onTap: () => setState(() => _receiveStatus = 'Damaged'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatusButton(
                  label: 'Rejected',
                  icon: Icons.cancel,
                  color: Colors.red,
                  isSelected: _receiveStatus == 'Rejected',
                  onTap: () => setState(() => _receiveStatus = 'Rejected'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
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
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? color : AppTheme.textMuted, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.textSecondary,
              ),
            ),
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
        onPressed: _selectedTransfer != null &&
                _receiveStatus.isNotEmpty &&
                _receiverName != null &&
                _receiverName!.isNotEmpty
            ? () {
                _showSnackbar(
                  'Receipt confirmed by $_receiverName',
                  AppTheme.success,
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 20),
            SizedBox(width: 10),
            Text(
              'Confirm Receipt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
}
