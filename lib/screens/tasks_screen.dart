import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  String _filter = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Check diesel levels at Site A', 'type': 'Daily', 'done': false, 'priority': 'high', 'dueDate': 'Today', 'assignedBy': 'HOD Sharma'},
    {'title': 'Update machine log for MCH-003', 'type': 'Daily', 'done': true, 'priority': 'normal', 'dueDate': 'Yesterday', 'assignedBy': 'HOD Sharma'},
    {'title': 'Verify operator attendance photos', 'type': 'Daily', 'done': false, 'priority': 'high', 'dueDate': 'Today', 'assignedBy': 'HOD Patel'},
    {'title': 'Submit weekly stock summary', 'type': 'Weekly', 'done': false, 'priority': 'normal', 'dueDate': 'This Week', 'assignedBy': 'HOD Sharma'},
    {'title': 'Calibrate equipment at Site B', 'type': 'Weekly', 'done': true, 'priority': 'high', 'dueDate': 'This Week', 'assignedBy': 'HOD Mehta'},
    {'title': 'Review rental records', 'type': 'Monthly', 'done': false, 'priority': 'normal', 'dueDate': 'End of Month', 'assignedBy': 'HOD Sharma'},
    {'title': 'Conduct safety inspection', 'type': 'Weekly', 'done': false, 'priority': 'high', 'dueDate': 'Tomorrow', 'assignedBy': 'HOD Patel'},
    {'title': 'Update stock register', 'type': 'Daily', 'done': false, 'priority': 'normal', 'dueDate': 'Today', 'assignedBy': 'HOD Mehta'},
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTasks {
    var tasks = _tasks;
    
    // Apply type filter
    if (_filter != 'All') {
      tasks = tasks.where((t) => t['type'] == _filter).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      tasks = tasks.where((t) => 
        t['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        t['assignedBy'].toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    return tasks;
  }

  int get _totalCount => _tasks.length;
  int get _doneCount => _tasks.where((t) => t['done'] == true).length;
  int get _pendingCount => _totalCount - _doneCount;
  double get _completionPercentage => _totalCount > 0 ? (_doneCount / _totalCount) * 100 : 0;

  void _toggleTask(Map<String, dynamic> task) {
    setState(() {
      task['done'] = !task['done'];
    });
    _showSnackbar(
      task['done'] ? 'Task completed! Great job!' : 'Task marked as pending',
      task['done'] ? AppTheme.success : AppTheme.warning,
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
    final filteredTasks = _filteredTasks;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Tasks & Checklist'),
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
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(seconds: 1));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildProgressSection(),
                const SizedBox(height: 20),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildCategoryTabs(),
                const SizedBox(height: 16),
                if (_searchQuery.isNotEmpty) _buildSearchChip(),
                if (filteredTasks.isEmpty)
                  _buildEmptyState()
                else
                  ...filteredTasks.map((task) => _buildTaskTile(task)),
                const SizedBox(height: 16),
                _buildMotivationalCard(),
                const SizedBox(height: 16),
                const NoteBox(
                  title: 'Performance Tracking',
                  content: 'Task completion feeds into HOD-visible supervisor performance report automatically. Complete tasks on time to maintain high performance rating.',
                  icon: Icons.trending_up,
                ),
                const SizedBox(height: 16),
              ],
            ),
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
              colors: [AppTheme.success.withOpacity(0.15), AppTheme.success.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.success.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: const Text('✅', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasks & Checklist',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              SizedBox(height: 4),
              Text(
                'HOD-assigned tasks — complete and track progress',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
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
            'Overall Progress',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_completionPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Text(
                'Completed',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _completionPercentage / 100,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_doneCount completed', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              Text('$_pendingCount remaining', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total', '$_totalCount', AppTheme.primary, Icons.task_alt),
        const SizedBox(width: 12),
        _buildStatCard('Completed', '$_doneCount', AppTheme.success, Icons.check_circle),
        const SizedBox(width: 12),
        _buildStatCard('Pending', '$_pendingCount', AppTheme.warning, Icons.pending),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = ['All', 'Daily', 'Weekly', 'Monthly'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _filter == category;
          return GestureDetector(
            onTap: () => setState(() => _filter = category),
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
                boxShadow: isSelected ? AppTheme.subtleShadow : [],
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchChip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppTheme.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Search: "$_searchQuery"',
              style: const TextStyle(fontSize: 12, color: AppTheme.info),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _searchQuery = ''),
            child: const Icon(Icons.close, size: 16, color: AppTheme.info),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final isDone = task['done'] as bool;
    final type = task['type'] as String;
    final priority = task['priority'] as String;
    final dueDate = task['dueDate'] as String;
    final assignedBy = task['assignedBy'] as String;

    Color typeColor = type == 'Daily' ? AppTheme.info : 
                     type == 'Weekly' ? AppTheme.success : 
                     AppTheme.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? AppTheme.success.withOpacity(0.3) : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleTask(task),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: isDone
                        ? LinearGradient(colors: [AppTheme.success, AppTheme.successLight])
                        : null,
                    color: isDone ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone ? AppTheme.success : AppTheme.border,
                      width: 1.5,
                    ),
                  ),
                  child: isDone 
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDone ? AppTheme.textMuted : AppTheme.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTypeBadge(type, typeColor),
                          if (priority == 'high') _buildPriorityBadge(),
                          _buildDueDateChip(dueDate),
                          _buildAssignedByChip(assignedBy),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'Daily' ? Icons.today : 
            type == 'Weekly' ? Icons.weekend : 
            Icons.calendar_month,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.priority_high, size: 12, color: AppTheme.danger),
          SizedBox(width: 4),
          Text('High Priority', style: TextStyle(fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(String dueDate) {
    bool isUrgent = dueDate == 'Today' || dueDate == 'Tomorrow';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.warning.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 10, color: isUrgent ? AppTheme.warning : AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            dueDate,
            style: TextStyle(
              fontSize: 10,
              color: isUrgent ? AppTheme.warning : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedByChip(String assignedBy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 10, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            assignedBy,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
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
            child: const Icon(Icons.task_alt, size: 48, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tasks found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No tasks match "$_searchQuery"'
                : 'No ${_filter.toLowerCase()} tasks available',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalCard() {
    if (_doneCount == 0) return const SizedBox();
    
    String message;
    IconData icon;
    Color color;
    
    if (_completionPercentage >= 80) {
      message = "Excellent! You're crushing your goals! 🎉";
      icon = Icons.celebration;
      color = AppTheme.success;
    } else if (_completionPercentage >= 50) {
      message = "Great progress! Keep up the momentum! 💪";
      icon = Icons.rocket_launch;
      color = AppTheme.info;
    } else {
      message = "You're on your way! Complete pending tasks to level up! 🚀";
      icon = Icons.trending_up;
      color = AppTheme.warning;
    }
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color, height: 1.4),
            ),
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

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...['All', 'Daily', 'Weekly', 'Monthly'].map((filter) => ListTile(
              leading: Radio<String>(
                value: filter,
                groupValue: _filter,
                onChanged: (value) {
                  setState(() => _filter = value!);
                  Navigator.pop(context);
                },
              ),
              title: Text(filter),
            )).toList(),
          ],
        ),
      ),
    );
  }
}