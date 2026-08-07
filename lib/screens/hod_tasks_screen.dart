import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

class HODTasksScreen extends StatefulWidget {
  const HODTasksScreen({super.key});

  @override
  State<HODTasksScreen> createState() => _HODTasksScreenState();
}

class _HODTasksScreenState extends State<HODTasksScreen> with TickerProviderStateMixin {
  String _filter = 'All';
  String _searchQuery = '';
  late TabController _tabController;
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  List<AppTask> _filteredTasks(List<AppTask> tasks) {
    var filtered = tasks;

    if (_filter != 'All') {
      filtered = filtered.where((t) => t.type == _filter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) =>
        t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        t.assignedBy.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  void _toggleTask(AppTask task) {
    final store = context.read<AppStore>();
    store.toggleTask(task.id);
    _showSnackbar(
      !task.done
        ? 'Task completed! +${task.points} points earned!'
        : 'Task marked as pending',
      !task.done ? AppTheme.success : AppTheme.warning,
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
    final hodTasks = context.watch<AppStore>().hodTasks;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('HOD Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'My Tasks', icon: Icon(Icons.assignment)),
            Tab(text: 'Performance', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(hodTasks),
          _buildPerformanceTab(hodTasks),
        ],
      ),
    );
  }

  Widget _buildTasksTab(List<AppTask> hodTasks) {
    final filteredTasks = _filteredTasks(hodTasks);
    final completedCount = hodTasks.where((t) => t.done).length;
    final totalPoints = hodTasks.where((t) => t.done).fold(0, (sum, t) => sum + t.points);

    return Column(
      children: [
        _buildStatsBar(hodTasks.length, completedCount, totalPoints),
        _buildFilterBar(),
        Expanded(
          child: filteredTasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) => _buildTaskCard(filteredTasks[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(int totalTasks, int completedCount, int totalPoints) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          _buildStatItem('Tasks', '$totalTasks', Icons.task_alt),
          Container(width: 1, height: 30, color: Colors.white24),
          _buildStatItem('Completed', '$completedCount', Icons.check_circle),
          Container(width: 1, height: 30, color: Colors.white24),
          _buildStatItem('Points', '$totalPoints', Icons.star),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        children: [
          if (_searchQuery.isNotEmpty) _buildSearchChip(),
          Wrap(
            spacing: 8,
            children: ['All', 'Daily', 'Weekly', 'Monthly'].map((filter) {
              final isSelected = _filter == filter;
              return FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (_) => setState(() => _filter = filter),
                backgroundColor: AppTheme.surface,
                selectedColor: AppTheme.primary.withOpacity(0.2),
                checkmarkColor: AppTheme.primary,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, size: 14, color: AppTheme.info),
          const SizedBox(width: 6),
          Text('"$_searchQuery"', style: const TextStyle(fontSize: 11, color: AppTheme.info)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _searchQuery = ''),
            child: const Icon(Icons.close, size: 14, color: AppTheme.info),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(AppTask task) {
    final isCompleted = task.done;
    final type = task.type;
    final priority = task.priority;
    final dueDate = task.dueDate;

    Color typeColor = type == 'Daily' ? AppTheme.info : 
                     type == 'Weekly' ? AppTheme.success : 
                     AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? AppTheme.success.withOpacity(0.3) : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleTask(task),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? AppTheme.success : AppTheme.border,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 16, color: AppTheme.success)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? AppTheme.textMuted : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(type, style: TextStyle(fontSize: 10, color: typeColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.description ?? '',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildChip(Icons.person_outline, task.assignedBy),
                    _buildDueDateChip(dueDate),
                    if (priority == 'high') _buildPriorityChip(),
                    _buildPointsChip(task.points),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(String dueDate) {
    bool isUrgent = dueDate == 'Today' || dueDate == 'Tomorrow';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.warningBg : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 12, color: isUrgent ? AppTheme.warning : AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(dueDate, style: TextStyle(fontSize: 10, color: isUrgent ? AppTheme.warning : AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.priority_high, size: 12, color: AppTheme.danger),
          SizedBox(width: 4),
          Text('High Priority', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
        ],
      ),
    );
  }

  Widget _buildPointsChip(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: AppTheme.success),
          const SizedBox(width: 4),
          Text('+$points pts', style: const TextStyle(fontSize: 10, color: AppTheme.success)),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab(List<AppTask> hodTasks) {
    final completedCount = hodTasks.where((t) => t.done).length;
    final pendingCount = hodTasks.length - completedCount;
    final completionPercentage = hodTasks.isNotEmpty ? (completedCount / hodTasks.length) * 100 : 0.0;
    final totalPoints = hodTasks.where((t) => t.done).fold(0, (sum, t) => sum + t.points);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceHeader(),
          const SizedBox(height: 20),
          _buildProgressCard(completionPercentage, completedCount, pendingCount),
          const SizedBox(height: 20),
          _buildTaskBreakdown(hodTasks),
          const SizedBox(height: 20),
          _buildRecentAchievements(),
          const SizedBox(height: 20),
          _buildLeaderboardCard(totalPoints),
        ],
      ),
    );
  }

  Widget _buildPerformanceHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.success.withOpacity(0.15), AppTheme.success.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Text('🏆', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Track your task completion progress', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(double completionPercentage, int completedCount, int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overall Progress', style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${completionPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Text('of tasks completed', style: TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completionPercentage / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$completedCount completed', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Text('$pendingCount remaining', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskBreakdown(List<AppTask> hodTasks) {
    final dailyCount = hodTasks.where((t) => t.type == 'Daily').length;
    final weeklyCount = hodTasks.where((t) => t.type == 'Weekly').length;
    final monthlyCount = hodTasks.where((t) => t.type == 'Monthly').length;
    final dailyCompleted = hodTasks.where((t) => t.type == 'Daily' && t.done).length;
    final weeklyCompleted = hodTasks.where((t) => t.type == 'Weekly' && t.done).length;
    final monthlyCompleted = hodTasks.where((t) => t.type == 'Monthly' && t.done).length;

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
          const Text('Task Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildBreakdownItem('Daily Tasks', dailyCompleted, dailyCount, AppTheme.info),
          const SizedBox(height: 10),
          _buildBreakdownItem('Weekly Tasks', weeklyCompleted, weeklyCount, AppTheme.success),
          const SizedBox(height: 10),
          _buildBreakdownItem('Monthly Tasks', monthlyCompleted, monthlyCount, AppTheme.warning),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String title, int completed, int total, Color color) {
    final percentage = total > 0 ? (completed / total) * 100 : 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('$completed/$total', style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAchievements() {
    final achievements = [
      {'title': 'First Task Completed', 'points': 50, 'date': '2024-05-10', 'achieved': true},
      {'title': '5 Tasks Streak', 'points': 100, 'date': '2024-05-12', 'achieved': true},
      {'title': 'Weekly Warrior', 'points': 200, 'date': '', 'achieved': false},
      {'title': 'Perfect Month', 'points': 500, 'date': '', 'achieved': false},
    ];

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
          const Text('Achievements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...achievements.map((achievement) => _buildAchievementTile(achievement)),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(Map<String, dynamic> achievement) {
    final isAchieved = achievement['achieved'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAchieved ? AppTheme.successBg : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAchieved ? AppTheme.success.withOpacity(0.3) : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(
            isAchieved ? Icons.emoji_events : Icons.lock_outline,
            size: 24,
            color: isAchieved ? AppTheme.success : AppTheme.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement['title'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('+${achievement['points']} points', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          if (isAchieved)
            Text(achievement['date'], style: const TextStyle(fontSize: 10, color: AppTheme.success)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardCard(int totalPoints) {
    final topPerformers = [
      {'rank': 1, 'name': 'You', 'points': totalPoints, 'badge': '🥇'},
      {'rank': 2, 'name': 'Rahul S.', 'points': 185, 'badge': '🥈'},
      {'rank': 3, 'name': 'Priya M.', 'points': 150, 'badge': '🥉'},
    ];

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
          const Text('Leaderboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...topPerformers.map((performer) => _buildLeaderboardTile(performer)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(Map<String, dynamic> performer) {
    final isUser = performer['name'] == 'You';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isUser ? Border.all(color: AppTheme.primary.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Text(performer['badge'], style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text('${performer['rank']}.', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              performer['name'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isUser ? FontWeight.w700 : FontWeight.w500,
                color: isUser ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Text('${performer['points']} pts', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_turned_in, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          const Text('No tasks found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty ? 'No tasks match "$_searchQuery"' : 'No ${_filter.toLowerCase()} tasks available',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter task title or assignee',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
