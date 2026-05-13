import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ─── INTERNAL TRANSFERS ──────────────────────────────────────────────────────
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  String _transferStatus = '';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ModuleHeader(
            title: 'Internal Transfers',
            subtitle: 'Move stock between stock points with receiver confirmation',
            emoji: '🔄',
            color: AppTheme.info,
          ),
          const SizedBox(height: 20),

          _TransferCard(
            step: 1,
            title: 'Source & Destination',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  hint: const Text('From stock point', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  decoration: _dropdownDecoration(Icons.arrow_circle_up_outlined, AppTheme.danger),
                  items: const [
                    DropdownMenuItem(value: 'a', child: Text('Site A - North', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'b', child: Text('Warehouse Main', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Icon(Icons.keyboard_double_arrow_down, color: AppTheme.textMuted, size: 28),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  hint: const Text('To stock point', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  decoration: _dropdownDecoration(Icons.arrow_circle_down_outlined, AppTheme.success),
                  items: const [
                    DropdownMenuItem(value: 'b', child: Text('Site B - South', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'c', child: Text('Field Store', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _TransferCard(
            step: 2,
            title: 'Item & Quantity',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  hint: const Text('Select item to transfer', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                  decoration: _dropdownDecoration(Icons.inventory_2_outlined, AppTheme.warning),
                  items: const [
                    DropdownMenuItem(value: 'diesel', child: Text('Diesel', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'oil', child: Text('Engine Oil', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(height: 10),
                const AppFormField(label: 'Quantity to transfer', icon: Icons.numbers, keyboardType: TextInputType.number),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _TransferCard(
            step: 3,
            title: 'Initiate Transfer',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: AppTheme.warning, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stock is immediately deducted from source when transfer is initiated.',
                      style: TextStyle(fontSize: 12, color: AppTheme.warning, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _TransferCard(
            step: 4,
            title: 'Receiver Acknowledgment',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The destination stock point receives a pop-up notification to confirm receipt.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatusBubble(
                        label: 'Received',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.success,
                        selected: _transferStatus == 'Received',
                        onTap: () => setState(() => _transferStatus = 'Received'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusBubble(
                        label: 'Pending',
                        icon: Icons.hourglass_empty_outlined,
                        color: AppTheme.warning,
                        selected: _transferStatus == 'Pending',
                        onTap: () => setState(() => _transferStatus = 'Pending'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const NoteBox(
            title: 'Two-way confirmation',
            content: 'The transfer flow is a handshake — supervisor initiates, receiver confirms. Both sides must act for stock counts to update on both ends.',
          ),
          const SizedBox(height: 20),
          const SubmitButton(label: 'Initiate Transfer', color: AppTheme.info),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(IconData icon, Color color) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 18, color: color),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border, width: 0.8)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.border, width: 0.8)),
      filled: true, fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}

class _StatusBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusBubble({required this.label, required this.icon, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : AppTheme.textMuted, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final int step;
  final String title;
  final Widget child;

  const _TransferCard({required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppTheme.infoBg, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Text('$step', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.info)),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── RENTAL ──────────────────────────────────────────────────────────────────
class RentalScreen extends StatefulWidget {
  const RentalScreen({super.key});

  @override
  State<RentalScreen> createState() => _RentalScreenState();
}

class _RentalScreenState extends State<RentalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _billingMode = 'Per day';

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
    return Column(
      children: [
        Container(
          color: AppTheme.surfaceCard,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              const ModuleHeader(
                title: 'Rental',
                subtitle: 'Track rented equipment from check-in to check-out',
                emoji: '🔑',
                color: AppTheme.danger,
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 2,
                tabs: const [Tab(text: 'Open Rental'), Tab(text: 'Close Rental')],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Open Rental
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppTheme.dangerBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.danger.withOpacity(0.25))),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high, color: AppTheme.danger, size: 18),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Auto-generated Rental ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.danger)),
                              const Text('RNT-2024-0034', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.danger)),
                              const SizedBox(height: 4),
                              const HodApprovalBadge(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _RentalCard(
                      step: 2,
                      title: 'Item & Check-in Date',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppFormField(label: 'Item name', hint: 'Rented equipment name', icon: Icons.build_outlined),
                          const SizedBox(height: 10),
                          const AppFormField(label: 'Check-in date', icon: Icons.calendar_today_outlined, readOnly: true),
                          const SizedBox(height: 10),
                          const Text('Billing mode', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Row(
                            children: ['Per day', 'Per hour'].map((m) {
                              final bool sel = _billingMode == m;
                              return GestureDetector(
                                onTap: () => setState(() => _billingMode = m),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? AppTheme.danger : AppTheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: sel ? AppTheme.danger : AppTheme.border),
                                  ),
                                  child: Text(m, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _RentalCard(
                      step: 3,
                      title: 'Rate & Fuel',
                      child: Column(
                        children: [
                          AppFormField(label: 'Rate per ${_billingMode == 'Per day' ? 'day' : 'hour'} (₹)', icon: Icons.currency_rupee, keyboardType: TextInputType.number),
                          const SizedBox(height: 10),
                          const AppFormField(label: 'Fuel consumed (running total)', hint: 'Diesel/petrol as ₹ amount', icon: Icons.local_gas_station_outlined, keyboardType: TextInputType.number),
                          const SizedBox(height: 10),
                          const AppFormField(label: 'Notes', hint: 'Conditions, remarks, observations', icon: Icons.notes_outlined, maxLines: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SubmitButton(label: 'Open Rental Record', color: AppTheme.danger),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Close Rental + Summary
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RentalCard(
                      step: 6,
                      title: 'Close Rental',
                      child: Column(
                        children: [
                          const AppFormField(label: 'Rental ID', hint: 'Enter or scan rental ID', icon: Icons.tag),
                          const SizedBox(height: 10),
                          const AppFormField(label: 'Closing date', icon: Icons.event_available_outlined, readOnly: true),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.infoBg, borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.calculate_outlined, color: AppTheme.info, size: 16),
                                SizedBox(width: 6),
                                Text('Total auto-calculated from rate × duration', style: TextStyle(fontSize: 11.5, color: AppTheme.info)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Rental Summary View', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),
                    InfoCardGrid(cards: [
                      InfoCardData('Rental ID & item name', 'Identification'),
                      InfoCardData('In date / Out date', 'Rental period'),
                      InfoCardData('Earned amount', 'Total billed'),
                      InfoCardData('Used amount', 'Expenses paid out'),
                      InfoCardData('Remaining amount', 'Balance to collect'),
                      InfoCardData('Account numbers', 'Managed by HOD'),
                    ]),
                    const SizedBox(height: 20),
                    const SubmitButton(label: 'Close Rental Record', color: AppTheme.success),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RentalCard extends StatelessWidget {
  final int step;
  final String title;
  final Widget child;

  const _RentalCard({required this.step, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(color: AppTheme.dangerBg, borderRadius: BorderRadius.circular(6)),
                alignment: Alignment.center,
                child: Text('$step', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.danger)),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── TASKS ───────────────────────────────────────────────────────────────────
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'All';

  final List<_TaskItem> _tasks = [
    _TaskItem('Check diesel levels at Site A', 'Daily', false, 'High'),
    _TaskItem('Update machine log for MCH-003', 'Daily', true, 'Normal'),
    _TaskItem('Verify operator attendance photos', 'Daily', false, 'High'),
    _TaskItem('Submit weekly stock summary', 'Weekly', false, 'Normal'),
    _TaskItem('Calibrate equipment at Site B', 'Weekly', true, 'High'),
    _TaskItem('Review rental records', 'Monthly', false, 'Normal'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All' ? _tasks : _tasks.where((t) => t.type == _filter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ModuleHeader(
            title: 'Tasks & Checklist',
            subtitle: 'HOD-assigned tasks — complete and track progress',
            emoji: '✅',
            color: AppTheme.success,
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _TaskStat(label: 'Total', value: '${_tasks.length}', color: AppTheme.primary),
              const SizedBox(width: 8),
              _TaskStat(label: 'Done', value: '${_tasks.where((t) => t.done).length}', color: AppTheme.success),
              const SizedBox(width: 8),
              _TaskStat(label: 'Pending', value: '${_tasks.where((t) => !t.done).length}', color: AppTheme.warning),
            ],
          ),
          const SizedBox(height: 16),

          // Filter chips
          Row(
            children: ['All', 'Daily', 'Weekly', 'Monthly'].map((f) {
              final bool sel = _filter == f;
              return GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Task list
          ...filtered.map((task) => _TaskTile(
            task: task,
            onToggle: () => setState(() => task.done = !task.done),
          )),

          const SizedBox(height: 16),
          const NoteBox(
            title: 'Performance tracking',
            content: 'Task completion feeds into HOD-visible supervisor performance report automatically. The map & specifications module also tracks compliance.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _TaskItem {
  final String title, type, priority;
  bool done;
  _TaskItem(this.title, this.type, this.done, this.priority);
}

class _TaskTile extends StatelessWidget {
  final _TaskItem task;
  final VoidCallback onToggle;

  const _TaskTile({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: task.done ? AppTheme.success.withOpacity(0.3) : AppTheme.border, width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: task.done ? AppTheme.success : AppTheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: task.done ? AppTheme.success : AppTheme.border, width: task.done ? 0 : 1.5),
            ),
            child: task.done ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: task.done ? AppTheme.textMuted : AppTheme.textPrimary,
            decoration: task.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            _TypeBadge(type: task.type),
            const SizedBox(width: 6),
            if (task.priority == 'High')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.dangerBg, borderRadius: BorderRadius.circular(4)),
                child: const Text('High', style: TextStyle(fontSize: 10, color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    Color c = type == 'Daily' ? AppTheme.info : type == 'Weekly' ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(type, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _TaskStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TaskStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── REPORTS ─────────────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedReport = '';
  String _selectedPeriod = 'Monthly';

  static const List<_ReportType> _reportTypes = [
    _ReportType('📊', 'Machines summary', 'Machine ID · Operator · Hour/Day rate · Earned · Used · Diesel · Balance'),
    _ReportType('👷', 'Workers', 'ID · Name · Earned amount · Used amount · Remaining balance'),
    _ReportType('🔑', 'Rental', 'ID · Item name · Start/End date · Working days · Earned · Used · Remaining'),
    _ReportType('⛽', 'Diesel', 'Batch ID · Total in · Amount · Consumed (liters) · Amount · Remaining diesel'),
    _ReportType('↩️', 'Returns', 'Batch ID · Machine name · Start/End date · Working days · Earned · Used · Remaining'),
    _ReportType('🏍️', 'Site bikes petrol', 'Bike ID · Petrol consumption note'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ModuleHeader(
            title: 'Reports',
            subtitle: 'Auto-generated summaries across all modules',
            emoji: '📊',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 20),

          // Step 1 — Report type
          const SectionHeader(title: 'Step 1 — Select report type'),
          Column(
            children: _reportTypes.map((r) {
              final bool sel = _selectedReport == r.title;
              return GestureDetector(
                onTap: () => setState(() => _selectedReport = r.title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primary : AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? AppTheme.primary : AppTheme.border, width: sel ? 1.5 : 0.8),
                  ),
                  child: Row(
                    children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppTheme.textPrimary)),
                            const SizedBox(height: 3),
                            Text(r.fields, style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? Colors.white : AppTheme.textMuted, size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Step 2 — Filters
          const SectionHeader(title: 'Step 2 — Apply filters'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: const AppFormField(label: 'Start date', icon: Icons.date_range_outlined, readOnly: true)),
                    const SizedBox(width: 8),
                    Expanded(child: const AppFormField(label: 'End date', icon: Icons.date_range_outlined, readOnly: true)),
                  ],
                ),
                const SizedBox(height: 10),
                const AppFormField(label: 'Name / ID', hint: 'Filter by name or ID', icon: Icons.search),
                const SizedBox(height: 10),
                const AppFormField(label: 'Stock point', hint: 'Filter by location', icon: Icons.location_on_outlined),
                const SizedBox(height: 12),
                Row(
                  children: ['Daily', 'Weekly', 'Monthly'].map((p) {
                    final bool sel = _selectedPeriod == p;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
                        ),
                        child: Text(p, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.textSecondary)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Step 3 — Generate
          const SectionHeader(title: 'Step 3 — Generate report'),
          SubmitButton(
            label: _selectedReport.isEmpty ? 'Select a report type first' : 'Generate $_selectedReport Report',
            color: _selectedReport.isEmpty ? AppTheme.textMuted : AppTheme.primary,
            onTap: _selectedReport.isEmpty ? null : () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generating $_selectedReport report...'), backgroundColor: AppTheme.primary),
              );
            },
          ),

          const SizedBox(height: 16),
          const NoteBox(
            title: 'Tip',
            content: 'Reports here reflect the same data as category-specific summaries inside each module. Use filters to generate period-specific or person-specific reports for review.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ReportType {
  final String emoji, title, fields;
  const _ReportType(this.emoji, this.title, this.fields);
}
