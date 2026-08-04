import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class PetrolEntry {
  final String id;
  final String bikeId;
  final String date;
  final double quantity;
  final double amount;
  final String paymentMode;
  final String notes;

  const PetrolEntry({
    required this.id,
    required this.bikeId,
    required this.date,
    required this.quantity,
    required this.amount,
    required this.paymentMode,
    this.notes = '',
  });
}

class SnackEntry {
  final String id;
  final String broughtBy;
  final String forWhom;
  final String items;
  final double cost;
  final String paymentMode;
  final String date;

  const SnackEntry({
    required this.id,
    required this.broughtBy,
    required this.forWhom,
    required this.items,
    required this.cost,
    required this.paymentMode,
    required this.date,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class OthersScreen extends StatefulWidget {
  const OthersScreen({super.key});

  @override
  State<OthersScreen> createState() => _OthersScreenState();
}

class _OthersScreenState extends State<OthersScreen>
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Others',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Bike Petrol'),
              Tab(text: 'Snacks/Extras'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            BikePetrolTab(),
            SnacksExtrasTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Bike Petrol Tab ─────────────────────────────────────────────────────────
class BikePetrolTab extends StatefulWidget {
  const BikePetrolTab({super.key});

  @override
  State<BikePetrolTab> createState() => _BikePetrolTabState();
}

class _BikePetrolTabState extends State<BikePetrolTab> {
  String? _selectedBike;
  String _paymentMode = 'Cash';
  bool _isSubmitting = false;

  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _bikes = [
    'Bike-001 (Hero Splendor)',
    'Bike-002 (Honda Shine)',
    'Bike-003 (Bajaj Pulsar)',
    'Bike-004 (TVS Apache)',
    'Bike-005 (Royal Enfield)',
  ];

  final List<PetrolEntry> _petrolEntries = [
    const PetrolEntry(
      id: 'PTL-001',
      bikeId: 'Bike-001 (Hero Splendor)',
      date: '15 May, 10:30 AM',
      quantity: 5.5,
      amount: 550,
      paymentMode: 'Cash',
      notes: 'Regular fill',
    ),
    const PetrolEntry(
      id: 'PTL-002',
      bikeId: 'Bike-003 (Bajaj Pulsar)',
      date: '15 May, 2:00 PM',
      quantity: 3.2,
      amount: 320,
      paymentMode: 'UPI',
      notes: 'Emergency top-up',
    ),
    const PetrolEntry(
      id: 'PTL-003',
      bikeId: 'Bike-002 (Honda Shine)',
      date: '14 May, 9:00 AM',
      quantity: 6.0,
      amount: 600,
      paymentMode: 'Cash',
    ),
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitPetrolEntry() {
    if (_selectedBike == null) {
      _showSnackbar('Please select a bike', AppTheme.danger);
      return;
    }
    if (_quantityController.text.isEmpty) {
      _showSnackbar('Please enter quantity', AppTheme.danger);
      return;
    }
    if (_amountController.text.isEmpty) {
      _showSnackbar('Please enter amount', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isSubmitting = false;
        _petrolEntries.insert(
            0,
            PetrolEntry(
              id: 'PTL-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
              bikeId: _selectedBike!,
              date: 'Today ${DateTime.now().hour}:${DateTime.now().minute}',
              quantity: double.parse(_quantityController.text),
              amount: double.parse(_amountController.text),
              paymentMode: _paymentMode,
              notes: _notesController.text,
            ));
      });
      _showSnackbar('Petrol entry added successfully!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _selectedBike = null;
    _quantityController.clear();
    _amountController.clear();
    _notesController.clear();
    setState(() => _paymentMode = 'Cash');
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
            title: 'Select Bike',
            color: AppTheme.info,
            child: _buildBikeSelector(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Petrol Details',
            color: AppTheme.warning,
            child: _buildPetrolDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Payment Mode',
            color: AppTheme.primary,
            child: _buildPaymentMode(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '4',
            title: 'Notes (Optional)',
            color: AppTheme.success,
            child: _buildNotes(),
          ),
          const SizedBox(height: 20),
          _buildSubmitButton(),
          const SizedBox(height: 20),
          _buildRecentEntries(),
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
          child: const Text('🏍️', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bike Petrol Tracking',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Record petrol details for site bikes',
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
            child: const Icon(Icons.local_gas_station,
                color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Petrol Usage',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Record petrol quantity, amount, and payment mode for each bike.',
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

  Widget _buildBikeSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedBike,
        hint: const Text('Select bike'),
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.motorcycle, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: _bikes.map((bike) {
          return DropdownMenuItem(
            value: bike,
            child: Text(bike, style: const TextStyle(fontSize: 13)),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedBike = value),
      ),
    );
  }

  Widget _buildPetrolDetails() {
    return Column(
      children: [
        TextField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity (Liters)',
            hintText: 'Enter petrol quantity',
            prefixIcon: const Icon(Icons.water_drop, size: 20),
            suffixText: 'L',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount (₹)',
            hintText: 'Enter total amount',
            prefixIcon: const Icon(Icons.currency_rupee, size: 20),
            suffixText: '₹',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMode() {
    return Row(
      children: ['Cash', 'UPI', 'Digital'].map((mode) {
        final isSelected = _paymentMode == mode;
        IconData icon;
        switch (mode) {
          case 'Cash':
            icon = Icons.money;
            break;
          case 'UPI':
            icon = Icons.qr_code;
            break;
          default:
            icon = Icons.phone_android;
        }
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotes() {
    return TextField(
      controller: _notesController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Notes',
        hintText: 'Any additional information...',
        prefixIcon: const Icon(Icons.notes_outlined, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitPetrolEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.info,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Save Petrol Entry',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Petrol Entries',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._petrolEntries.map((entry) => _buildPetrolEntryCard(entry)),
      ],
    );
  }

  Widget _buildPetrolEntryCard(PetrolEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.motorcycle, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.bikeId,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${entry.quantity}L',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${entry.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: entry.paymentMode == 'UPI'
                            ? AppTheme.successBg
                            : AppTheme.warningBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        entry.paymentMode,
                        style: TextStyle(
                          fontSize: 9,
                          color: entry.paymentMode == 'UPI'
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.date,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.notes,
                  style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textMuted,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Snacks/Extras Tab ──────────────────────────────────────────────────────
class SnacksExtrasTab extends StatefulWidget {
  const SnacksExtrasTab({super.key});

  @override
  State<SnacksExtrasTab> createState() => _SnacksExtrasTabState();
}

class _SnacksExtrasTabState extends State<SnacksExtrasTab> {
  String _paymentMode = 'Cash';
  bool _isSubmitting = false;

  final TextEditingController _broughtByController = TextEditingController();
  final TextEditingController _forWhomController = TextEditingController();
  final TextEditingController _itemsController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  final List<SnackEntry> _snackEntries = [
    const SnackEntry(
      id: 'SNK-001',
      broughtBy: 'Ramesh',
      forWhom: 'Site A Team',
      items: 'Samosa, Tea, Biscuits',
      cost: 350,
      paymentMode: 'Cash',
      date: '15 May, 11:00 AM',
    ),
    const SnackEntry(
      id: 'SNK-002',
      broughtBy: 'Suresh',
      forWhom: 'All Workers',
      items: 'Cold drinks, Chips',
      cost: 500,
      paymentMode: 'UPI',
      date: '14 May, 3:30 PM',
    ),
  ];

  @override
  void dispose() {
    _broughtByController.dispose();
    _forWhomController.dispose();
    _itemsController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submitSnackEntry() {
    if (_broughtByController.text.isEmpty) {
      _showSnackbar('Please enter who brought', AppTheme.danger);
      return;
    }
    if (_forWhomController.text.isEmpty) {
      _showSnackbar('Please enter for whom', AppTheme.danger);
      return;
    }
    if (_itemsController.text.isEmpty) {
      _showSnackbar('Please enter items', AppTheme.danger);
      return;
    }
    if (_costController.text.isEmpty) {
      _showSnackbar('Please enter cost', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isSubmitting = false;
        _snackEntries.insert(
            0,
            SnackEntry(
              id: 'SNK-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
              broughtBy: _broughtByController.text,
              forWhom: _forWhomController.text,
              items: _itemsController.text,
              cost: double.parse(_costController.text),
              paymentMode: _paymentMode,
              date: 'Today ${DateTime.now().hour}:${DateTime.now().minute}',
            ));
      });
      _showSnackbar('Snack entry added successfully!', AppTheme.success);
      _clearForm();
    });
  }

  void _clearForm() {
    _broughtByController.clear();
    _forWhomController.clear();
    _itemsController.clear();
    _costController.clear();
    setState(() => _paymentMode = 'Cash');
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
            title: 'Who Brought & For Whom',
            color: AppTheme.warning,
            child: _buildPeopleDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Items & Cost',
            color: AppTheme.info,
            child: _buildItemDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Payment Mode',
            color: AppTheme.success,
            child: _buildPaymentMode(),
          ),
          const SizedBox(height: 20),
          _buildSubmitButton(),
          const SizedBox(height: 20),
          _buildRecentEntries(),
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
          child: const Text('🍕', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Snacks & Extras',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Record snacks and extra items details',
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
            child:
                const Icon(Icons.fastfood, color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Extras',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Record who brought items, for whom, what items, and payment details.',
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

  Widget _buildPeopleDetails() {
    return Column(
      children: [
        TextField(
          controller: _broughtByController,
          decoration: InputDecoration(
            labelText: 'Brought By',
            hintText: 'Name of person who brought',
            prefixIcon: const Icon(Icons.person, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _forWhomController,
          decoration: InputDecoration(
            labelText: 'For Whom',
            hintText: 'Team, department, or person names',
            prefixIcon: const Icon(Icons.people, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildItemDetails() {
    return Column(
      children: [
        TextField(
          controller: _itemsController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Items/Snacks',
            hintText: 'List all items (e.g., Samosa, Tea, Biscuits)',
            prefixIcon: const Icon(Icons.fastfood, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _costController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total Cost (₹)',
            hintText: 'Enter total cost',
            prefixIcon: const Icon(Icons.currency_rupee, size: 20),
            suffixText: '₹',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMode() {
    return Row(
      children: ['Cash', 'UPI', 'Digital'].map((mode) {
        final isSelected = _paymentMode == mode;
        IconData icon;
        switch (mode) {
          case 'Cash':
            icon = Icons.money;
            break;
          case 'UPI':
            icon = Icons.qr_code;
            break;
          default:
            icon = Icons.phone_android;
        }
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _paymentMode = mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.success.withValues(alpha: 0.15)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.success : AppTheme.border,
                  width: isSelected ? 1.5 : 0.8,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppTheme.success : AppTheme.textMuted,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitSnackEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.warning,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, size: 20, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Save Snack Entry',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecentEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Snack Entries',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._snackEntries.map((entry) => _buildSnackEntryCard(entry)),
      ],
    );
  }

  Widget _buildSnackEntryCard(SnackEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.8),
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
                child: const Icon(Icons.fastfood,
                    color: AppTheme.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.broughtBy} → ${entry.forWhom}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.items,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${entry.cost.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warning,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.paymentMode == 'UPI'
                          ? AppTheme.successBg
                          : AppTheme.warningBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.paymentMode,
                      style: TextStyle(
                        fontSize: 9,
                        color: entry.paymentMode == 'UPI'
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                entry.date,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
