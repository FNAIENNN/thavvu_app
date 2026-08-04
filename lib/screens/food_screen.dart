import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../models/machine_worker_group.dart';
import '../models/food_models.dart';
import '../services/food_repository.dart';
import '../services/attendance_context_service.dart';
import '../services/realtime_service.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import 'hod_module_review_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FOOD MODULE MODELS
// ══════════════════════════════════════════════════════════════════════════════

class WorkerFood {
  final String id;
  final String name;
  final String status;

  const WorkerFood({
    required this.id,
    required this.name,
    required this.status,
  });
}

class OutsideWorkerBatch {
  final String id;
  final String name;
  final int totalWorkers;

  const OutsideWorkerBatch({
    required this.id,
    required this.name,
    required this.totalWorkers,
  });
}

class OutsideWorkerFood {
  final String id;
  final String name;
  final String status;

  const OutsideWorkerFood({
    required this.id,
    required this.name,
    required this.status,
  });
}

enum FoodEntryType { regularWorker, outsideWorker, machineWorker, guest, other }

extension FoodEntryTypeX on FoodEntryType {
  String get label {
    switch (this) {
      case FoodEntryType.regularWorker:
        return 'Regular Worker';
      case FoodEntryType.outsideWorker:
        return 'Outside Worker';
      case FoodEntryType.machineWorker:
        return 'Machine Worker';
      case FoodEntryType.guest:
        return 'Guest';
      case FoodEntryType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case FoodEntryType.regularWorker:
        return Icons.badge_outlined;
      case FoodEntryType.outsideWorker:
        return Icons.groups_2_outlined;
      case FoodEntryType.machineWorker:
        return Icons.precision_manufacturing_outlined;
      case FoodEntryType.guest:
        return Icons.person_add_alt_1_outlined;
      case FoodEntryType.other:
        return Icons.category_outlined;
    }
  }
}

class FoodSubmissionRecord {
  final String id;
  final DateTime submittedAt;
  final Set<String> shifts;
  final int regularWorkerCount;
  final int outsideWorkerCount;
  final int machineWorkerPeopleCount;
  final int guestCount;
  final int otherCount;
  final String remarks;
  final List<Map<String, dynamic>> payload;
  final String status;

  const FoodSubmissionRecord({
    required this.id,
    required this.submittedAt,
    required this.shifts,
    required this.regularWorkerCount,
    required this.outsideWorkerCount,
    required this.machineWorkerPeopleCount,
    required this.guestCount,
    required this.otherCount,
    required this.payload,
    this.remarks = '',
    this.status = 'Submitted',
  });

  int get totalPeople =>
      regularWorkerCount +
      outsideWorkerCount +
      machineWorkerPeopleCount +
      guestCount +
      otherCount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'submittedAt': submittedAt.toIso8601String(),
      'shifts': shifts.toList(),
      'regularWorkerCount': regularWorkerCount,
      'outsideWorkerCount': outsideWorkerCount,
      'machineWorkerPeopleCount': machineWorkerPeopleCount,
      'guestCount': guestCount,
      'otherCount': otherCount,
      'totalPeople': totalPeople,
      'remarks': remarks,
      'status': status,
      'payload': payload,
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class FoodScreen extends StatefulWidget {
  final bool isHOD;
  final List<WorkerFood> activeInactiveWorkers;
  final List<MachineWorkerGroup> machineWorkerGroups;
  final List<OutsideWorkerBatch> outsideWorkerBatches;
  final int outsideWorkerCount;
  final List<OutsideWorkerFood> outsideWorkers;

  const FoodScreen({
    super.key,
    this.isHOD = false,
    this.activeInactiveWorkers = const [],
    this.machineWorkerGroups = const [],
    this.outsideWorkerBatches = const [],
    this.outsideWorkerCount = 0,
    this.outsideWorkers = const [],
  });

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late final TabController _subTabController;

  final Set<String> _selectedShifts = {'Morning', 'Afternoon', 'Evening'};

  // Backend-fed lists default to empty so a failed/hung load can never
  // crash the screen with a LateInitializationError.
  List<Map<String, dynamic>> _foodAttendance = [];
  List<Map<String, dynamic>> _machineWorkers = [];

  List<OutsideWorkerBatch> _outsideBatches = [];
  Map<String, int> _outsideBatchCounts = {};
  Map<String, TextEditingController> _outsideBatchControllers = {};
  Map<String, TextEditingController> _outsideBatchExtraControllers = {};

  final List<Map<String, dynamic>> _guests = [];
  final TextEditingController _guestNameController = TextEditingController();

  final List<Map<String, dynamic>> _others = [];
  final TextEditingController _otherController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _finalRemarksController = TextEditingController();

  bool _isSubmitting = false;

  final List<FoodSubmissionRecord> _submissionHistory = [];

  // Backend (Supabase) integration — food module reads `food_requests`
  // written by the attendance module and submits daily counts.
  final FoodRepository _foodRepo = FoodRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  String? _siteId;
  List<FoodRequest> _loadedRequests = [];

  // Realtime subscription — refreshes when attendance writes food_requests
  // or another device submits food counts.
  FoodRealtimeSubscription? _realtimeSub;
  final RealtimeDebouncer _realtimeDebouncer = RealtimeDebouncer();

  int _currentSession = 0;
  int _currentStage = -1;
  int _receivedRegular = 0;
  int _receivedOutside = 0;
  int _receivedGuestsOthers = 0;
  List<Map<String, dynamic>> _savedSessions = [];

  final List<String> _sessionNames = ['Morning', 'Afternoon', 'Night'];
  final List<String> _sessionIcons = ['☀️', '🌤️', '🌙'];
  final List<String> _sessionMeals = ['Tiffins', 'Lunch', 'Dinner'];

  int _orderedRegular = 0;
  int _orderedOutside = 0;
  int _orderedGuestsOthers = 0;
  int _orderedTotal = 0;

  bool _isReceived = false;

  String _currentOrderId = '';
  String _currentDate = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _subTabController = TabController(length: 3, vsync: this);
    _loadFoodDataFromBackend();
    _loadLatestOrderData();
    _checkAndUpdateSession();
    _setupStatusListener();
    _checkForNewDay();
  }

  void _checkForNewDay() {
    final today = _formatDate(DateTime.now());
    
    if (_currentDate.isEmpty) {
      _currentDate = today;
      return;
    }

    if (_currentDate != today) {
      _resetForNewDay();
      _currentDate = today;
    }
  }

  void _resetForNewDay() {
    setState(() {
      _orderedRegular = 0;
      _orderedOutside = 0;
      _orderedGuestsOthers = 0;
      _orderedTotal = 0;
      _receivedRegular = 0;
      _receivedOutside = 0;
      _receivedGuestsOthers = 0;
      _resetStage();
      _savedSessions.clear();
      _currentSession = 0;
      _currentOrderId = '';
      _isReceived = false;
    });
    
    _showSnackbar('📅 New Day Started! Everything reset.', AppTheme.info);
  }

  void _setupStatusListener() {
    debugPrint('✅ Status listener ready for API integration');
  }

  void _onOrderPlaced() {
    setState(() {
      _currentStage = 0;
    });
    _showSnackbar('✅ Order Placed!', Colors.orange);
  }

  void _onCanteenReceived() {
    setState(() {
      _currentStage = 1;
      _receivedRegular = _orderedRegular;
      _receivedOutside = _orderedOutside;
      _receivedGuestsOthers = _orderedGuestsOthers;
    });
    _showSnackbar('✅ Canteen Received Order!', Colors.green);
  }

  void _onDispatched() {
    setState(() {
      _currentStage = 2;
    });
    _showSnackbar('✅ Food Dispatched!', Colors.blue);
  }


  Future<void> _sendOrderToCanteen(FoodSubmissionRecord record) async {
    try {
      _currentOrderId = record.id;

      setState(() {
        _orderedRegular = record.regularWorkerCount;
        _orderedOutside = record.outsideWorkerCount + record.machineWorkerPeopleCount;
        _orderedGuestsOthers = record.guestCount + record.otherCount;
        _orderedTotal = record.totalPeople;
        _receivedRegular = 0;
        _receivedOutside = 0;
        _receivedGuestsOthers = 0;
      });

      _onOrderPlaced();

      _showSnackbar('✅ Order sent to Canteen!', Colors.orange);
    } catch (e) {
      _showSnackbar('❌ Failed to send order: $e', AppTheme.danger);
    }
  }

  void _saveSession() {
    if (_currentStage < 2) {
      _showSnackbar('⚠️ Please wait for dispatch!', AppTheme.warning);
      return;
    }

    setState(() {
      _currentStage = 3;
      _isReceived = true;
    });

    final sessionData = {
      'session': _sessionNames[_currentSession],
      'icon': _sessionIcons[_currentSession],
      'meal': _sessionMeals[_currentSession],
      'time': _getCurrentTime(),
      'orderedRegular': _orderedRegular,
      'orderedOutside': _orderedOutside,
      'orderedGuestsOthers': _orderedGuestsOthers,
      'orderedTotal': _orderedTotal,
      'receivedRegular': _receivedRegular,
      'receivedOutside': _receivedOutside,
      'receivedGuestsOthers': _receivedGuestsOthers,
      'balanceRegular': _balanceRegular,
      'balanceOutside': _balanceOutside,
      'balanceGuestsOthers': _balanceGuestsOthers,
      'balanceTotal': _balanceTotal,
      'date': _formatDate(DateTime.now()),
      'timestamp': DateTime.now().toString(),
      'sessionIndex': _currentSession,
    };

    setState(() {
      _savedSessions.removeWhere((s) => s['date'] != _formatDate(DateTime.now()));
      _savedSessions.add(sessionData);
      _savedSessions.sort((a, b) => (a['sessionIndex'] ?? 0).compareTo(b['sessionIndex'] ?? 0));
    });

    _showSnackbar(
      '✅ ${_sessionNames[_currentSession]} session saved!',
      AppTheme.success,
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final nextSession = (_currentSession + 1) % 3;
        setState(() {
          _currentSession = nextSession;
          _resetStage();
          _orderedRegular = 0;
          _orderedOutside = 0;
          _orderedGuestsOthers = 0;
          _orderedTotal = 0;
          _receivedRegular = 0;
          _receivedOutside = 0;
          _receivedGuestsOthers = 0;
          _currentOrderId = '';
        });
        
        if (nextSession == 0) {
          _showSnackbar('🎉 All sessions complete for today!', AppTheme.success);
        } else {
          _showSnackbar(
            '🔄 ${_sessionNames[nextSession]} session started!',
            AppTheme.info,
          );
        }
      }
    });
  }

  void _resetStage() {
    _currentStage = -1;
    _isReceived = false;
  }

  void _checkAndUpdateSession() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      _currentSession = 0;
    } else if (hour >= 12 && hour < 18) {
      _currentSession = 1;
    } else {
      _currentSession = 2;
    }
    _resetStage();
    _currentDate = _formatDate(DateTime.now());
  }

  void _loadLatestOrderData() {
    _orderedRegular = 0;
    _orderedOutside = 0;
    _orderedGuestsOthers = 0;
    _orderedTotal = 0;
    _receivedRegular = 0;
    _receivedOutside = 0;
    _receivedGuestsOthers = 0;
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text('${session['icon']} ${session['session']} Session Details'),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${session['date']}  •  ${session['time']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Received',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Regular', session['orderedRegular'], session['receivedRegular'], session['balanceRegular']),
                      _buildDetailRow('Outside', session['orderedOutside'], session['receivedOutside'], session['balanceOutside']),
                      _buildDetailRow('Guests & Others', session['orderedGuestsOthers'], session['receivedGuestsOthers'], session['balanceGuestsOthers']),
                      Container(
                        height: 1,
                        color: AppTheme.border,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      _buildDetailRow('Total', session['orderedTotal'], 
                          session['receivedRegular'] + session['receivedOutside'] + session['receivedGuestsOthers'],
                          session['balanceTotal'], isTotal: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, int ordered, int received, int balance, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              ordered.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              received.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              balance >= 0 ? '+$balance' : balance.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
                color: balance >= 0 ? AppTheme.success : AppTheme.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Load today's food requests from Supabase.
  ///
  /// `food_requests` rows are written by the attendance module (who needs
  /// food). This screen consumes them: regular workers appear as attendees,
  /// outside workers as batches, machine/guest/other stay manual entries.
  Future<void> _loadFoodDataFromBackend() async {
    try {
      _siteId = await _contextService.resolveSiteId();
      final requests = await _foodRepo.fetchPendingRequests(
        DateTime.now(),
        siteId: _siteId,
      );
      _loadedRequests = requests;
      _foodAttendance = requests
          .where((r) => r.category == 'regular')
          .map((r) => {
                'id': r.workerId ?? r.id ?? r.name,
                'name': r.name,
                'status': 'Active',
                'foodStatus': 'yes',
                'type': FoodEntryType.regularWorker.label,
              })
          .toList();

      _machineWorkers = requests
          .where((r) => r.category == 'machine')
          .map((r) => {
                'id': r.id ?? r.name,
                'name': r.name,
                'people': 1,
                'status': 'Machine Group',
                'foodStatus': 'yes',
                'type': FoodEntryType.machineWorker.label,
              })
          .toList();

      _outsideBatches = requests
          .where((r) => r.category == 'outside')
          .map((r) => OutsideWorkerBatch(
                id: r.id ?? r.batchWorkerId ?? r.name,
                name: r.name,
                totalWorkers: 1,
              ))
          .toList();

      _outsideBatchCounts = {
        for (var batch in _outsideBatches) batch.id: 1
      };
      _outsideBatchControllers = {
        for (var batch in _outsideBatches)
          batch.id: TextEditingController(text: '1')
      };
      _outsideBatchExtraControllers = {
        for (var batch in _outsideBatches) batch.id: TextEditingController()
      };
    } catch (e) {
      // A failed backend load must never crash the screen — keep the
      // empty defaults and surface a non-blocking notice instead.
      debugPrint('Error loading food data from backend: $e');
      if (!mounted) return;
      _showSnackbar(
          'Could not load food requests from server. Showing manual entry.',
          AppTheme.warning);
      return;
    }

    // Start realtime subscription (siteId resolved) so food_requests
    // written by attendance (or another device) refresh automatically.
    _realtimeSub?.cancel();
    _realtimeSub = RealtimeService.subscribeFood(
      siteId: _siteId,
      onAnyChange: () {
        _realtimeDebouncer.call(() {
          if (mounted) _loadFoodDataFromBackend();
        });
      },
    );

    if (!mounted) return;
    setState(() {});
  }


  @override
  void dispose() {
    _realtimeSub?.cancel();
    _tabController.dispose();
    _subTabController.dispose();
    _guestNameController.dispose();
    _otherController.dispose();
    _searchController.dispose();
    _finalRemarksController.dispose();
    for (final controller in _outsideBatchControllers.values) {
      controller.dispose();
    }
    for (final controller in _outsideBatchExtraControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _regularFoodCount =>
      _foodAttendance.where((item) => item['foodStatus'] == 'yes').length;

  int get _outsideFoodCount {
    return _outsideBatchCounts.values.fold(0, (sum, count) => sum + count);
  }

  int get _machineFoodCount {
    return _machineWorkers.fold<int>(0, (sum, item) {
      if (item['foodStatus'] != 'yes') return sum;
      return sum + ((item['people'] as int?) ?? 0);
    });
  }

  int get _guestFoodCount {
    return _guests.fold<int>(0, (sum, item) {
      if (item['foodStatus'] != 'yes') return sum;
      return sum + 1;
    });
  }

  int get _otherFoodCount {
    return _others.fold<int>(0, (sum, item) {
      if (item['foodStatus'] != 'yes') return sum;
      return sum + 1;
    });
  }

  int get _balanceRegular => _receivedRegular - _orderedRegular;
  int get _balanceOutside => _receivedOutside - _orderedOutside;
  int get _balanceGuestsOthers => _receivedGuestsOthers - _orderedGuestsOthers;
  int get _balanceTotal => (_receivedRegular + _receivedOutside + _receivedGuestsOthers) - _orderedTotal;

  int intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  int _calculateTotal() {
    return _regularFoodCount +
        _outsideFoodCount +
        _machineFoodCount +
        _guestFoodCount +
        _otherFoodCount;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $ampm';
  }

  String _getCurrentTime() {
    return _formatTime(DateTime.now());
  }

  void _addGuest() {
    final name = _guestNameController.text.trim();
    if (name.isEmpty) {
      _showSnackbar('Please enter guest name', AppTheme.danger);
      return;
    }
    setState(() {
      _guests.add({
        'id': 'GST-${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'status': 'Guest',
        'foodStatus': 'yes',
        'type': FoodEntryType.guest.label,
      });
      _guestNameController.clear();
    });
    _showSnackbar('Guest added successfully', AppTheme.success);
  }

  void _addOther() {
    final name = _otherController.text.trim();
    if (name.isEmpty) {
      _showSnackbar('Please enter other item name', AppTheme.danger);
      return;
    }
    setState(() {
      _others.add({
        'id': 'OTH-${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'count': 1,
        'status': 'Other',
        'foodStatus': 'yes',
        'type': FoodEntryType.other.label,
      });
      _otherController.clear();
    });
    _showSnackbar('Other item added successfully', AppTheme.success);
  }

  void _toggleEntry(Map<String, dynamic> item) {
    setState(() {
      item['foodStatus'] = item['foodStatus'] == 'yes' ? 'no' : 'yes';
    });
  }

  void _markAll(List<Map<String, dynamic>> list, String status) {
    setState(() {
      for (final item in list) {
        item['foodStatus'] = status;
      }
    });
  }

  void _removeGuest(int index) {
    setState(() => _guests.removeAt(index));
    _showSnackbar('Guest removed', AppTheme.warning);
  }

  void _removeOther(int index) {
    setState(() => _others.removeAt(index));
    _showSnackbar('Item removed', AppTheme.warning);
  }

  void _updateOutsideCount(String batchId, int newCount) {
    final batch = _outsideBatches.firstWhere((b) => b.id == batchId);
    final clamped = newCount.clamp(0, batch.totalWorkers);
    setState(() {
      _outsideBatchCounts[batchId] = clamped;
    });
    final controller = _outsideBatchControllers[batchId];
    if (controller != null && controller.text != clamped.toString()) {
      controller.value = TextEditingValue(
        text: clamped.toString(),
        selection: TextSelection.collapsed(offset: clamped.toString().length),
      );
    }
  }

  Future<void> _submitFoodList() async {
    if (_selectedShifts.isEmpty) {
      _showSnackbar('Please select at least one shift', AppTheme.warning);
      return;
    }

    final totalPeople = _calculateTotal();
    if (totalPeople <= 0) {
      _showSnackbar('No people selected for food', AppTheme.danger);
      return;
    }

    setState(() => _isSubmitting = true);

    if (_siteId == null) {
      _siteId = await _contextService.resolveSiteId();
    }

    final submission = FoodSubmission(
      siteId: _siteId,
      attendanceDate: DateTime.now(),
      shifts: _selectedShifts.toList(),
      regularWorkerCount: _regularFoodCount,
      outsideWorkerCount: _outsideFoodCount,
      machineWorkerCount: _machineFoodCount,
      guestCount: _guestFoodCount,
      otherCount: _otherFoodCount,
      remarks: _finalRemarksController.text.trim(),
      payload: _buildSubmissionPayload(),
    );

    final saved = await _foodRepo.submitFood(submission);

    if (!mounted) return;
    if (saved == null) {
      setState(() => _isSubmitting = false);
      _showSnackbar(
          '❌ Failed to submit food list. Check connection.', AppTheme.danger);
      return;
    }

    // Mark the consumed food requests as submitted.
    for (final request in _loadedRequests) {
      if (request.id != null) {
        await _foodRepo.markRequestSubmitted(request.id!);
      }
    }

    final record = FoodSubmissionRecord(
      id: saved.id ?? 'FOOD-${DateTime.now().millisecondsSinceEpoch}',
      submittedAt: saved.submittedAt ?? DateTime.now(),
      shifts: Set<String>.from(saved.shifts),
      regularWorkerCount: saved.regularWorkerCount,
      outsideWorkerCount: saved.outsideWorkerCount,
      machineWorkerPeopleCount: saved.machineWorkerCount,
      guestCount: saved.guestCount,
      otherCount: saved.otherCount,
      remarks: saved.remarks,
      payload: saved.payload is List
          ? (saved.payload as List).cast<Map<String, dynamic>>()
          : const [],
      status: 'Submitted',
    );

    setState(() {
      _submissionHistory.insert(0, record);
      _isSubmitting = false;
      _finalRemarksController.clear();
    });

    _sendOrderToCanteen(record);

    _showSnackbar(
      '✅ Food list submitted to HOD!',
      AppTheme.success,
    );
  }

  List<Map<String, dynamic>> _buildSubmissionPayload() {
    final payload = <Map<String, dynamic>>[];

    void addSelected({
      required List<Map<String, dynamic>> source,
      required FoodEntryType type,
      bool isMachine = false,
      bool isExtra = false,
    }) {
      for (final item in source) {
        if (item['foodStatus'] != 'yes') continue;

        payload.add({
          'entryType': type.label,
          'id': item['id'],
          'name': item['name'],
          'status': item['status'],
          'peopleCount': isMachine || isExtra
              ? intValue(item['people'] ?? item['count'] ?? 0)
              : 1,
          'foodStatus': item['foodStatus'],
        });
      }
    }

    addSelected(source: _foodAttendance, type: FoodEntryType.regularWorker);
    for (final batch in _outsideBatches) {
      final count = _outsideBatchCounts[batch.id] ?? 0;
      if (count > 0) {
        payload.add({
          'entryType': FoodEntryType.outsideWorker.label,
          'id': batch.id,
          'name': batch.name,
          'status': 'Batch',
          'peopleCount': count,
          'foodStatus': 'yes',
          'extraInfo': _outsideBatchExtraControllers[batch.id]?.text ?? '',
        });
      }
    }
    addSelected(source: _machineWorkers, type: FoodEntryType.machineWorker, isMachine: true);
    addSelected(source: _guests, type: FoodEntryType.guest, isExtra: true);
    addSelected(source: _others, type: FoodEntryType.other, isExtra: true);

    return payload;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHOD) {
      return const HodModuleReviewScreen(
        title: 'HOD Admin: Food Review',
        moduleFilter: 'Food',
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Food Management',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Prepare'),
              Tab(text: 'Workers'),
              Tab(text: 'History'),
              Tab(text: 'Status'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPrepareTab(),
            _buildWorkersTab(),
            _buildHistoryTab(),
            _buildStatusTab(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PREPARE TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPrepareTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildQuickStatsGrid(),
        const SizedBox(height: 16),
        _buildPreparationPreviewCard(),
        const SizedBox(height: 16),
        _buildFinalRemarksCard(),
        const SizedBox(height: 16),
        _buildSubmitButton(),
        const SizedBox(height: 18),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WORKERS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWorkersTab() {
    return Column(
      children: [
        TabBar(
          controller: _subTabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Regular Workers'),
            Tab(text: 'Outside Workers'),
            Tab(text: 'Guests & Others'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildRegularTabContent(),
              _buildOutsideTabContent(),
              _buildGuestOthersTabContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegularTabContent() {
    final items = _foodAttendance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTopBar(
          title: 'Regular Workers',
          subtitle: 'Worker ID, Name, and Food Status',
          icon: Icons.badge_outlined,
          color: AppTheme.success,
          selectedCount: _regularFoodCount,
          totalCount: _foodAttendance.length,
          onAllYes: () => _markAll(_foodAttendance, 'yes'),
          onAllNo: () => _markAll(_foodAttendance, 'no'),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _buildEmptyState(
            icon: Icons.badge_outlined,
            title: 'No regular workers found',
            subtitle: 'Workers will appear here from attendance data.',
          )
        else
          ...items.map((item) {
            return _buildRegularWorkerCard(
              item: item,
              onToggle: () => _toggleEntry(item),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildRegularWorkerCard({
    required Map<String, dynamic> item,
    required VoidCallback onToggle,
  }) {
    final enabled = item['foodStatus'] == 'yes';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.success.withOpacity(0.055) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppTheme.success.withOpacity(0.35) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppTheme.success.withOpacity(0.14) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person_outline,
              color: enabled ? AppTheme.success : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${item['id'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (item['status'] != null && item['status'] != 'Active')
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item['status'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.success.withOpacity(0.14)
                    : AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: enabled
                      ? AppTheme.success.withOpacity(0.28)
                      : AppTheme.danger.withOpacity(0.25),
                ),
              ),
              child: Text(
                enabled ? 'YES' : 'NO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsideTabContent() {
    final batches = _outsideBatches;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_2_outlined,
                  color: AppTheme.primary, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Outside Workers',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Batch-wise with count input and extra info',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildCountBadge(
                '${_outsideFoodCount} / ${_outsideBatches.fold(0, (sum, b) => sum + b.totalWorkers)}',
                AppTheme.primary),
          ],
        ),
        const SizedBox(height: 14),
        if (batches.isEmpty)
          _buildEmptyState(
            icon: Icons.groups_2_outlined,
            title: 'No outside worker batches',
            subtitle: 'Batches will appear here when added.',
          )
        else
          ...batches.map((batch) {
            final controller = _outsideBatchControllers[batch.id];
            final extraController = _outsideBatchExtraControllers[batch.id];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              batch.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Batch ID: ${batch.id}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Total: ${batch.totalWorkers}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        'Food Count:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppTheme.primary, width: 1.4),
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            final count = int.tryParse(value) ?? 0;
                            _updateOutsideCount(batch.id, count);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Extra Info:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: extraController,
                          decoration: InputDecoration(
                            hintText: 'Any additional notes...',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: AppTheme.primary, width: 1.4),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildGuestOthersTabContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuestSection(),
        const SizedBox(height: 16),
        _buildOthersSection(),
      ],
    );
  }

  Widget _buildGuestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTopBar(
          title: 'Guests',
          subtitle: 'Guest Name and Food Status (YES/NO)',
          icon: Icons.person_add_alt_1_outlined,
          color: AppTheme.warning,
          selectedCount: _guestFoodCount,
          totalCount: _guests.length,
          onAllYes: () => _markAll(_guests, 'yes'),
          onAllNo: () => _markAll(_guests, 'no'),
        ),
        const SizedBox(height: 14),
        if (_guests.isEmpty)
          _buildEmptyState(
            icon: Icons.person_add_alt_1_outlined,
            title: 'No guests added',
            subtitle: 'Add a guest using the form below.',
          )
        else
          ..._guests.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildGuestCard(
              item: item,
              onToggle: () => _toggleEntry(item),
              onRemove: () => _removeGuest(index),
            );
          }).toList(),
        const SizedBox(height: 14),
        _buildAddGuestForm(),
      ],
    );
  }

  Widget _buildGuestCard({
    required Map<String, dynamic> item,
    required VoidCallback onToggle,
    required VoidCallback onRemove,
  }) {
    final enabled = item['foodStatus'] == 'yes';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.warning.withOpacity(0.055) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppTheme.warning.withOpacity(0.35) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppTheme.warning.withOpacity(0.14) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person_outline,
              color: enabled ? AppTheme.warning : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['name'] ?? 'Unknown Guest',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.success.withOpacity(0.14)
                    : AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: enabled
                      ? AppTheme.success.withOpacity(0.28)
                      : AppTheme.danger.withOpacity(0.25),
                ),
              ),
              child: Text(
                enabled ? 'YES' : 'NO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppTheme.danger, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAddGuestForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _guestNameController,
              decoration: _inputDecoration(
                hint: 'Enter guest name',
                icon: Icons.person_add_outlined,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _addGuest,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOthersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTopBar(
          title: 'Others',
          subtitle: 'Extra food items',
          icon: Icons.category_outlined,
          color: AppTheme.accent,
          selectedCount: _otherFoodCount,
          totalCount: _others.length,
          onAllYes: () => _markAll(_others, 'yes'),
          onAllNo: () => _markAll(_others, 'no'),
        ),
        const SizedBox(height: 14),
        if (_others.isEmpty)
          _buildEmptyState(
            icon: Icons.category_outlined,
            title: 'No other items added',
            subtitle: 'Add extra food items using the form below.',
          )
        else
          ..._others.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildOtherCard(
              item: item,
              onToggle: () => _toggleEntry(item),
              onRemove: () => _removeOther(index),
            );
          }).toList(),
        const SizedBox(height: 14),
        _buildAddOtherForm(),
      ],
    );
  }

  Widget _buildOtherCard({
    required Map<String, dynamic> item,
    required VoidCallback onToggle,
    required VoidCallback onRemove,
  }) {
    final enabled = item['foodStatus'] == 'yes';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.accent.withOpacity(0.055) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppTheme.accent.withOpacity(0.35) : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppTheme.accent.withOpacity(0.14) : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.category_outlined,
              color: enabled ? AppTheme.accent : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item['name'] ?? 'Unknown Item',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.success.withOpacity(0.14)
                    : AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: enabled
                      ? AppTheme.success.withOpacity(0.28)
                      : AppTheme.danger.withOpacity(0.25),
                ),
              ),
              child: Text(
                enabled ? 'YES' : 'NO',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: enabled ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, color: AppTheme.danger, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOtherForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _otherController,
              decoration: _inputDecoration(
                hint: 'Enter others',
                icon: Icons.add_box_outlined,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _addOther,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORY TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryTab() {
    final Map<DateTime, List<FoodSubmissionRecord>> grouped = {};
    for (final record in _submissionHistory) {
      final dateKey = DateTime(record.submittedAt.year,
          record.submittedAt.month, record.submittedAt.day);
      grouped.putIfAbsent(dateKey, () => []).add(record);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHistorySummaryCard(),
        const SizedBox(height: 16),
        if (sortedDates.isEmpty)
          _buildEmptyState(
            icon: Icons.history_outlined,
            title: 'No food submissions yet',
            subtitle: 'Submitted food lists will appear here grouped by date.',
          )
        else
          ...sortedDates.map((date) {
            final records = grouped[date]!;
            final totalParcels =
                records.fold(0, (sum, r) => sum + r.totalPeople);
            return _buildDateTile(date, totalParcels, records);
          }),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildDateTile(
      DateTime date, int totalParcels, List<FoodSubmissionRecord> records) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
        title: Text(
          _formatDate(date),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalParcels parcels',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ),
        onTap: () {
          _showDayDetailsDialog(date, records);
        },
      ),
    );
  }

  void _showDayDetailsDialog(
      DateTime date, List<FoodSubmissionRecord> records) {
    final totalParcels = records.fold(0, (sum, r) => sum + r.totalPeople);
    final regular = records.fold(0, (sum, r) => sum + r.regularWorkerCount);
    final outside = records.fold(0, (sum, r) => sum + r.outsideWorkerCount);
    final machine =
        records.fold(0, (sum, r) => sum + r.machineWorkerPeopleCount);
    final guest = records.fold(0, (sum, r) => sum + r.guestCount);
    final other = records.fold(0, (sum, r) => sum + r.otherCount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Food Details for ${_formatDate(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryDetailRow('Total Parcels', totalParcels, AppTheme.primary),
            const Divider(),
            _buildSummaryDetailRow('Regular Workers', regular, AppTheme.success),
            _buildSummaryDetailRow('Outside Workers', outside, AppTheme.info),
            _buildSummaryDetailRow('Machine Workers', machine, AppTheme.warning),
            _buildSummaryDetailRow('Guests', guest, Colors.orange),
            _buildSummaryDetailRow('Others', other, AppTheme.accent),
            const SizedBox(height: 8),
            Text(
              'Total submissions: ${records.length}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetailRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSessionHeader(),
          const SizedBox(height: 16),
          _buildFoodStatusBar(),
          const SizedBox(height: 16),
          _buildOrderSummary(),
          const SizedBox(height: 16),
          _buildReceivedCounts(),
          const SizedBox(height: 16),
          _buildSaveButton(),
          const SizedBox(height: 20),
          _buildSavedSessions(),
        ],
      ),
    );
  }

  Widget _buildSessionHeader() {
    final icon = _sessionIcons[_currentSession];
    final name = _sessionNames[_currentSession];
    final meal = _sessionMeals[_currentSession];
    final time = _getCurrentTime();
    final isOrderActive = _currentStage >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name - $meal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                isOrderActive ? 'Order in Progress' : 'No Active Order',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodStatusBar() {
    final List<String> stages = ['Ordered', 'Canteen Received', 'Dispatched', 'Received'];
    final bool hasOrder = _currentStage >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Food Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (!hasOrder) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No Active Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    'Waiting for order to be placed...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: stages.asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value;
                final isActive = index <= _currentStage;
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.green : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 6),

            LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final progress = (_currentStage + 1) / stages.length;
                final progressWidth = barWidth * progress;

                return Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: progressWidth,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentStage < 4 ? Colors.green : AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentStage < 4
                      ? 'Current: ${stages[_currentStage]}'
                      : '✅ Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _currentStage < 4 ? Colors.green : AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final totalReceived = _receivedRegular + _receivedOutside + _receivedGuestsOthers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getCurrentTime(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Ordered',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Received',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Balance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _buildSummaryRow('Regular', _orderedRegular, _receivedRegular, _balanceRegular),
          _buildSummaryRow('Outside', _orderedOutside, _receivedOutside, _balanceOutside),
          _buildSummaryRow('Guests & Others', _orderedGuestsOthers, _receivedGuestsOthers, _balanceGuestsOthers),

          Container(
            height: 1,
            color: AppTheme.border,
            margin: const EdgeInsets.symmetric(vertical: 4),
          ),

          _buildSummaryRow('Total', _orderedTotal, totalReceived, _balanceTotal, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int ordered, int received, int balance,
      {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: isTotal ? AppTheme.primary.withOpacity(0.04) : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isTotal ? 13 : 12,
                  fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                  color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              ordered.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 13 : 12,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              received.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 13 : 12,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              balance >= 0 ? '+$balance' : balance.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTotal ? 13 : 12,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
                color: balance >= 0 ? AppTheme.success : AppTheme.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedCounts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Received Counts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCountField(
                label: 'Regular',
                value: _receivedRegular,
                onChanged: (val) => setState(() => _receivedRegular = val),
              ),
              const SizedBox(width: 8),
              _buildCountField(
                label: 'Outside',
                value: _receivedOutside,
                onChanged: (val) => setState(() => _receivedOutside = val),
              ),
              const SizedBox(width: 8),
              _buildCountField(
                label: 'Guests & Others',
                value: _receivedGuestsOthers,
                onChanged: (val) => setState(() => _receivedGuestsOthers = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
              ),
              isDense: true,
            ),
            onChanged: (val) {
              final newVal = int.tryParse(val) ?? 0;
              onChanged(newVal);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final isEnabled = _currentStage >= 2 && !_isReceived;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? _saveSession : null,
        icon: const Icon(Icons.save_rounded),
        label: Text(
          _isReceived ? '✅ Session Saved' 
              : (_currentStage >= 2 ? 'Save Session' 
              : (_currentStage >= 0 ? 'Waiting for Dispatch...' 
              : 'No Active Order')),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppTheme.primary : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedSessions() {
    final today = _formatDate(DateTime.now());
    final todaySessions = _savedSessions
        .where((s) => s['date'] == today)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📋 Today\'s Sessions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (todaySessions.isEmpty)
            _buildEmptyState(
              icon: Icons.history_outlined,
              title: 'No sessions saved today',
              subtitle: 'Save sessions to track daily food orders.',
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSessionCard(todaySessions, 0),
                _buildSessionCard(todaySessions, 1),
                _buildSessionCard(todaySessions, 2),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(List<Map<String, dynamic>> sessions, int index) {
    final session = sessions.firstWhere(
      (s) => (s['sessionIndex'] ?? 0) == index,
      orElse: () => {},
    );

    if (session.isEmpty) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ['☀️', '🌤️', '🌙'][index],
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                ['Morning', 'Afternoon', 'Night'][index],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '0 parcels',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _showSessionDetails(session),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                session['icon'] ?? '',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                session['session'] ?? '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${session['orderedTotal'] ?? 0} parcels',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                session['time'] ?? '',
                style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final width = isWide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _buildStatCard(
                label: 'Regular',
                value: '$_regularFoodCount',
                subtitle: '${_foodAttendance.length} workers',
                icon: Icons.badge_outlined,
                color: AppTheme.success,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildStatCard(
                label: 'Outside',
                value: '$_outsideFoodCount',
                subtitle: '${_outsideBatches.length} batches',
                icon: Icons.groups_2_outlined,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildStatCard(
                label: 'Machine',
                value: '$_machineFoodCount',
                subtitle: '${_machineWorkers.length} machine groups',
                icon: Icons.precision_manufacturing_outlined,
                color: AppTheme.info,
              ),
            ),
            SizedBox(
              width: width,
              child: _buildStatCard(
                label: 'Extras',
                value: '${_guestFoodCount + _otherFoodCount}',
                subtitle: '${_guests.length + _others.length} entries',
                icon: Icons.add_box_outlined,
                color: AppTheme.warning,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreparationPreviewCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            title: 'Final Food Count Preview',
            subtitle: 'Live count before sending to Admin & Canteen.',
            icon: Icons.fact_check_outlined,
            color: AppTheme.success,
          ),
          const SizedBox(height: 14),
          _buildPreviewRow('Regular Workers', _regularFoodCount,
              Icons.badge_outlined, AppTheme.success),
          _buildPreviewRow('Outside Workers', _outsideFoodCount,
              Icons.groups_2_outlined, AppTheme.primary),
          _buildPreviewRow('Machine Workers', _machineFoodCount,
              Icons.precision_manufacturing_outlined, AppTheme.info),
          _buildPreviewRow('Guests', _guestFoodCount,
              Icons.person_add_alt_1_outlined, AppTheme.warning),
          _buildPreviewRow('Others', _otherFoodCount, Icons.category_outlined,
              AppTheme.accent),
          const Divider(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total People for Food',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.success.withOpacity(0.24)),
                ),
                child: Text(
                  '${_calculateTotal()}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalRemarksCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            title: 'Final Remarks',
            subtitle: 'Optional note for admin and canteen.',
            icon: Icons.notes_outlined,
            color: AppTheme.warning,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _finalRemarksController,
            minLines: 2,
            maxLines: 4,
            decoration: _inputDecoration(
              hint:
                  'Example: prepare extra curry for machine workers / less spicy food for guests',
              icon: Icons.edit_note_outlined,
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
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: Text(
          _isSubmitting ? 'Sending Food List...' : 'Send to Admin & Canteen',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTopBar({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required int selectedCount,
    required int totalCount,
    required VoidCallback onAllYes,
    required VoidCallback onAllNo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildCountBadge('$selectedCount / $totalCount', color),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAllYes,
                icon: const Icon(Icons.check_circle_outline, size: 17),
                label: const Text('All YES'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: const BorderSide(color: AppTheme.success),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAllNo,
                icon: const Icon(Icons.cancel_outlined, size: 17),
                label: const Text('All NO'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }


  Widget _buildMiniPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildHistorySummaryCard() {
    final last = _submissionHistory.isEmpty ? null : _submissionHistory.first;

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            title: 'Submission History',
            subtitle: 'Track food lists sent to Admin & Canteen.',
            icon: Icons.history_outlined,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSmallSummaryTile(
                  'Records',
                  '${_submissionHistory.length}',
                  Icons.receipt_long_outlined,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSmallSummaryTile(
                  'Last Total',
                  last == null ? '0' : '${last.totalPeople}',
                  Icons.restaurant_outlined,
                  AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildCardTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 19),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 28 : 42, color: AppTheme.textMuted),
          SizedBox(height: compact ? 8 : 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}