import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

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
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RegularWorkersTab(),
                OutsideWorkersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text('🪪', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Management',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mark Worker Attendance',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Present', '24', AppTheme.success, Icons.check_circle),
        const SizedBox(width: 12),
        _buildStatCard('Absent', '3', AppTheme.danger, Icons.cancel),
        const SizedBox(width: 12),
        _buildStatCard('Late', '5', AppTheme.warning, Icons.access_time),
        const SizedBox(width: 12),
        _buildStatCard('Leave', '2', AppTheme.info, Icons.beach_access),
      ],
    );
  }

  Widget _buildStatCard(String label, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        children: [
          _buildTab('Regular Workers', 0),
          _buildTab('Outside Workers', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== REGULAR WORKERS TAB ====================
class RegularWorkersTab extends StatefulWidget {
  const RegularWorkersTab({super.key});

  @override
  State<RegularWorkersTab> createState() => _RegularWorkersTabState();
}

class _RegularWorkersTabState extends State<RegularWorkersTab> {
  String _selectedMethod = 'ID Scan';
  String _selectedStatus = 'Present';
  bool _morningMarked = false;
  bool _eveningMarked = false;
  String? _selectedWorkerId;

  final List<Map<String, String>> _workers = [
    {'id': 'ATT-001', 'name': 'John Doe', 'department': 'Operations'},
    {'id': 'ATT-002', 'name': 'Jane Smith', 'department': 'Maintenance'},
    {'id': 'ATT-003', 'name': 'Robert Johnson', 'department': 'Logistics'},
    {'id': 'ATT-004', 'name': 'Maria Garcia', 'department': 'Quality'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildStep(
            1,
            'Select Attendance ID',
            _buildWorkerDropdown(),
            badge: _buildHodBadge(),
          ),
          const SizedBox(height: 16),
          _buildStep(
            2,
            'Morning & Evening Session',
            _buildSessionSection(),
          ),
          const SizedBox(height: 16),
          _buildStep(
            3,
            'ID Scan Method',
            _buildMethodSection(),
          ),
          const SizedBox(height: 16),
          _buildStep(
            4,
            'Attendance Status',
            _buildStatusSection(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
        ],
      ),
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
                  'Today\'s Attendance',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mark attendance using ID scan or manual entry. Photos are required for verification.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedWorkerId,
        decoration: const InputDecoration(
          hintText: 'Select worker',
          prefixIcon: Icon(Icons.badge_outlined),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: _workers.map((worker) {
          return DropdownMenuItem(
            value: worker['id'],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${worker['id']} • ${worker['department']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedWorkerId = value),
      ),
    );
  }

  Widget _buildHodBadge() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.danger),
          const SizedBox(width: 6),
          const Text(
            'IDs created by HOD with Aadhaar',
            style: TextStyle(fontSize: 11, color: AppTheme.danger, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSessionCard(
                'Morning',
                '🌅',
                _morningMarked,
                () => setState(() => _morningMarked = !_morningMarked),
                AppTheme.warning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSessionCard(
                'Evening',
                '🌙',
                _eveningMarked,
                () => setState(() => _eveningMarked = !_eveningMarked),
                AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildPhotoCard('Session attendance photo', required: true),
      ],
    );
  }

  Widget _buildSessionCard(
    String title,
    String emoji,
    bool isMarked,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: isMarked
              ? LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMarked ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMarked ? color : AppTheme.border,
            width: isMarked ? 1.5 : 0.8,
          ),
          boxShadow: isMarked ? AppTheme.subtleShadow : [],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMarked ? color : AppTheme.textSecondary,
              ),
            ),
            if (isMarked) ...[
              const SizedBox(height: 6),
              Icon(Icons.check_circle, color: color, size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodSection() {
    final methods = [
      {'label': 'ID Scan', 'emoji': '📷', 'color': AppTheme.success},
      {'label': 'Manual', 'emoji': '⌨️', 'color': AppTheme.info},
      {'label': 'Manual + Photo', 'emoji': '📝', 'color': AppTheme.warning},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: methods.map((method) {
        final isSelected = _selectedMethod == method['label'];
        final color = method['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedMethod = method['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? color : AppTheme.border,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(method['emoji'] as String, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  method['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle, color: color, size: 14),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusSection() {
    final statuses = [
      {'label': 'Present', 'color': AppTheme.success, 'icon': Icons.check_circle},
      {'label': 'Absent', 'color': AppTheme.danger, 'icon': Icons.cancel},
      {'label': 'Half day', 'color': AppTheme.warning, 'icon': Icons.hourglass_top},
      {'label': 'Leave', 'color': AppTheme.info, 'icon': Icons.beach_access},
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: statuses.map((status) {
        final isSelected = _selectedStatus == status['label'];
        final color = status['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedStatus = status['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? color : AppTheme.border,
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status['icon'] as IconData, color: isSelected ? color : AppTheme.textMuted, size: 16),
                const SizedBox(width: 8),
                Text(
                  status['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoCard(String label, {bool required = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.infoBg, AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('📷', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  required ? 'Tap to capture (Required)' : 'Tap to capture (Optional)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.info),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_alt, size: 20, color: AppTheme.info),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int number, String title, Widget content, {Widget? badge}) {
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
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
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
          content,
          if (badge != null) badge,
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedWorkerId == null) {
            _showSnackbar('Please select a worker', AppTheme.danger);
            return;
          }
          if (!_morningMarked && !_eveningMarked) {
            _showSnackbar('Please mark at least one session', AppTheme.warning);
            return;
          }
          _showSnackbar('Attendance marked successfully!', AppTheme.success);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Mark Attendance',
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
      ),
    );
  }
}

// ==================== OUTSIDE WORKERS TAB ====================
class OutsideWorkersTab extends StatefulWidget {
  const OutsideWorkersTab({super.key});

  @override
  State<OutsideWorkersTab> createState() => _OutsideWorkersTabState();
}

class _OutsideWorkersTabState extends State<OutsideWorkersTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _wageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedWorker;
  String _selectedStatus = 'Present';
  bool _isCreating = false;

  final List<Map<String, String>> _outsideWorkers = [
    {'id': 'OW-001', 'name': 'Raju', 'wage': '500'},
    {'id': 'OW-002', 'name': 'Lakshmi', 'wage': '450'},
    {'id': 'OW-003', 'name': 'Suresh', 'wage': '550'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _wageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCreateProfileCard(),
          const SizedBox(height: 16),
          _buildMarkAttendanceCard(),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCreateProfileCard() {
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
                    colors: [AppTheme.info, AppTheme.infoLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '1',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create Outside Worker Profile',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Worker Full Name',
              prefixIcon: const Icon(Icons.person_outline),
              hintText: 'Enter worker\'s full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Daily Wage (₹)',
              prefixIcon: const Icon(Icons.currency_rupee),
              hintText: 'Enter daily wage amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: const Icon(Icons.notes_outlined),
              hintText: 'Any additional information...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.dangerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.danger),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'HOD approval required for permanent record',
                    style: TextStyle(fontSize: 11, color: AppTheme.danger),
                  ),
                ),
                if (_isCreating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _createProfile,
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.info,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('Save Profile', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAttendanceCard() {
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
                    colors: [AppTheme.success, AppTheme.successLight],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '2',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mark Attendance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedWorker,
              decoration: const InputDecoration(
                hintText: 'Select outside worker',
                prefixIcon: Icon(Icons.people_outline),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _outsideWorkers.map((worker) {
                return DropdownMenuItem(
                  value: worker['id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(worker['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${worker['id']} • ₹${worker['wage']}/day', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedWorker = value),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildStatusChip('Present', AppTheme.success, Icons.check_circle),
              _buildStatusChip('Absent', AppTheme.danger, Icons.cancel),
              _buildStatusChip('Half day', AppTheme.warning, Icons.hourglass_top),
              _buildStatusChip('Leave', AppTheme.info, Icons.beach_access),
            ],
          ),
          const SizedBox(height: 16),
          _buildPhotoCard('Attendance live photo', required: true),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    final isSelected = _selectedStatus == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textMuted, size: 16),
            const SizedBox(width: 8),
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

  Widget _buildPhotoCard(String label, {bool required = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.info.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('📷', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  required ? 'Tap to capture (Required)' : 'Tap to capture',
                  style: const TextStyle(fontSize: 11, color: AppTheme.info),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.camera_alt, size: 18, color: AppTheme.info),
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
        onPressed: () {
          if (_selectedWorker == null) {
            _showSnackbar('Please select a worker', AppTheme.danger);
            return;
          }
          _showSnackbar('Outside worker attendance marked!', AppTheme.success);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt_1, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Mark Outside Worker Attendance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _createProfile() {
    if (_nameController.text.isEmpty || _wageController.text.isEmpty) {
      _showSnackbar('Please fill name and wage', AppTheme.danger);
      return;
    }
    setState(() => _isCreating = true);
    Future.delayed(const Duration(seconds: 1), () {
      setState(() => _isCreating = false);
      _showSnackbar('Profile created! Awaiting HOD approval', AppTheme.success);
      _nameController.clear();
      _wageController.clear();
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
      ),
    );
  }
}