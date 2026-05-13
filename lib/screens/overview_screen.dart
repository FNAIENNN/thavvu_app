import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class OverviewScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final Function(String) onNavigateModule;

  const OverviewScreen({
    super.key,
    required this.onNavigate,
    required this.onNavigateModule,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final int _totalTasks = 14;
  final int _completedTasks = 6;
  final int _pendingAmount = 24500;
  final String _userName = 'Rajesh';
  String _greeting = 'Good morning';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _updateGreeting();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greeting = 'Good morning';
      } else if (hour < 17) {
        _greeting = 'Good afternoon';
      } else {
        _greeting = 'Good evening';
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(),
                const SizedBox(height: 16),
                _buildStatsSection(),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(title: 'All Modules'),
                ),
                _buildModuleGrid(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F3460), Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1976D2).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1976D2), Color(0xFF0FA37A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Center(
                                    child: Text('👷', style: TextStyle(fontSize: 28)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_greeting, $_userName!',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTodayDate(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0FA37A).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF0FA37A).withOpacity(0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 7, color: Color(0xFF66BB6A)),
                          SizedBox(width: 5),
                          Text('Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF66BB6A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildDateChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    const days = [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Widget _buildDateChips() {
    final now = DateTime.now();
    return Row(
      children: [
        _dateChip(Icons.today_outlined, 'Day ${now.day}'),
        const SizedBox(width: 8),
        _dateChip(Icons.calendar_view_week_outlined, 'Week ${now.weekday}/7'),
        const SizedBox(width: 8),
        _dateChip(Icons.calendar_month_outlined, 'Month ${now.month}'),
      ],
    );
  }

  Widget _dateChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.white60),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Modules', '10', AppTheme.info, Icons.dashboard_rounded, 'Available'),
          const SizedBox(width: 10),
          _buildStatCard('Tasks', '$_totalTasks', AppTheme.success, Icons.task_alt_rounded, '$_completedTasks done'),
          const SizedBox(width: 10),
          _buildStatCard('Pending', '₹$_pendingAmount', AppTheme.warning, Icons.currency_rupee_rounded, 'To collect'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.18)),
          boxShadow: AppTheme.subtleShadow,
          color: Colors.white,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
            Text(sub, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          Row(
            children: [
              _quickActionBtn('Attendance', Icons.fingerprint_rounded, AppTheme.success, () => widget.onNavigate(3)),
              const SizedBox(width: 10),
              _quickActionBtn('New Machine', Icons.add_business_rounded, AppTheme.warning, () => widget.onNavigate(1)),
              const SizedBox(width: 10),
              _quickActionBtn('Daily Log', Icons.edit_calendar_rounded, AppTheme.info, () => widget.onNavigate(2)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quickActionBtn('HOD Tasks', Icons.assignment_turned_in_rounded, AppTheme.primary, () => widget.onNavigateModule('/hodtasks')),
              const SizedBox(width: 10),
              _quickActionBtn('Maps', Icons.map_outlined, AppTheme.warning, () => widget.onNavigateModule('/maps')),
              const SizedBox(width: 10),
              _quickActionBtn('Reports', Icons.bar_chart_rounded, AppTheme.danger, () => widget.onNavigateModule('/reports')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: 6),
              Text(label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleGrid() {
    final modules = [
      {'emoji': '🗺️', 'title': 'Maps & Specs', 'subtitle': 'Location points & maps', 'navType': 'route', 'route': '/maps', 'color': AppTheme.info, 'popularity': 70},
      {'emoji': '📋', 'title': 'HOD Tasks', 'subtitle': 'Assigned tasks by HOD', 'navType': 'route', 'route': '/hodtasks', 'color': AppTheme.success, 'popularity': 82},
      {'emoji': '🚜', 'title': 'New Machine Entry', 'subtitle': '10 fields · HOD approval', 'navType': 'bottom', 'navIndex': 1, 'color': AppTheme.warning, 'popularity': 95},
      {'emoji': '📋', 'title': 'Daily Machines Data', 'subtitle': '7 fields · Daily log', 'navType': 'bottom', 'navIndex': 2, 'color': AppTheme.info, 'popularity': 88},
      {'emoji': '🪪', 'title': 'Attendance', 'subtitle': 'Regular + outside workers', 'navType': 'bottom', 'navIndex': 3, 'color': AppTheme.success, 'popularity': 92},
      {'emoji': '📦', 'title': 'Stock Inventory', 'subtitle': 'Orders · Returns · Levels', 'navType': 'route', 'route': '/stock', 'color': AppTheme.warning, 'popularity': 78},
      {'emoji': '🔄', 'title': 'Internal Transfers', 'subtitle': 'Point-to-point stock', 'navType': 'route', 'route': '/transfers', 'color': AppTheme.info, 'popularity': 72},
      {'emoji': '🔑', 'title': 'Rental', 'subtitle': 'Equipment hire tracking', 'navType': 'route', 'route': '/rental', 'color': AppTheme.danger, 'popularity': 68},
      {'emoji': '✅', 'title': 'Tasks & Checklist', 'subtitle': 'HOD-assigned · Daily/Weekly', 'navType': 'route', 'route': '/tasks', 'color': AppTheme.success, 'popularity': 85},
      {'emoji': '📊', 'title': 'Reports', 'subtitle': 'Auto-generated · 7 types', 'navType': 'route', 'route': '/reports', 'color': AppTheme.primary, 'popularity': 75},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.88,
        ),
        itemCount: modules.length,
        itemBuilder: (context, index) {
          final module = modules[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 40)),
            tween: Tween(begin: 0, end: 1),
            builder: (_, value, child) => Transform.scale(
              scale: 0.85 + (0.15 * value),
              child: Opacity(opacity: value, child: child),
            ),
            child: _ModuleCard(
              emoji: module['emoji'] as String,
              title: module['title'] as String,
              subtitle: module['subtitle'] as String,
              color: module['color'] as Color,
              popularity: module['popularity'] as int,
              onTap: () {
                if (module['navType'] == 'bottom') {
                  widget.onNavigate(module['navIndex'] as int);
                } else {
                  widget.onNavigateModule(module['route'] as String);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final int popularity;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.popularity,
    required this.onTap,
  });

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: widget.color.withOpacity(0.15), width: 1),
            boxShadow: [
              BoxShadow(color: widget.color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.color.withOpacity(0.15), widget.color.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 10, color: widget.color),
                        const SizedBox(width: 2),
                        Text('${widget.popularity}%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: widget.color)),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A1628), height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(widget.subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Open', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.color)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 11, color: widget.color),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
