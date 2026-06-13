import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'All';
  String _searchQuery = '';
  final bool _isLoading = false;

  // Checklists data
  final List<Map<String, dynamic>> _checklists = [
    {
      'title': 'Daily Safety Inspection',
      'type': 'Daily',
      'done': false,
      'items': ['Check fire extinguishers', 'Inspect safety gear', 'Verify emergency exits']
    },
    {
      'title': 'Equipment Maintenance Check',
      'type': 'Weekly',
      'done': false,
      'items': ['Check oil levels', 'Inspect hydraulic systems', 'Test emergency stops']
    },
    {
      'title': 'Site Cleanliness Audit',
      'type': 'Daily',
      'done': true,
      'items': ['Clear debris from walkways', 'Organize tool storage', 'Dispose waste properly']
    },
  ];

  // Tasks data
  final List<Map<String, dynamic>> _tasks = [
    {
      'title': 'Check diesel levels at Site A',
      'type': 'Daily',
      'done': false,
      'priority': 'high',
      'dueDate': 'Today',
      'assignedBy': 'HOD Sharma',
      'hasPhoto': false,
      'hasVideo': false,
      'hasVoiceNote': false,
      'notes': ''
    },
    {
      'title': 'Update machine log for MCH-003',
      'type': 'Daily',
      'done': true,
      'priority': 'normal',
      'dueDate': 'Yesterday',
      'assignedBy': 'HOD Sharma',
      'hasPhoto': true,
      'hasVideo': false,
      'hasVoiceNote': false,
      'notes': 'Completed with photo evidence'
    },
    {
      'title': 'Verify operator attendance photos',
      'type': 'Daily',
      'done': false,
      'priority': 'high',
      'dueDate': 'Today',
      'assignedBy': 'HOD Patel',
      'hasPhoto': false,
      'hasVideo': false,
      'hasVoiceNote': true,
      'notes': ''
    },
    {
      'title': 'Submit weekly stock summary',
      'type': 'Weekly',
      'done': false,
      'priority': 'normal',
      'dueDate': 'This Week',
      'assignedBy': 'HOD Sharma',
      'hasPhoto': false,
      'hasVideo': true,
      'hasVoiceNote': false,
      'notes': 'Video walkthrough required'
    },
  ];

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

  void _showMediaOptions(Map<String, dynamic> task) {
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
            Text('Add to: ${task['title']}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMediaOption(
                  icon: Icons.camera_alt,
                  label: 'Photo',
                  color: AppTheme.info,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => task['hasPhoto'] = !task['hasPhoto']);
                    _showSnackbar(
                      task['hasPhoto'] ? 'Photo attached' : 'Photo removed',
                      AppTheme.info,
                    );
                  },
                ),
                _buildMediaOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: AppTheme.danger,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => task['hasVideo'] = !task['hasVideo']);
                    _showSnackbar(
                      task['hasVideo'] ? 'Video attached' : 'Video removed',
                      AppTheme.danger,
                    );
                  },
                ),
                _buildMediaOption(
                  icon: Icons.mic,
                  label: 'Voice Note',
                  color: AppTheme.warning,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => task['hasVoiceNote'] = !task['hasVoiceNote']);
                    _showSnackbar(
                      task['hasVoiceNote'] ? 'Voice note added' : 'Voice note removed',
                      AppTheme.warning,
                    );
                  },
                ),
                _buildMediaOption(
                  icon: Icons.text_fields,
                  label: 'Text Note',
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.pop(context);
                    _showTextNoteDialog(task);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTextNoteDialog(Map<String, dynamic> task) {
    final TextEditingController noteController = TextEditingController(text: task['notes']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Text Note'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter your note here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => task['notes'] = noteController.text);
              Navigator.pop(context);
              _showSnackbar('Note saved successfully', AppTheme.success);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Checklists', icon: Icon(Icons.checklist)),
            Tab(text: 'Tasks', icon: Icon(Icons.task_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChecklistsTab(),
          _buildTasksTab(),
        ],
      ),
    );
  }

  Widget _buildChecklistsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildChecklistStats(),
          const SizedBox(height: 20),
          _buildCategoryTabs(),
          const SizedBox(height: 16),
          ..._checklists.map((checklist) => _buildChecklistCard(checklist)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildTasksStats(),
          const SizedBox(height: 20),
          _buildCategoryTabs(),
          const SizedBox(height: 16),
          ..._tasks.map((task) => _buildTaskTile(task)),
          const SizedBox(height: 16),
          const NoteBox(
            title: 'Performance Tracking',
            content:
                'Task completion feeds into HOD-visible supervisor performance report automatically. Complete tasks on time to maintain high performance rating.',
            icon: Icons.trending_up,
          ),
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
          child: const Text('✅', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasks & Checklist',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
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

  Widget _buildChecklistStats() {
    int total = _checklists.length;
    int completed = _checklists.where((c) => c['done'] == true).length;
    int pending = total - completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildStatItem('Total', '$total', Icons.checklist, Colors.white),
          _buildStatItem('Completed', '$completed', Icons.check_circle, Colors.green),
          _buildStatItem('Pending', '$pending', Icons.pending, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildTasksStats() {
    int total = _tasks.length;
    int completed = _tasks.where((t) => t['done'] == true).length;
    int pending = total - completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildStatItem('Total', '$total', Icons.task_alt, Colors.white),
          _buildStatItem('Completed', '$completed', Icons.check_circle, Colors.green),
          _buildStatItem('Pending', '$pending', Icons.pending, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
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
                    ? const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.accent])
                    : null,
                color: isSelected ? null : AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                  width: isSelected ? 0 : 0.8,
                ),
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

  Widget _buildChecklistCard(Map<String, dynamic> checklist) {
    final isDone = checklist['done'] as bool;
    final items = checklist['items'] as List<String>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        leading: GestureDetector(
          onTap: () => setState(() => checklist['done'] = !checklist['done']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: isDone
                  ? const LinearGradient(
                      colors: [AppTheme.success, AppTheme.successLight])
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
        ),
        title: Text(
          checklist['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDone ? AppTheme.textMuted : AppTheme.textPrimary,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${items.length} items',
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        children: items.map((item) => ListTile(
          dense: true,
          leading: const Icon(Icons.circle_outlined, size: 12, color: AppTheme.textMuted),
          title: Text(item, style: const TextStyle(fontSize: 13)),
        )).toList(),
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final isDone = task['done'] as bool;
    final type = task['type'] as String;
    final priority = task['priority'] as String;
    final dueDate = task['dueDate'] as String;
    final assignedBy = task['assignedBy'] as String;
    final hasPhoto = task['hasPhoto'] as bool;
    final hasVideo = task['hasVideo'] as bool;
    final hasVoiceNote = task['hasVoiceNote'] as bool;
    final notes = task['notes'] as String;

    Color typeColor = type == 'Daily'
        ? AppTheme.info
        : type == 'Weekly'
            ? AppTheme.success
            : AppTheme.warning;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border,
          width: 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        leading: GestureDetector(
          onTap: () => _toggleTask(task),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: isDone
                  ? const LinearGradient(
                      colors: [AppTheme.success, AppTheme.successLight])
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
        ),
        title: Text(
          task['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDone ? AppTheme.textMuted : AppTheme.textPrimary,
            decoration: isDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildTypeBadge(type, typeColor),
            if (priority == 'high') _buildPriorityBadge(),
            _buildDueDateChip(dueDate),
            _buildAssignedByChip(assignedBy),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPhoto) const Icon(Icons.camera_alt, size: 14, color: AppTheme.info),
            if (hasVideo) const Icon(Icons.videocam, size: 14, color: AppTheme.danger),
            if (hasVoiceNote) const Icon(Icons.mic, size: 14, color: AppTheme.warning),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primary),
              onPressed: () => _showMediaOptions(task),
            ),
          ],
        ),
        children: [
          if (notes.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.text_fields, size: 16, color: AppTheme.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Photo',
                  isActive: hasPhoto,
                  color: AppTheme.info,
                  onTap: () => setState(() => task['hasPhoto'] = !task['hasPhoto']),
                ),
                _buildMediaButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  isActive: hasVideo,
                  color: AppTheme.danger,
                  onTap: () => setState(() => task['hasVideo'] = !task['hasVideo']),
                ),
                _buildMediaButton(
                  icon: Icons.mic,
                  label: 'Voice',
                  isActive: hasVoiceNote,
                  color: AppTheme.warning,
                  onTap: () => setState(() => task['hasVoiceNote'] = !task['hasVoiceNote']),
                ),
                _buildMediaButton(
                  icon: Icons.text_fields,
                  label: 'Note',
                  isActive: notes.isNotEmpty,
                  color: AppTheme.success,
                  onTap: () => _showTextNoteDialog(task),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : AppTheme.border,
            width: isActive ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? color : AppTheme.textMuted, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isActive ? color : AppTheme.textMuted,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == 'Daily'
                ? Icons.today
                : type == 'Weekly'
                    ? Icons.weekend
                    : Icons.calendar_month,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            type,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600),
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high, size: 12, color: AppTheme.danger),
          SizedBox(width: 4),
          Text('High Priority',
              style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDueDateChip(String dueDate) {
    bool isUrgent = dueDate == 'Today' || dueDate == 'Tomorrow';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? AppTheme.warning.withValues(alpha: 0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time,
              size: 10,
              color: isUrgent ? AppTheme.warning : AppTheme.textMuted),
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
          const Icon(Icons.person_outline, size: 10, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            assignedBy,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
            const Text('Filter Tasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                )),
          ],
        ),
      ),
    );
  }
}