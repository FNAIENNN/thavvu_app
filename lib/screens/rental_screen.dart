import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class RentalScreen extends StatefulWidget {
  const RentalScreen({super.key});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _billingMode = 'Per day';
  bool _isOpening = false;
  bool _isClosing = false;
  
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _fuelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _rentalIdController = TextEditingController();

  // Mock data for active rentals
  final List<Map<String, dynamic>> _activeRentals = [
    {'id': 'RNT-2024-0034', 'item': 'Excavator', 'startDate': '2024-05-01', 'rate': 5000, 'fuel': 1200},
    {'id': 'RNT-2024-0035', 'item': 'Compressor', 'startDate': '2024-05-05', 'rate': 3000, 'fuel': 800},
    {'id': 'RNT-2024-0036', 'item': 'Generator', 'startDate': '2024-05-10', 'rate': 4000, 'fuel': 1500},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemController.dispose();
    _rateController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    _rentalIdController.dispose();
    super.dispose();
  }

  void _openRental() {
    if (_itemController.text.isEmpty) {
      _showSnackbar('Please enter item name', AppTheme.danger);
      return;
    }
    if (_rateController.text.isEmpty) {
      _showSnackbar('Please enter rate', AppTheme.danger);
      return;
    }

    setState(() => _isOpening = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isOpening = false);
      _showSnackbar('Rental record opened for ${_itemController.text}', AppTheme.success);
      _clearOpenForm();
    });
  }

  void _closeRental() {
    if (_rentalIdController.text.isEmpty) {
      _showSnackbar('Please enter Rental ID', AppTheme.danger);
      return;
    }

    setState(() => _isClosing = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isClosing = false);
      _showSnackbar('Rental record closed successfully', AppTheme.success);
      _rentalIdController.clear();
    });
  }

  void _clearOpenForm() {
    _itemController.clear();
    _rateController.clear();
    _fuelController.clear();
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

  double _calculateEarnedAmount() {
    if (_rateController.text.isEmpty) return 0;
    double rate = double.tryParse(_rateController.text) ?? 0;
    if (_billingMode == 'Per day') {
      return rate;
    } else {
      // Assume 8 hours per day for hourly billing
      return rate * 8;
    }
  }

  double _calculateUsedAmount() {
    return double.tryParse(_fuelController.text) ?? 0;
  }

  double _calculateRemainingAmount() {
    return _calculateEarnedAmount() - _calculateUsedAmount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Rental Management'),
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
          tabs: const [
            Tab(text: 'Open Rental', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'Close Rental', icon: Icon(Icons.check_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOpenRentalTab(),
          _buildCloseRentalTab(),
        ],
      ),
    );
  }

  Widget _buildOpenRentalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAutoIdCard(),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 1,
            title: 'Item & Check-in Details',
            color: AppTheme.danger,
            child: _buildItemDetails(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 2,
            title: 'Rate & Billing Configuration',
            color: AppTheme.warning,
            child: _buildRateAndBilling(),
          ),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 3,
            title: 'Fuel & Additional Notes',
            color: AppTheme.info,
            child: _buildFuelAndNotes(),
          ),
          const SizedBox(height: 20),
          _buildFinancialPreview(),
          const SizedBox(height: 20),
          _buildSubmitButton('Open Rental Record', AppTheme.danger, _openRental, _isOpening, Icons.add),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCloseRentalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildActiveRentalsList(),
          const SizedBox(height: 16),
          _buildRentalCard(
            step: 1,
            title: 'Close Rental Record',
            color: AppTheme.success,
            child: _buildCloseRentalForm(),
          ),
          const SizedBox(height: 20),
          _buildSummaryGrid(),
          const SizedBox(height: 20),
          _buildSubmitButton('Close Rental Record', AppTheme.success, _closeRental, _isClosing, Icons.check),
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
              colors: [AppTheme.danger.withOpacity(0.15), AppTheme.danger.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('🔑', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rental Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Track rented equipment from check-in to check-out', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoIdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.dangerBg, AppTheme.dangerBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.auto_fix_high, color: AppTheme.danger, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auto-generated Rental ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                const Text('RNT-2024-0034', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.danger)),
                const SizedBox(height: 4),
                const HodApprovalBadge(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.copy, size: 16, color: AppTheme.danger),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalCard({
    required int step,
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

  Widget _buildItemDetails() {
    return Column(
      children: [
        TextField(
          controller: _itemController,
          decoration: InputDecoration(
            labelText: 'Item Name',
            hintText: 'Enter rented equipment name',
            prefixIcon: const Icon(Icons.build_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: _getCurrentDate()),
          decoration: InputDecoration(
            labelText: 'Check-in Date',
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            suffixIcon: const Icon(Icons.arrow_drop_down, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildRateAndBilling() {
    return Column(
      children: [
        const Text('Billing Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: ['Per day', 'Per hour'].map((mode) {
            final isSelected = _billingMode == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _billingMode = mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [AppTheme.danger, AppTheme.danger.withOpacity(0.8)])
                        : null,
                    color: isSelected ? null : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.danger : AppTheme.border,
                      width: isSelected ? 0 : 0.8,
                    ),
                  ),
                  child: Text(
                    mode,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _rateController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Rate per ${_billingMode == 'Per day' ? 'day' : 'hour'} (₹)',
            prefixIcon: const Icon(Icons.currency_rupee, size: 20),
            suffixText: _billingMode == 'Per day' ? '/day' : '/hour',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFuelAndNotes() {
    return Column(
      children: [
        TextField(
          controller: _fuelController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Fuel Consumed (₹)',
            hintText: 'Diesel/petrol as running total',
            prefixIcon: const Icon(Icons.local_gas_station_outlined, size: 20),
            suffixText: '₹',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Additional Notes',
            hintText: 'Conditions, remarks, observations...',
            prefixIcon: const Icon(Icons.notes_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialPreview() {
    final earned = _calculateEarnedAmount();
    final used = _calculateUsedAmount();
    final remaining = _calculateRemainingAmount();

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
            'Financial Preview',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPreviewItem('Earned', '₹${earned.toStringAsFixed(0)}', Icons.trending_up, Colors.green),
              const SizedBox(width: 8),
              _buildPreviewItem('Used', '₹${used.toStringAsFixed(0)}', Icons.shopping_cart, Colors.orange),
              const SizedBox(width: 8),
              _buildPreviewItem('Balance', '₹${remaining.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRentalsList() {
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
            'Active Rentals',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          ..._activeRentals.map((rental) => _buildActiveRentalTile(rental)),
        ],
      ),
    );
  }

  Widget _buildActiveRentalTile(Map<String, dynamic> rental) {
    return GestureDetector(
      onTap: () => _rentalIdController.text = rental['id'],
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _rentalIdController.text == rental['id'] 
              ? AppTheme.successBg 
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _rentalIdController.text == rental['id'] 
                ? AppTheme.success 
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(rental['item'][0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rental['item'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${rental['id']} • Started ${rental['startDate']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${rental['rate']}/day', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Fuel: ₹${rental['fuel']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseRentalForm() {
    return Column(
      children: [
        TextField(
          controller: _rentalIdController,
          decoration: InputDecoration(
            labelText: 'Rental ID',
            hintText: 'Enter or scan rental ID',
            prefixIcon: const Icon(Icons.tag, size: 20),
            suffixIcon: const Icon(Icons.qr_code_scanner, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          readOnly: true,
          controller: TextEditingController(text: _getCurrentDate()),
          decoration: InputDecoration(
            labelText: 'Closing Date',
            prefixIcon: const Icon(Icons.event_available_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppTheme.surface,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.infoBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.info.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.calculate_outlined, color: AppTheme.info, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total amount will be auto-calculated based on rate × duration. Late fees may apply if applicable.',
                  style: TextStyle(fontSize: 12, color: AppTheme.info, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryGrid() {
    final items = [
      {'title': 'Rental ID & Item', 'value': 'Identification', 'icon': Icons.tag},
      {'title': 'Period', 'value': 'Start → End', 'icon': Icons.date_range},
      {'title': 'Earned', 'value': 'Total Billed', 'icon': Icons.trending_up},
      {'title': 'Expenses', 'value': 'Paid Out', 'icon': Icons.shopping_cart},
      {'title': 'Balance', 'value': 'To Collect', 'icon': Icons.account_balance_wallet},
      {'title': 'Accounts', 'value': 'HOD Managed', 'icon': Icons.security},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.surface, AppTheme.surfaceCard],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(items[index]['icon'] as IconData, size: 22, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text(
                items[index]['value'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                items[index]['title'] as String,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(String label, Color color, VoidCallback onPressed, bool isLoading, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}