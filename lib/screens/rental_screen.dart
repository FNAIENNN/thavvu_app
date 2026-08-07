import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
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

  Future<void> _openRental() async {
    if (_itemController.text.isEmpty) {
      _showSnackbar('Please enter item name', AppTheme.danger);
      return;
    }
    if (_rateController.text.isEmpty) {
      _showSnackbar('Please enter rate', AppTheme.danger);
      return;
    }

    setState(() => _isOpening = true);
    final record = await context.read<AppStore>().openRental(
          item: _itemController.text,
          billingMode: _billingMode,
          rate: double.tryParse(_rateController.text) ?? 0,
          fuel: double.tryParse(_fuelController.text) ?? 0,
          notes: _notesController.text,
        );
    if (!mounted) return;
    setState(() => _isOpening = false);
    _showSnackbar('Rental record ${record.id} opened for ${record.item}', AppTheme.success);
    _clearOpenForm();
  }

  Future<void> _closeRental() async {
    if (_rentalIdController.text.isEmpty) {
      _showSnackbar('Please enter Rental ID', AppTheme.danger);
      return;
    }

    setState(() => _isClosing = true);
    final closed = await context.read<AppStore>().closeRental(_rentalIdController.text.trim());
    if (!mounted) return;
    setState(() => _isClosing = false);
    if (closed == null) {
      _showSnackbar('Rental ID not found', AppTheme.danger);
      return;
    }
    _showSnackbar('Rental ${closed.id} closed successfully', AppTheme.success);
    _rentalIdController.clear();
  }

  Future<void> _copyRentalId(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    _showSnackbar('Rental ID $id copied to clipboard', AppTheme.info);
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
    final store = context.watch<AppStore>();
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
          _buildOpenRentalTab(store),
          _buildCloseRentalTab(store),
        ],
      ),
    );
  }

  Widget _buildOpenRentalTab(AppStore store) {
    final nextId = 'RNT-${DateTime.now().year}-${(34 + store.rentals.length).toString().padLeft(4, '0')}';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAutoIdCard(nextId),
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

  Widget _buildCloseRentalTab(AppStore store) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildActiveRentalsList(store.activeRentals),
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
          if (store.closedRentals.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildClosedRentalsSummary(store.closedRentals),
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

  Widget _buildAutoIdCard(String previewId) {
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
                Text(previewId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.danger)),
                const SizedBox(height: 4),
                const HodApprovalBadge(),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copyRentalId(previewId),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.copy, size: 16, color: AppTheme.danger),
            ),
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

  Widget _buildActiveRentalsList(List<RentalRecord> activeRentals) {
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
          Text(
            'Active Rentals (${activeRentals.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          if (activeRentals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No active rentals right now',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            )
          else
            ...activeRentals.map((rental) => _buildActiveRentalTile(rental)),
        ],
      ),
    );
  }

  Widget _buildActiveRentalTile(RentalRecord rental) {
    return GestureDetector(
      onTap: () => setState(() => _rentalIdController.text = rental.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _rentalIdController.text == rental.id
              ? AppTheme.successBg 
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _rentalIdController.text == rental.id
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
              child: Text(rental.item.isNotEmpty ? rental.item[0] : '?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rental.item, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('${rental.id} • Started ${rental.startDate}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${rental.rate.toStringAsFixed(0)}/day', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Fuel: ₹${rental.fuel.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16, color: AppTheme.textMuted),
              onPressed: () => _copyRentalId(rental.id),
              tooltip: 'Copy rental ID',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosedRentalsSummary(List<RentalRecord> closedRentals) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Closed Rentals',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${closedRentals.length} closed',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...closedRentals.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${r.id} · ${r.item} · closed ${r.endDate ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              )),
        ],
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