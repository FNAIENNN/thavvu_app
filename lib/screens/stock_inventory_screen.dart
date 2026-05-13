import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─── Models ───────────────────────────────────────────────────────────────────
class StockPoint {
  final String id, name, location, batchId;
  final int onHand, todayUsage, reorderLevel, totalIn, totalOut;
  const StockPoint({
    required this.id, required this.name, required this.location,
    required this.batchId, required this.onHand, required this.todayUsage,
    required this.reorderLevel, required this.totalIn, required this.totalOut,
  });
  int get remaining => onHand - todayUsage;
  bool get isLow => remaining <= reorderLevel;
  double get stockPercentage => (remaining / reorderLevel) * 100;
}

class StockMovement {
  final String type, item, batch, date, by;
  final int quantity;
  const StockMovement({
    required this.type, required this.item, required this.quantity,
    required this.batch, required this.date, required this.by,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class StockInventoryScreen extends StatefulWidget {
  const StockInventoryScreen({super.key});
  @override
  State<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends State<StockInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StockPoint? _selectedPoint;
  bool _isSubmittingOrder = false;
  bool _isSubmittingReturn = false;

  static const List<StockPoint> _stockPoints = [
    StockPoint(id:'SP-001', name:'Site A — North',    location:'North Block',   batchId:'B-042', onHand:450, todayUsage:12, reorderLevel:20, totalIn:750,  totalOut:300),
    StockPoint(id:'SP-002', name:'Site B — South',    location:'South Block',   batchId:'B-039', onHand:200, todayUsage:8,  reorderLevel:30, totalIn:400,  totalOut:200),
    StockPoint(id:'SP-003', name:'Warehouse Main',    location:'Central Store', batchId:'B-031', onHand:18,  todayUsage:5,  reorderLevel:20, totalIn:600,  totalOut:582),
    StockPoint(id:'SP-004', name:'Field Store',       location:'Field Office',  batchId:'B-044', onHand:120, todayUsage:20, reorderLevel:15, totalIn:300,  totalOut:180),
  ];

  static const List<StockMovement> _movements = [
    StockMovement(type:'in',       item:'Diesel',         quantity:80,  batch:'B-042', date:'Today 9:10 AM',   by:'HOD Approved'),
    StockMovement(type:'out',      item:'Diesel',         quantity:12,  batch:'B-042', date:'Today 11:30 AM',  by:'MCH-001'),
    StockMovement(type:'in',       item:'Engine Oil',     quantity:20,  batch:'B-041', date:'Yesterday',       by:'HOD Approved'),
    StockMovement(type:'return',   item:'Bolts & Nuts',   quantity:5,   batch:'B-038', date:'12 May',          by:'RET-0089'),
    StockMovement(type:'transfer', item:'Hydraulic Fluid',quantity:10,  batch:'B-040', date:'11 May',          by:'SP-001→SP-002'),
  ];

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
      appBar: AppBar(
        title: const Text('Stock Inventory'),
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
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'View Stock', icon: Icon(Icons.visibility_outlined)),
            Tab(text: 'Raise Order', icon: Icon(Icons.add_shopping_cart)),
            Tab(text: 'Return', icon: Icon(Icons.assignment_return)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ViewStockTab(
            points: _stockPoints, 
            movements: _movements, 
            selectedPoint: _selectedPoint,
            onSelect: (point) => setState(() => _selectedPoint = point),
          ),
          const _RaiseOrderTab(),
          const _ReturnTab(),
        ],
      ),
    );
  }
}

// ─── View Stock Tab ───────────────────────────────────────────────────────────
class _ViewStockTab extends StatelessWidget {
  final List<StockPoint> points;
  final List<StockMovement> movements;
  final StockPoint? selectedPoint;
  final ValueChanged<StockPoint?> onSelect;
  
  const _ViewStockTab({
    required this.points,
    required this.movements,
    required this.selectedPoint,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildStockPointSelector(),
          const SizedBox(height: 16),
          if (selectedPoint != null) ...[
            if (selectedPoint!.isLow) _buildLowStockAlert(),
            const SizedBox(height: 16),
            _buildDashboardHeader(),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildMovementHeader(),
            const SizedBox(height: 12),
            ...movements.map((m) => _MovementTile(movement: m)),
          ] else ...[
            _buildEmptyState(),
          ],
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
              colors: [AppTheme.warning.withOpacity(0.15), AppTheme.warning.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('📦', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Stock Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Real-time stock monitoring and management', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockPointSelector() {
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
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: AppTheme.warning, size: 20),
              SizedBox(width: 10),
              Text('Select Stock Point', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          const HodApprovalBadge(text: 'Stock points created by HOD only'),
          const SizedBox(height: 12),
          DropdownButtonFormField<StockPoint>(
            value: selectedPoint,
            hint: const Text('Choose a stock point to view dashboard'),
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: points.map((point) => DropdownMenuItem(
              value: point,
              child: Row(
                children: [
                  Expanded(child: Text(point.name, style: const TextStyle(fontSize: 13))),
                  if (point.isLow) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Low Stock', style: TextStyle(fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            )).toList(),
            onChanged: onSelect,
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.dangerBg, AppTheme.dangerBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Low Stock Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                Text(
                  '⚠️ Stock at ${selectedPoint!.name} is at or below the reorder level (${selectedPoint!.reorderLevel} units). Raise an order immediately.',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.danger, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Stock Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(selectedPoint!.batchId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'Batch ID', 'value': selectedPoint!.batchId, 'icon': Icons.tag, 'color': AppTheme.info},
      {'label': 'Total In / Out', 'value': '${selectedPoint!.totalIn} / ${selectedPoint!.totalOut}', 'icon': Icons.swap_vert, 'color': AppTheme.success},
      {'label': 'On Hand', 'value': '${selectedPoint!.onHand} units', 'icon': Icons.inventory_2_outlined, 'color': AppTheme.warning},
      {'label': "Today's Usage", 'value': '${selectedPoint!.todayUsage} units', 'icon': Icons.today_outlined, 'color': AppTheme.primary},
      {'label': 'Stock Status', 'value': '${selectedPoint!.remaining} units', 'icon': Icons.donut_large_outlined, 'color': selectedPoint!.isLow ? AppTheme.danger : AppTheme.success},
      {'label': 'Reorder Level', 'value': '${selectedPoint!.reorderLevel} units', 'icon': Icons.low_priority_outlined, 'color': selectedPoint!.isLow ? AppTheme.danger : AppTheme.textSecondary},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((stat) => _StatCell(
        label: stat['label'] as String,
        value: stat['value'] as String,
        icon: stat['icon'] as IconData,
        color: stat['color'] as Color,
      )).toList(),
    );
  }

  Widget _buildMovementHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Movement Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.history, size: 16),
          label: const Text('View All'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.info),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Stock Point Selected',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a stock point above to view its live dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.06), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> styles = {
      'in': {'icon': Icons.arrow_downward, 'label': 'Received', 'gradient': [AppTheme.successBg, AppTheme.successBg]},
      'out': {'icon': Icons.arrow_upward, 'label': 'Consumed', 'gradient': [AppTheme.dangerBg, AppTheme.dangerBg]},
      'transfer': {'icon': Icons.compare_arrows, 'label': 'Transfer', 'gradient': [AppTheme.infoBg, AppTheme.infoBg]},
      'return': {'icon': Icons.loop, 'label': 'Return', 'gradient': [AppTheme.warningBg, AppTheme.warningBg]},
    };
    
    final Color color = movement.type == 'in' ? AppTheme.success : 
                        movement.type == 'out' ? AppTheme.danger : 
                        movement.type == 'transfer' ? AppTheme.info : AppTheme.warning;
    final icon = styles[movement.type]!['icon'] as IconData;
    final label = styles[movement.type]!['label'] as String;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(movement.item, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${movement.batch} · ${movement.quantity} units · ${movement.by}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              movement.date,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Raise Order Tab ──────────────────────────────────────────────────────────
class _RaiseOrderTab extends StatefulWidget {
  const _RaiseOrderTab();
  @override
  State<_RaiseOrderTab> createState() => _RaiseOrderTabState();
}

class _RaiseOrderTabState extends State<_RaiseOrderTab> {
  String? _selectedItem;
  String? _selectedStockPoint;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  bool _isSubmitting = false;
  
  final String _orderId = 'ORD-2024-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';
  
  static const List<String> _items = ['Diesel', 'Engine Oil', 'Hydraulic Fluid', 'Bolts & Nuts', 'Grease', 'Coolant', 'Air Filter'];
  static const List<Map<String, String>> _stockPoints = [
    {'id': 'SP-001', 'name': 'Site A — North'},
    {'id': 'SP-002', 'name': 'Site B — South'},
    {'id': 'SP-003', 'name': 'Warehouse Main'},
    {'id': 'SP-004', 'name': 'Field Store'},
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _submitOrder() {
    if (_selectedStockPoint == null) {
      _showSnackbar('Please select a stock point', AppTheme.danger);
      return;
    }
    if (_selectedItem == null) {
      _showSnackbar('Please select an item', AppTheme.danger);
      return;
    }
    if (_quantityController.text.isEmpty) {
      _showSnackbar('Please enter quantity', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _showSnackbar('Order submitted for HOD approval!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _selectedStockPoint = null;
    _selectedItem = null;
    _quantityController.clear();
    _purposeController.clear();
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
          _buildAutoIdBanner(),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1',
            title: 'Destination Stock Point',
            color: AppTheme.warning,
            child: _buildStockPointSelector(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Item, Quantity & Purpose',
            color: AppTheme.warning,
            child: _buildOrderDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Submit for HOD Approval',
            color: AppTheme.warning,
            child: _buildSubmissionInfo(),
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add_shopping_cart, color: AppTheme.warning, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Raise New Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Request stock from HOD', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoIdBanner() {
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
            child: const Icon(Icons.receipt_long_outlined, color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Auto-generated Order ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warning)),
              Text(_orderId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.warning)),
            ],
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStockPointSelector() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedStockPoint,
          hint: const Text('Select stock point'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.warehouse_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _stockPoints.map((point) => DropdownMenuItem(
            value: point['id'],
            child: Text(point['name']!, style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (value) => setState(() => _selectedStockPoint = value),
        ),
        const SizedBox(height: 8),
        const HodApprovalBadge(),
      ],
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedItem,
          hint: const Text('Select item to order'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.category_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (value) => setState(() => _selectedItem = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity Required',
            prefixIcon: Icon(Icons.numbers, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _purposeController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Purpose / Reason',
            hintText: 'Describe why this order is needed...',
            prefixIcon: Icon(Icons.notes_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        _buildVoiceNoteButton(),
      ],
    );
  }

  Widget _buildVoiceNoteButton() {
    return GestureDetector(
      onTap: () => _showSnackbar('Voice recording started', AppTheme.info),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.mic_outlined, color: AppTheme.info, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice Note (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                  Text('Tap to record a voice message', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionInfo() {
    return Column(
      children: [
        const HodApprovalBadge(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.pending_actions_outlined, color: AppTheme.warning, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Order will appear in pending list after submission. HOD reviews before stock levels are updated.',
                  style: TextStyle(fontSize: 12, color: AppTheme.warning, height: 1.4),
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
        onPressed: _isSubmitting ? null : _submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Submit Order for Approval', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

// ─── Return Tab ───────────────────────────────────────────────────────────────
class _ReturnTab extends StatefulWidget {
  const _ReturnTab();
  @override
  State<_ReturnTab> createState() => _ReturnTabState();
}

class _ReturnTabState extends State<_ReturnTab> {
  String? _selectedItem;
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;
  
  final String _returnId = 'RET-2024-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';
  
  static const List<String> _items = ['Engine Oil', 'Bolts & Nuts', 'Hydraulic Fluid', 'Grease', 'Coolant'];

  @override
  void dispose() {
    _batchController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submitReturn() {
    if (_batchController.text.isEmpty) {
      _showSnackbar('Please enter original batch ID', AppTheme.danger);
      return;
    }
    if (_selectedItem == null) {
      _showSnackbar('Please select an item', AppTheme.danger);
      return;
    }
    if (_quantityController.text.isEmpty) {
      _showSnackbar('Please enter quantity', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isSubmitting = false);
      _showSnackbar('Return submitted for HOD approval!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _batchController.clear();
    _selectedItem = null;
    _quantityController.clear();
    _reasonController.clear();
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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
          _buildAutoIdBanner(),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1',
            title: 'Link to Original Batch',
            color: AppTheme.success,
            child: _buildBatchField(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Return Details',
            color: AppTheme.success,
            child: _buildReturnDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Submit for HOD Approval',
            color: AppTheme.success,
            child: _buildSubmissionInfo(),
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
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.assignment_return, color: AppTheme.success, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Return Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('Request stock return approval', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoIdBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.successBg, AppTheme.successBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.success.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.loop_outlined, color: AppTheme.success, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Auto-generated Return ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success)),
              Text(_returnId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.success)),
            ],
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(step, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBatchField() {
    return TextField(
      controller: _batchController,
      decoration: InputDecoration(
        labelText: 'Original Batch ID',
        hintText: 'e.g., B-042',
        prefixIcon: Icon(Icons.link_outlined, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildReturnDetails() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedItem,
          hint: const Text('Select item to return'),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.category_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (value) => setState(() => _selectedItem = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity to Return',
            prefixIcon: Icon(Icons.numbers, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Return Reason',
            hintText: 'Explain why stock is being returned...',
            prefixIcon: Icon(Icons.notes_outlined, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionInfo() {
    return Column(
      children: [
        const HodApprovalBadge(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.info.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.info, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once approved, returned quantity will be added back to the original batch stock count.',
                  style: TextStyle(fontSize: 12, color: AppTheme.info, height: 1.4),
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
        onPressed: _isSubmitting ? null : _submitReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_return, size: 20),
                  SizedBox(width: 10),
                  Text('Submit Return for Approval', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}