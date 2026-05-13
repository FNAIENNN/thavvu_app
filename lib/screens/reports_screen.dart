import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  // State variables
  String _selectedReport = '';
  String _selectedPeriod = 'Monthly';
  String _selectedFormat = 'PDF';
  bool _isGenerating = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockPointController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Report types data
  final List<Map<String, dynamic>> _reportTypes = [
    {'emoji': '📊', 'title': 'Machines Summary', 'desc': 'Machine ID · Operator · Rate · Earned · Used · Balance', 'color': AppTheme.info, 'icon': Icons.construction},
    {'emoji': '👷', 'title': 'Workers', 'desc': 'ID · Name · Earned · Used · Remaining balance', 'color': AppTheme.success, 'icon': Icons.people},
    {'emoji': '🔑', 'title': 'Rental', 'desc': 'ID · Item · Start/End · Days · Earned · Used · Remaining', 'color': AppTheme.danger, 'icon': Icons.key},
    {'emoji': '⛽', 'title': 'Diesel', 'desc': 'Batch ID · Total in · Consumed · Remaining', 'color': AppTheme.warning, 'icon': Icons.local_gas_station},
    {'emoji': '↩️', 'title': 'Returns', 'desc': 'Batch ID · Machine · Days · Earned · Used', 'color': AppTheme.info, 'icon': Icons.assignment_return},
    {'emoji': '🏍️', 'title': 'Site bikes petrol', 'desc': 'Bike ID · Petrol consumption', 'color': AppTheme.success, 'icon': Icons.two_wheeler},
  ];

  // Demo data for recent reports
  final List<Map<String, dynamic>> _recentReports = [
    {'id': 'RPT-001', 'title': 'Machines Summary', 'date': DateTime(2024, 5, 13), 'size': '2.4 MB', 'type': 'PDF', 'status': 'completed'},
    {'id': 'RPT-002', 'title': 'Workers Report', 'date': DateTime(2024, 5, 12), 'size': '1.8 MB', 'type': 'PDF', 'status': 'completed'},
    {'id': 'RPT-003', 'title': 'Diesel Consumption', 'date': DateTime(2024, 5, 11), 'size': '1.2 MB', 'type': 'Excel', 'status': 'completed'},
    {'id': 'RPT-004', 'title': 'Rental Summary', 'date': DateTime(2024, 5, 10), 'size': '892 KB', 'type': 'PDF', 'status': 'pending'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    
    // Initialize dates
    _startDate = DateTime.now().subtract(const Duration(days: 30));
    _endDate = DateTime.now();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _stockPointController.dispose();
    super.dispose();
  }

  // Helper methods
  int get _completedReportsCount => _recentReports.where((r) => r['status'] == 'completed').length;
  int get _pendingReportsCount => _recentReports.where((r) => r['status'] == 'pending').length;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _generateReport() {
    if (_selectedReport.isEmpty) {
      _showSnackbar('Please select a report type', AppTheme.warning);
      return;
    }

    setState(() => _isGenerating = true);
    
    // Simulate API call with realistic delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isGenerating = false);
      
      // Add to recent reports (simulated)
      final newReport = {
        'id': 'RPT-${DateTime.now().millisecondsSinceEpoch}',
        'title': _selectedReport,
        'date': DateTime.now(),
        'size': '${(150 + DateTime.now().millisecond % 500)} KB',
        'type': _selectedFormat,
        'status': 'completed',
      };
      
      _showSnackbar(
        '$_selectedReport report generated successfully!',
        AppTheme.success,
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () => _viewReport(newReport),
        ),
      );
    });
  }

  void _viewReport(Map<String, dynamic> report) {
    _showSnackbar('Opening ${report['title']}...', AppTheme.info);
  }

  void _downloadReport(Map<String, dynamic> report) {
    _showSnackbar('Downloading ${report['title']}...', AppTheme.success);
  }

  void _shareReport() {
    if (_selectedReport.isEmpty) {
      _showSnackbar('Please generate a report first', AppTheme.warning);
      return;
    }
    _showSnackbar('Sharing $_selectedReport report...', AppTheme.info);
  }

  void _refreshReports() {
    setState(() {});
    _showSnackbar('Reports refreshed!', AppTheme.success);
  }

  void _showSnackbar(String message, Color color, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppTheme.success ? Icons.check_circle :
              color == AppTheme.warning ? Icons.warning :
              Icons.info,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: action,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedReport.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareReport,
              tooltip: 'Share report',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatsOverview(),
              const SizedBox(height: 20),
              _buildStepSection(
                number: '01',
                title: 'Select Report Type',
                subtitle: 'Choose from ${_reportTypes.length} report categories',
                child: _buildReportTypesGrid(),
              ),
              const SizedBox(height: 24),
              _buildStepSection(
                number: '02',
                title: 'Apply Filters',
                subtitle: 'Narrow down your report data',
                child: _buildFiltersCard(),
              ),
              const SizedBox(height: 24),
              _buildStepSection(
                number: '03',
                title: 'Export Options',
                subtitle: 'Choose format and generate',
                child: _buildExportOptions(),
              ),
              const SizedBox(height: 24),
              _buildGenerateButton(),
              const SizedBox(height: 24),
              _buildRecentReports(),
              const SizedBox(height: 16),
              _buildInfoNote(),
              const SizedBox(height: 16),
            ],
          ),
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
              colors: [AppTheme.primary.withOpacity(0.15), AppTheme.primary.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('📊', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports & Analytics',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'Auto-generated summaries across all modules',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
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
      child: Row(
        children: [
          _buildStatOverviewItem('Reports', '${_recentReports.length}', Icons.description, Colors.white),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatOverviewItem('Generated', '$_completedReportsCount', Icons.check_circle, Colors.white),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatOverviewItem('Pending', '$_pendingReportsCount', Icons.pending, Colors.white),
        ],
      ),
    );
  }

  Widget _buildStatOverviewItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStepSection({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildReportTypesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _reportTypes.length,
      itemBuilder: (context, index) {
        final report = _reportTypes[index];
        final isSelected = _selectedReport == report['title'];
        final color = report['color'] as Color;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedReport = report['title']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                  : null,
              color: isSelected ? null : AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : AppTheme.border,
                width: isSelected ? 0 : 0.8,
              ),
              boxShadow: isSelected ? AppTheme.cardShadow : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    report['icon'] as IconData,
                    size: 24,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  report['title'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  report['desc'] as String,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? Colors.white70 : AppTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  Icons.calendar_today,
                  _formatDate(_startDate),
                  () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  Icons.calendar_today,
                  _formatDate(_endDate),
                  () => _selectDate(context, false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('Name / ID', 'Filter by name or ID', Icons.search, _nameController),
          const SizedBox(height: 16),
          _buildTextField('Stock Point', 'Filter by location', Icons.location_on_outlined, _stockPointController),
          const SizedBox(height: 16),
          const Text('Period Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'].map((period) {
              final isSelected = _selectedPeriod == period;
              return GestureDetector(
                onTap: () => setState(() => _selectedPeriod = period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                        : null,
                    color: isSelected ? null : AppTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 0 : 0.8,
                    ),
                  ),
                  child: Text(
                    period,
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
      ),
    );
  }

  Widget _buildDateField(String label, IconData icon, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: AppTheme.textMuted,
        ),
        filled: true,
        fillColor: AppTheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppTheme.primary,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildExportOptions() {
    final formats = ['PDF', 'Excel', 'CSV', 'Print'];
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
          const Text('Export Format', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: formats.map((format) {
              final isSelected = _selectedFormat == format;
              return GestureDetector(
                onTap: () => setState(() => _selectedFormat = format),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [AppTheme.primary, AppTheme.accent])
                        : null,
                    color: isSelected ? null : AppTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: isSelected ? 0 : 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        format == 'PDF' ? Icons.picture_as_pdf_rounded :
                        format == 'Excel' ? Icons.table_chart_rounded :
                        format == 'CSV' ? Icons.dataset_outlined :
                        Icons.print_rounded,
                        size: 16,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        format,
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
      ),
    );
  }

  Widget _buildGenerateButton() {
    final bool isValid = _selectedReport.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isValid
            ? LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.accent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isValid ? null : Colors.grey.shade400,
        boxShadow: isValid
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _isGenerating || !isValid ? null : _generateReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          disabledBackgroundColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isGenerating
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedFormat == 'PDF'
                        ? Icons.picture_as_pdf_rounded
                        : _selectedFormat == 'Excel'
                            ? Icons.table_chart_rounded
                            : _selectedFormat == 'CSV'
                                ? Icons.dataset_outlined
                                : Icons.print_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      !isValid
                          ? 'Select a report type first'
                          : 'Generate $_selectedReport Report ($_selectedFormat)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRecentReports() {
    if (_recentReports.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Reports', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            TextButton(
              onPressed: () {},
              child: const Text('View All', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentReports.take(3).map((report) => _buildRecentReportTile(report)),
      ],
    );
  }

  Widget _buildRecentReportTile(Map<String, dynamic> report) {
    final isPending = report['status'] == 'pending';
    final isPDF = report['type'] == 'PDF';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPDF ? Icons.picture_as_pdf : Icons.table_chart,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(report['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (isPending) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warningBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Pending', style: TextStyle(fontSize: 9, color: AppTheme.warning)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(report['date'])} • ${report['size']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 18),
            onPressed: isPending ? null : () => _downloadReport(report),
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18),
            onPressed: isPending ? null : () => _viewReport(report),
            tooltip: 'View',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: AppTheme.info, width: 3),
          top: BorderSide(color: AppTheme.border, width: 0.5),
          right: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lightbulb_outline, size: 18, color: AppTheme.info),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pro Tip', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                SizedBox(height: 4),
                Text(
                  'Reports can be exported in multiple formats. Use date filters to get accurate period-wise data. Schedule automatic reports for regular intervals.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}