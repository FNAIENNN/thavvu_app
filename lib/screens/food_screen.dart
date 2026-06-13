import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Models for data integration
class WorkerFood {
  final String id;
  final String name;
  final String status; // 'active' or 'inactive'
  WorkerFood({required this.id, required this.name, required this.status});
}

class MachineWorkerGroup {
  final String machineId;
  final String machineName;
  final int workerCount;
  MachineWorkerGroup({required this.machineId, required this.machineName, required this.workerCount});
}

class OutsideWorkerFood {
  final String id;
  final String name;
  final String status; // 'Present', 'Absent', 'Half day', 'Leave'
  OutsideWorkerFood({required this.id, required this.name, required this.status});
}

class FoodScreen extends StatefulWidget {
  final List<WorkerFood> activeInactiveWorkers;
  final List<MachineWorkerGroup> machineWorkerGroups;
  final int outsideWorkerCount;
  final List<OutsideWorkerFood> outsideWorkers;

  const FoodScreen({
    super.key,
    this.activeInactiveWorkers = const [],
    this.machineWorkerGroups = const [],
    this.outsideWorkerCount = 0,
    this.outsideWorkers = const [],
  });

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  // Shift selection
  final Set<String> _selectedShifts = {'Morning', 'Afternoon', 'Evening'};
  final List<String> _shifts = ['Morning', 'Afternoon', 'Evening'];

  // Food attendance list (from active+inactive workers)
  late List<Map<String, dynamic>> _foodAttendance;

  // Machine workers list
  late List<Map<String, dynamic>> _machineWorkers;

  // Outside workers list
  late List<Map<String, dynamic>> _outsideWorkers;

  // Workers on leave (no food)
  late List<Map<String, dynamic>> _workersOnLeave;

  // Guests list
  final List<Map<String, dynamic>> _guests = [];
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestCountController = TextEditingController();

  // Others list
  final List<Map<String, dynamic>> _others = [];
  final TextEditingController _otherNameController = TextEditingController();
  final TextEditingController _otherCountController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Initialize food attendance from active/inactive workers
    _foodAttendance = (widget.activeInactiveWorkers ?? []).map((worker) {
      return {
        'id': worker.id,
        'name': worker.name,
        'status': worker.status,
        'foodStatus': 'yes',
      };
    }).toList();

    // Initialize outside workers (only those with status 'Present' are eligible for food, but we show all with toggles)
    _outsideWorkers = (widget.outsideWorkers ?? []).map((worker) {
      return {
        'id': worker.id,
        'name': worker.name,
        'status': worker.status,
        'foodStatus': worker.status == 'Present' ? 'yes' : 'no',
      };
    }).toList();

    // Workers on leave are not included in activeInactiveWorkers; they are separate but we don't have a list here.
    // For simplicity, we assume no regular workers on leave are passed. We'll just leave it empty.

    // Initialize machine workers
    _machineWorkers = (widget.machineWorkerGroups ?? []).map((group) {
      return {
        'id': group.machineId,
        'name': group.machineName,
        'people': group.workerCount,
        'foodStatus': 'yes',
      };
    }).toList();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _guestCountController.dispose();
    _otherNameController.dispose();
    _otherCountController.dispose();
    super.dispose();
  }

  void _addGuest() {
    if (_guestNameController.text.isEmpty || _guestCountController.text.isEmpty) {
      _showSnackbar('Please fill all fields', AppTheme.danger);
      return;
    }
    final count = int.tryParse(_guestCountController.text);
    if (count == null || count <= 0) {
      _showSnackbar('Please enter a valid count', AppTheme.danger);
      return;
    }
    setState(() {
      _guests.add({
        'name': _guestNameController.text,
        'count': count,
        'foodStatus': 'yes',
      });
      _guestNameController.clear();
      _guestCountController.clear();
    });
    _showSnackbar('Guest added', AppTheme.success);
  }

  void _addOther() {
    if (_otherNameController.text.isEmpty || _otherCountController.text.isEmpty) {
      _showSnackbar('Please fill all fields', AppTheme.danger);
      return;
    }
    final count = int.tryParse(_otherCountController.text);
    if (count == null || count <= 0) {
      _showSnackbar('Please enter a valid count', AppTheme.danger);
      return;
    }
    setState(() {
      _others.add({
        'name': _otherNameController.text,
        'count': count,
        'foodStatus': 'yes',
      });
      _otherNameController.clear();
      _otherCountController.clear();
    });
    _showSnackbar('Item added', AppTheme.success);
  }

  void _submitFoodList() {
    if (_selectedShifts.isEmpty) {
      _showSnackbar('Please select at least one shift', AppTheme.warning);
      return;
    }
    setState(() => _isSubmitting = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final total = _calculateTotal();
        _showSnackbar(
          'Food list submitted for ${_selectedShifts.join(", ")} shift(s). Total people: $total',
          AppTheme.success,
        );
      }
    });
  }

  int _calculateTotal() {
    int total = 0;
    for (var item in _foodAttendance) {
      if (item['foodStatus'] == 'yes') total++;
    }
    for (var item in _machineWorkers) {
      if (item['foodStatus'] == 'yes') total += item['people'] as int;
    }
    for (var item in _outsideWorkers) {
      if (item['foodStatus'] == 'yes') total++;
    }
    for (var item in _guests) {
      if (item['foodStatus'] == 'yes') total += item['count'] as int;
    }
    for (var item in _others) {
      if (item['foodStatus'] == 'yes') total += item['count'] as int;
    }
    return total;
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
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Food Management'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildShiftSelector(),
            const SizedBox(height: 20),
            _buildSection('Food Attendance (Active & Inactive Workers)', _buildFoodAttendanceList(), AppTheme.success),
            const SizedBox(height: 20),
            if (_outsideWorkers.isNotEmpty)
              _buildSection('Outside Workers', _buildOutsideWorkersList(), AppTheme.primary),
            const SizedBox(height: 20),
            _buildSection('Machine Workers', _buildMachineWorkersList(), AppTheme.info),
            const SizedBox(height: 20),
            _buildSection('Guests (Optional)', _buildGuestsSection(), AppTheme.warning),
            const SizedBox(height: 20),
            _buildSection('Others (Optional)', _buildOthersSection(), AppTheme.accent),
            const SizedBox(height: 20),
            _buildTotalFoodCard(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSelector() {
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
          const Text('Select Shifts for Food', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: _shifts.map((shift) {
              final isSelected = _selectedShifts.contains(shift);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedShifts.remove(shift);
                    } else {
                      _selectedShifts.add(shift);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(
                    shift,
                    style: TextStyle(
                      fontSize: 13,
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

  Widget _buildSection(String title, Widget content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildFoodAttendanceList() {
    if (_foodAttendance.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text('No active or inactive workers found.'),
      );
    }
    return Column(
      children: _foodAttendance.map((item) => _buildEditableItem(
        title: item['name'],
        subtitle: item['id'],
        status: item['foodStatus'],
        onToggle: () => setState(() {
          item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
        }),
      )).toList(),
    );
  }

  Widget _buildOutsideWorkersList() {
    return Column(
      children: _outsideWorkers.map((item) => _buildEditableItem(
        title: item['name'],
        subtitle: item['id'],
        status: item['foodStatus'],
        onToggle: () => setState(() {
          item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
        }),
      )).toList(),
    );
  }

  Widget _buildMachineWorkersList() {
    if (_machineWorkers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        child: const Text('No machine worker data available.'),
      );
    }
    return Column(
      children: _machineWorkers.map((item) => _buildEditableItem(
        title: item['name'],
        subtitle: '${item['people']} people',
        status: item['foodStatus'],
        onToggle: () => setState(() {
          item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
        }),
      )).toList(),
    );
  }

  Widget _buildEditableItem({
    required String title,
    required String subtitle,
    required String status,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'yes' ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status == 'yes' ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestsSection() {
    return Column(
      children: [
        if (_guests.isNotEmpty) ...[
          ..._guests.asMap().entries.map((entry) {
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${item['count']} people', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: item['foodStatus'] == 'yes' ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['foodStatus'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item['foodStatus'] == 'yes' ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _guests.removeAt(entry.key)),
                    child: const Icon(Icons.close, color: AppTheme.danger, size: 20),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _guestNameController,
                decoration: const InputDecoration(hintText: 'Guest name', border: InputBorder.none),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _guestCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Count', border: InputBorder.none),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addGuest,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOthersSection() {
    return Column(
      children: [
        if (_others.isNotEmpty) ...[
          ..._others.asMap().entries.map((entry) {
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('${item['count']} count', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: item['foodStatus'] == 'yes' ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['foodStatus'].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item['foodStatus'] == 'yes' ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _others.removeAt(entry.key)),
                    child: const Icon(Icons.close, color: AppTheme.danger, size: 20),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _otherNameController,
                decoration: const InputDecoration(hintText: 'Item name', border: InputBorder.none),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otherCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Count', border: InputBorder.none),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addOther,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                    child: const Text('Add', style: TextStyle(fontSize: 12, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalFoodCard() {
    final total = _calculateTotal();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total People for Food', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Text(total.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.success)),
            ],
          ),
          Icon(Icons.restaurant, size: 48, color: AppTheme.success.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: const Text('🍽️', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Food Management', style: TextStyle(fontSize: 13, color: Colors.white70)),
                    SizedBox(height: 4),
                    Text('Prepare Food List', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Select shifts, confirm attendance, then send to admin & canteen.',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitFoodList,
        icon: _isSubmitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.send),
        label: Text(_isSubmitting ? 'Submitting...' : 'Send to Admin & Canteen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}