// ignore_for_file: deprecated_member_use, prefer_const_constructors, prefer_const_literals_to_create_immutables, curly_braces_in_flow_control_structures, prefer_const_declarations, unused_field, unused_element, unused_element_parameter

import 'dart:async';
import 'dart:typed_data' as typed_data;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/attendance_context_service.dart';
import '../services/device_file_picker.dart';
import '../services/photo_upload_service.dart';
import '../services/stock_inventory_repository.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import 'hod_module_review_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// THEME
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF4F6AF5);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color successBg = Color(0xFFF0FDF4);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerBg = Color(0xFFFFF1F2);
  static const Color infoBg = Color(0xFFEFF6FF);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceCard,
          foregroundColor: textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontSize: 12),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: danger),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGET — HOD APPROVAL BADGE
// ══════════════════════════════════════════════════════════════════════════════
class HodApprovalBadge extends StatelessWidget {
  final String text;
  const HodApprovalBadge(
      {super.key, this.text = 'Requires HOD approval before processing'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              size: 13, color: AppTheme.warning),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class StockPoint {
  final String id, name, location, batchId;
  final int onHand, todayUsage, reorderLevel, totalIn, totalOut;

  const StockPoint({
    required this.id,
    required this.name,
    required this.location,
    required this.batchId,
    required this.onHand,
    required this.todayUsage,
    required this.reorderLevel,
    required this.totalIn,
    required this.totalOut,
  });

  int get remaining => onHand - todayUsage;
  bool get isLow => remaining <= reorderLevel;
  double get stockPercentage => (reorderLevel == 0)
      ? 100
      : ((remaining / reorderLevel) * 100).clamp(0, 200);
}

class StockMovement {
  final String type, item, batch, date, by;
  final int quantity;

  const StockMovement({
    required this.type,
    required this.item,
    required this.quantity,
    required this.batch,
    required this.date,
    required this.by,
  });
}

enum ReconciliationStatus { matched, shortage, excess }

/// Action a supervisor takes to resolve a bill line's reconciliation.
/// `reorder` = ordered more than received (shortage), `extra` = received more
/// than ordered (excess), `done` = no reconciliation needed (matched).
enum ReconciliationAction { reorder, extra, done }

class GINBillItem {
  final int sno;
  final String itemName;
  final double orderedQty;
  final double billedQty;
  double receivedQty;

  /// Null until the supervisor picks an action. Drives submit gating.
  ReconciliationAction? actionTaken;

  GINBillItem({
    required this.sno,
    required this.itemName,
    required this.orderedQty,
    required this.billedQty,
    required this.receivedQty,
    this.actionTaken,
  });

  double get diffBilledReceived => billedQty - receivedQty;
  double get diffOrderedReceived => orderedQty - receivedQty;

  bool get hasDiscrepancy =>
      diffBilledReceived != 0 || diffOrderedReceived != 0;

  ReconciliationStatus get status {
    if (diffBilledReceived == 0 && diffOrderedReceived == 0) {
      return ReconciliationStatus.matched;
    }
    return receivedQty < billedQty
        ? ReconciliationStatus.shortage
        : ReconciliationStatus.excess;
  }

  /// Action suggested by the received-vs-ordered diff. The single context
  /// button in the ACTION column defaults to this.
  ReconciliationAction get suggestedAction {
    switch (status) {
      case ReconciliationStatus.shortage:
        return ReconciliationAction.reorder;
      case ReconciliationStatus.excess:
        return ReconciliationAction.extra;
      case ReconciliationStatus.matched:
        return ReconciliationAction.done;
    }
  }

  /// True once the supervisor has picked any action for this line.
  bool get resolved => actionTaken != null;
}

class GINBill {
  final String billNumber, supplierName;
  final List<GINBillItem> items;

  const GINBill({
    required this.billNumber,
    required this.supplierName,
    required this.items,
  });
}

class GINStockPointPending {
  final String stockPointId, stockPointName;
  final List<GINBill> pendingBills;

  const GINStockPointPending({
    required this.stockPointId,
    required this.stockPointName,
    required this.pendingBills,
  });
}

class UploadedDocument {
  final String name;
  final DateTime uploadedAt;

  UploadedDocument({
    required this.name,
    required this.uploadedAt,
  });
}

enum SubmissionType { order, returnStock }

class SubmissionRecord {
  final String id;
  final SubmissionType type;
  final String stockPoint, item;
  final int quantity;
  final String? purpose;
  final DateTime submittedAt;
  final String status;

  const SubmissionRecord({
    required this.id,
    required this.type,
    required this.stockPoint,
    required this.item,
    required this.quantity,
    this.purpose,
    required this.submittedAt,
    required this.status,
  });
}

class RaisedOrderItem {
  final String itemName;
  final String batch;
  final int quantity;
  final String unit;

  const RaisedOrderItem({
    required this.itemName,
    required this.batch,
    required this.quantity,
    this.unit = 'units',
  });
}

class RaisedOrderRecord {
  final String id;
  final String stockPoint;
  final String approvedBy;
  final DateTime approvedAt;
  final String status;
  final List<RaisedOrderItem> items;

  const RaisedOrderRecord({
    required this.id,
    required this.stockPoint,
    required this.approvedBy,
    required this.approvedAt,
    required this.status,
    required this.items,
  });

  int get totalItems => items.length;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);
}

class ReturnItemDraft {
  final String itemName;
  final TextEditingController quantityController;
  bool selected;

  ReturnItemDraft({
    required this.itemName,
    TextEditingController? quantityController,
    this.selected = false,
  }) : quantityController = quantityController ?? TextEditingController();

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;

  void dispose() => quantityController.dispose();
}

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StockInventoryScreen extends StatefulWidget {
  final bool isHOD;

  const StockInventoryScreen({super.key, this.isHOD = false});

  @override
  State<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends State<StockInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StockPoint? _selectedPoint;

  static const List<StockPoint> _stockPoints = [
    StockPoint(
        id: 'SP-001',
        name: 'Site A — North',
        location: 'North Block',
        batchId: 'B-042',
        onHand: 450,
        todayUsage: 12,
        reorderLevel: 20,
        totalIn: 750,
        totalOut: 300),
    StockPoint(
        id: 'SP-002',
        name: 'Site B — South',
        location: 'South Block',
        batchId: 'B-039',
        onHand: 200,
        todayUsage: 8,
        reorderLevel: 30,
        totalIn: 400,
        totalOut: 200),
    StockPoint(
        id: 'SP-003',
        name: 'Warehouse Main',
        location: 'Central Store',
        batchId: 'B-031',
        onHand: 18,
        todayUsage: 5,
        reorderLevel: 20,
        totalIn: 600,
        totalOut: 582),
    StockPoint(
        id: 'SP-004',
        name: 'Field Store',
        location: 'Field Office',
        batchId: 'B-044',
        onHand: 120,
        todayUsage: 20,
        reorderLevel: 15,
        totalIn: 300,
        totalOut: 180),
  ];

  static const List<StockMovement> _movements = [
    StockMovement(
        type: 'in',
        item: 'Diesel',
        quantity: 80,
        batch: 'B-042',
        date: 'Today 9:10 AM',
        by: 'HOD Approved'),
    StockMovement(
        type: 'out',
        item: 'Diesel',
        quantity: 12,
        batch: 'B-042',
        date: 'Today 11:30 AM',
        by: 'MCH-001'),
    StockMovement(
        type: 'in',
        item: 'Engine Oil',
        quantity: 20,
        batch: 'B-041',
        date: 'Yesterday',
        by: 'HOD Approved'),
    StockMovement(
        type: 'return',
        item: 'Bolts & Nuts',
        quantity: 5,
        batch: 'B-038',
        date: '12 May',
        by: 'RET-0089'),
    StockMovement(
        type: 'transfer',
        item: 'Hydraulic Fluid',
        quantity: 10,
        batch: 'B-040',
        date: '11 May',
        by: 'SP-001→SP-002'),
  ];

  static final List<GINStockPointPending> _ginStockPoints = [
    GINStockPointPending(
      stockPointId: 'SP-001',
      stockPointName: 'Site A — North',
      pendingBills: [
        GINBill(
          billNumber: 'BILL-2024-001',
          supplierName: 'AquaFeed Ltd.',
          items: [
            GINBillItem(
                sno: 1,
                itemName: 'Floating Fish Feed (3mm)',
                orderedQty: 200,
                billedQty: 200,
                receivedQty: 180),
            GINBillItem(
                sno: 2,
                itemName: 'Sinking Pellets (5mm)',
                orderedQty: 150,
                billedQty: 150,
                receivedQty: 150),
          ],
        ),
        GINBill(
          billNumber: 'BILL-2024-002',
          supplierName: 'Marine Equipments Co.',
          items: [
            GINBillItem(
                sno: 1,
                itemName: 'Aerator Pump (2HP)',
                orderedQty: 5,
                billedQty: 5,
                receivedQty: 3),
            GINBillItem(
                sno: 2,
                itemName: 'Water Quality Sensor',
                orderedQty: 10,
                billedQty: 10,
                receivedQty: 10),
          ],
        ),
      ],
    ),
    GINStockPointPending(
      stockPointId: 'SP-002',
      stockPointName: 'Site B — South',
      pendingBills: [
        GINBill(
          billNumber: 'BILL-2024-003',
          supplierName: 'Net Solutions Pvt.',
          items: [
            GINBillItem(
                sno: 1,
                itemName: 'HDPE Net (100m roll)',
                orderedQty: 20,
                billedQty: 20,
                receivedQty: 15),
          ],
        ),
      ],
    ),
    GINStockPointPending(
      stockPointId: 'SP-003',
      stockPointName: 'Warehouse Main',
      pendingBills: [
        GINBill(
          billNumber: 'BILL-2024-004',
          supplierName: 'PharmaCare Aqua',
          items: [
            GINBillItem(
                sno: 1,
                itemName: 'Oxytetracycline (1kg)',
                orderedQty: 50,
                billedQty: 50,
                receivedQty: 50),
            GINBillItem(
                sno: 2,
                itemName: 'Probiotics (500g)',
                orderedQty: 30,
                billedQty: 30,
                receivedQty: 25),
            GINBillItem(
                sno: 3,
                itemName: 'Vitamin Premix',
                orderedQty: 100,
                billedQty: 100,
                receivedQty: 95),
          ],
        ),
        GINBill(
          billNumber: 'BILL-2024-005',
          supplierName: 'AquaFeed Ltd.',
          items: [
            GINBillItem(
                sno: 1,
                itemName: 'Spirulina Powder (1kg)',
                orderedQty: 40,
                billedQty: 40,
                receivedQty: 40),
          ],
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // Reduced to 6 tabs
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHOD) {
      return const HodModuleReviewScreen(
        title: 'HOD Admin: Stock Review',
        moduleFilter: 'Stock',
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Stock Inventory',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            controller: _tabController,
            tabs: const [
              Tab(text: 'Stock'),
              Tab(text: 'View Orders'),
              Tab(text: 'GIN'),
              Tab(text: 'Return'),
              Tab(text: 'Transfer'),
              Tab(text: 'Consumables'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            const _StockFeatureTab(),
            const _ViewOrdersTab(),
            const _GINReviewTab(),
            const _ReturnTab(),
            const StockTransferTab(),
            const _OtherConsumablesTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE TAB — STOCK
// ══════════════════════════════════════════════════════════════════════════════

enum StockFeatureView {
  summary,
  itemWise,
  categoryWise,
  stockPoint,
  entry,
  reports
}

enum AquaVoucherType {
  receipt,
  issue,
  transfer,
  mortality,
  harvest,
  adjustment,
  physicalVerification
}

enum AquaSyncState { idle, syncing, success, failed }

class AquaStockPoint {
  final String id, name, type, parent, locationCode;
  final double? capacityLitres;

  const AquaStockPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.parent,
    required this.locationCode,
    this.capacityLitres,
  });

  String get friendlyType => type
      .split('_')
      .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
      .join(' ');
}

class AquaUom {
  final String code, name, kind;
  final String? baseCode;
  final double numerator, denominator;
  final int decimals;

  const AquaUom({
    required this.code,
    required this.name,
    required this.kind,
    this.baseCode,
    this.numerator = 1,
    this.denominator = 1,
    this.decimals = 0,
  });

  double toBase(double qty) => qty * numerator / denominator;
  String get display => baseCode == null ? code : '$code → $baseCode';
}

class AquaStockItem {
  final String id,
      code,
      name,
      group,
      category,
      primaryUom,
      purchaseUom,
      stockNature;
  final double reorderLevel;
  final bool maintainBatches, trackAvgWeight;
  final double standardCost;

  const AquaStockItem({
    required this.id,
    required this.code,
    required this.name,
    required this.group,
    required this.category,
    required this.primaryUom,
    required this.purchaseUom,
    required this.stockNature,
    required this.reorderLevel,
    required this.maintainBatches,
    required this.trackAvgWeight,
    required this.standardCost,
  });
}

class AquaBatchBalance {
  final String id, batchCode, itemId, stockPointId, expectedHarvestDate, status;
  final double openingQty,
      currentQty,
      mortalityCount,
      avgWeightG,
      feedKg,
      totalIn,
      totalOut;
  final bool synced;

  const AquaBatchBalance({
    this.id = '',
    required this.batchCode,
    required this.itemId,
    required this.stockPointId,
    required this.expectedHarvestDate,
    required this.status,
    required this.openingQty,
    required this.currentQty,
    required this.mortalityCount,
    required this.avgWeightG,
    required this.feedKg,
    required this.totalIn,
    required this.totalOut,
    required this.synced,
  });

  double get biomassKg => (currentQty * avgWeightG) / 1000;
  double get survivalPct => openingQty <= 0
      ? 100
      : ((openingQty - mortalityCount) / openingQty * 100)
          .clamp(0, 100)
          .toDouble();
  double get biomassGainKg => biomassKg <= 0 ? 0 : biomassKg;
  double get fcr => biomassGainKg <= 0 ? 0 : feedKg / biomassGainKg;
  bool get isLow =>
      currentQty <= 0 || (openingQty > 0 && currentQty <= openingQty * 0.10);
}

class AquaMovementLine {
  final String id,
      voucherNo,
      idempotencyKey,
      payloadHash,
      type,
      itemName,
      batchCode,
      fromPoint,
      toPoint,
      date,
      enteredBy,
      note,
      uom;
  final double qty, qtyInBase;
  final bool synced;

  const AquaMovementLine({
    required this.id,
    required this.voucherNo,
    required this.idempotencyKey,
    required this.payloadHash,
    required this.type,
    required this.itemName,
    required this.batchCode,
    required this.fromPoint,
    required this.toPoint,
    required this.date,
    required this.enteredBy,
    required this.note,
    required this.uom,
    required this.qty,
    required this.qtyInBase,
    required this.synced,
  });

  AquaMovementLine copyWithSynced() => AquaMovementLine(
        id: id,
        voucherNo: voucherNo,
        idempotencyKey: idempotencyKey,
        payloadHash: payloadHash,
        type: type,
        itemName: itemName,
        batchCode: batchCode,
        fromPoint: fromPoint,
        toPoint: toPoint,
        date: date,
        enteredBy: enteredBy,
        note: note,
        uom: uom,
        qty: qty,
        qtyInBase: qtyInBase,
        synced: true,
      );
}

class _StockFeatureTab extends StatefulWidget {
  const _StockFeatureTab();

  @override
  State<_StockFeatureTab> createState() => _StockFeatureTabState();
}

class _StockFeatureTabState extends State<_StockFeatureTab> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '12');
  final _noteCtrl = TextEditingController();

  StockFeatureView _view = StockFeatureView.summary;
  AquaVoucherType _voucherType = AquaVoucherType.receipt;
  AquaSyncState _syncState = AquaSyncState.idle;
  AquaStockItem? _entryItem;
  AquaUom? _entryUom;
  AquaStockPoint? _entryFromPoint;
  AquaStockPoint? _entryToPoint;
  AquaStockPoint? _selectedPoint;
  String _groupFilter = 'All';
  String _reportFilter = 'Stock Summary';
  String _lastSyncTs = '28 May, 12:10 PM';
  String _serverCursor = 'chg_000998772';
  String? _lastSyncError;
  bool _showLowOnly = false;
  bool _autoRetryEnabled = true;
  bool _savingVoucher = false;
  final List<AquaMovementLine> _localQueue = [];
  final List<AquaMovementLine> _syncedDuringSession = [];

  static const List<AquaUom> _uoms = [
    AquaUom(code: 'NOS', name: 'Numbers', kind: 'simple', decimals: 0),
    AquaUom(code: 'KG', name: 'Kilogram', kind: 'simple', decimals: 2),
    AquaUom(code: 'LITRE', name: 'Litre', kind: 'simple', decimals: 2),
    AquaUom(
        code: 'BAG500',
        name: 'Seed Bag 500 Nos',
        kind: 'alternate',
        baseCode: 'NOS',
        numerator: 500,
        decimals: 0),
    AquaUom(
        code: 'LAKH',
        name: 'Lakh Nos',
        kind: 'alternate',
        baseCode: 'NOS',
        numerator: 100000,
        decimals: 2),
    AquaUom(
        code: 'BAG25',
        name: 'Feed Bag 25 Kg',
        kind: 'alternate',
        baseCode: 'KG',
        numerator: 25,
        decimals: 2),
    AquaUom(
        code: 'SACK50',
        name: 'Sack 50 Kg',
        kind: 'alternate',
        baseCode: 'KG',
        numerator: 50,
        decimals: 2),
    AquaUom(
        code: 'CAN5',
        name: 'Can 5 Litres',
        kind: 'alternate',
        baseCode: 'LITRE',
        numerator: 5,
        decimals: 2),
  ];

  final _stockRepo = StockInventoryRepository();
  RealtimeChannel? _stockChannel;
  final List<AquaStockPoint> _points = [];
  final List<AquaStockItem> _items = [];
  final List<AquaBatchBalance> _batches = [];
  final List<AquaMovementLine> _serverMovements = [];
  final List<StockConsumption> _consumptions = [];
  bool _loadingStock = true;
  String? _stockError;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadLiveStock();
    _stockChannel = _stockRepo.watchBatchBalances(_loadLiveStock);
  }

  @override
  void dispose() {
    _stockRepo.stopWatching(_stockChannel);
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<AquaMovementLine> get _allMovements =>
      [..._localQueue, ..._syncedDuringSession, ..._serverMovements];
  int get _pendingSyncCount => _localQueue.length;
  int get _lowItemCount => _items.where((i) => _isItemLow(i)).length;
  double get _totalBiomass => _batches
      .where((b) => _itemById(b.itemId).trackAvgWeight)
      .fold<double>(0, (sum, b) => sum + b.biomassKg);
  double get _totalFeedKg =>
      _batches.fold<double>(0, (sum, b) => sum + b.feedKg);
  double get _inventoryValue => _items.fold<double>(
      0, (sum, i) => sum + (_totalQtyForItem(i.id) * i.standardCost));

  List<String> get _groups => ['All', ..._items.map((i) => i.group).toSet()];
  List<AquaStockPoint> get _operationalPoints =>
      _points.where((p) => p.type != 'site').toList();

  Future<void> _showConsumptionSheet(
      AquaStockPoint point, List<AquaBatchBalance> batches) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConsumptionSheet(
        point: point,
        batches: batches,
        itemNameOf: (id) => _itemById(id).name,
        itemCodeOf: (id) => _itemById(id).code,
        onDone: _loadLiveStock,
      ),
    );
  }

  AquaStockItem _itemById(String id) => _items.firstWhere(
        (i) => i.id == id,
        orElse: () => AquaStockItem(
          id: id,
          code: id,
          name: id,
          group: '',
          category: '',
          primaryUom: '',
          purchaseUom: '',
          stockNature: 'consumable',
          reorderLevel: 0,
          maintainBatches: true,
          trackAvgWeight: false,
          standardCost: 0,
        ),
      );
  AquaStockPoint _pointById(String id) => _points.firstWhere(
        (p) => p.id == id,
        orElse: () => AquaStockPoint(
          id: id,
          name: id,
          type: 'stock_point',
          parent: '',
          locationCode: id,
        ),
      );
  AquaUom _uomByCode(String code) =>
      _uoms.firstWhere((u) => u.code == code, orElse: () => _uoms.first);

  Future<void> _loadLiveStock() async {
    try {
      final items = await _stockRepo.fetchItems();
      final batches = await _stockRepo.fetchBatchBalances();
      List<StockConsumption> consumptions = [];
      try {
        consumptions = await _stockRepo.fetchConsumptions();
      } catch (_) {
        // Consumption report is best-effort.
      }
      if (!mounted) return;
      final mappedItems = items.map(_toAquaItem).toList();
      final mappedBatches = batches.map(_toAquaBatch).toList();
      final mappedPoints = _pointsFromBatches(batches);
      setState(() {
        _items
          ..clear()
          ..addAll(mappedItems);
        _batches
          ..clear()
          ..addAll(mappedBatches);
        _consumptions
          ..clear()
          ..addAll(consumptions);
        _points
          ..clear()
          ..addAll(mappedPoints);
        if (_entryItem != null &&
            !_items.any((item) => item.id == _entryItem!.id)) {
          _entryItem = null;
          _entryUom = null;
        }
        if (_entryFromPoint != null &&
            !_points.any((point) => point.id == _entryFromPoint!.id)) {
          _entryFromPoint = null;
        }
        if (_entryToPoint != null &&
            !_points.any((point) => point.id == _entryToPoint!.id)) {
          _entryToPoint = null;
        }
        if (_selectedPoint != null &&
            !_points.any((point) => point.id == _selectedPoint!.id)) {
          _selectedPoint = null;
        }
        _entryItem ??= _items.isEmpty ? null : _items.first;
        if (_entryItem != null)
          _entryUom ??= _uomByCode(_entryItem!.primaryUom);
        _selectedPoint ??=
            _operationalPoints.isEmpty ? null : _operationalPoints.first;
        _loadingStock = false;
        _stockError = null;
        _lastSyncTs = 'Just now';
        _serverCursor =
            'live_${DateTime.now().millisecondsSinceEpoch % 1000000}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStock = false;
        _stockError =
            'Live stock is unavailable. Check stock_items, stock_batch_balances, RLS and realtime setup.';
        _syncState = AquaSyncState.failed;
      });
    }
  }

  AquaStockItem _toAquaItem(StockInventoryItem item) {
    return AquaStockItem(
      id: item.id,
      code: item.code,
      name: item.name,
      group: item.group,
      category: item.category,
      primaryUom: item.uom,
      purchaseUom: item.uom,
      stockNature: _stockNatureFor(item),
      reorderLevel: 0,
      maintainBatches: item.batchRequired,
      trackAvgWeight: false,
      standardCost: 0,
    );
  }

  AquaBatchBalance _toAquaBatch(StockBatchBalance batch) {
    return AquaBatchBalance(
      id: batch.id,
      batchCode: batch.batchId,
      itemId: batch.itemId,
      stockPointId: batch.stockPointId,
      expectedHarvestDate: '-',
      status: batch.availableQty > 0 ? 'active' : 'empty',
      openingQty: batch.availableQty,
      currentQty: batch.availableQty,
      mortalityCount: 0,
      avgWeightG: 0,
      feedKg: 0,
      totalIn: batch.availableQty,
      totalOut: 0,
      synced: true,
    );
  }

  String _batchBalanceIdFor(AquaBatchBalance batch) => batch.id;

  List<AquaStockPoint> _pointsFromBatches(List<StockBatchBalance> batches) {
    final byId = <String, AquaStockPoint>{};
    for (final batch in batches) {
      byId[batch.stockPointId] = AquaStockPoint(
        id: batch.stockPointId,
        name: batch.stockPointName,
        type: 'stock_point',
        parent: '',
        locationCode:
            batch.location.isEmpty ? batch.stockPointName : batch.location,
      );
    }
    return byId.values.toList();
  }

  String _stockNatureFor(StockInventoryItem item) {
    final text = '${item.group} ${item.category} ${item.name}'.toLowerCase();
    if (text.contains('equipment') || text.contains('spare')) {
      return 'equipment';
    }
    if (text.contains('harvest')) return 'harvest';
    if (text.contains('seed') || text.contains('fish') || text.contains('pl')) {
      return 'live';
    }
    return 'consumable';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _simulatePullRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 14),
          _buildSyncStrip(),
          const SizedBox(height: 14),
          _buildViewSwitch(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_view) {
              StockFeatureView.summary => _buildSummaryView(),
              StockFeatureView.itemWise => _buildItemWiseView(),
              StockFeatureView.categoryWise => _buildCategoryView(),
              StockFeatureView.stockPoint => _buildStockPointView(),
              StockFeatureView.entry => _buildEntryView(),
              StockFeatureView.reports => _buildReportsView(),
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primary.withOpacity(0.16),
              AppTheme.info.withOpacity(0.06)
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Icon(Icons.inventory_2_outlined,
              color: AppTheme.primary, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Stock',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text(
                'Live stock ledger, batch balances, stock points and realtime availability',
                style:
                    TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]);

  Widget _buildSyncStrip() {
    final stateColor = switch (_syncState) {
      AquaSyncState.idle =>
        _pendingSyncCount == 0 ? AppTheme.success : AppTheme.warning,
      AquaSyncState.syncing => AppTheme.info,
      AquaSyncState.success => AppTheme.success,
      AquaSyncState.failed => AppTheme.danger,
    };
    final stateText = switch (_syncState) {
      AquaSyncState.idle => '$_pendingSyncCount pending',
      AquaSyncState.syncing => 'syncing...',
      AquaSyncState.success => 'synced',
      AquaSyncState.failed => 'sync failed',
    };
    return _CardShell(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _SyncPill(
              icon: Icons.phone_android_rounded,
              label: 'Local-first',
              color: AppTheme.info),
          const SizedBox(width: 8),
          _SyncPill(
              icon: Icons.sync_rounded, label: stateText, color: stateColor),
          const Spacer(),
          Text('cursor: $_serverCursor',
              style:
                  const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        ]),
        if (_lastSyncError != null) ...[
          const SizedBox(height: 8),
          Text(_lastSyncError!,
              style: const TextStyle(fontSize: 11, color: AppTheme.danger)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _QuickMetric(
                  label: 'Live Biomass',
                  value: '${_formatNumber(_totalBiomass, decimals: 0)} kg',
                  icon: Icons.bubble_chart_outlined,
                  color: AppTheme.success)),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickMetric(
                  label: 'Inventory Value',
                  value: '₹${_formatNumber(_inventoryValue, decimals: 0)}',
                  icon: Icons.currency_rupee_rounded,
                  color: AppTheme.primary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed:
                      _syncState == AquaSyncState.syncing ? null : _syncNow,
                  icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                  label: const Text('Sync now'))),
          const SizedBox(width: 10),
          Expanded(
            child: SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto retry',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              value: _autoRetryEnabled,
              onChanged: (v) => setState(() => _autoRetryEnabled = v),
            ),
          ),
        ]),
        Text('last_sync_ts: $_lastSyncTs',
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
      ]),
    );
  }

  Widget _buildViewSwitch() {
    final data = [
      (StockFeatureView.summary, 'Summary', Icons.space_dashboard_outlined),
      (StockFeatureView.itemWise, 'Items', Icons.table_chart_outlined),
      (StockFeatureView.categoryWise, 'Groups', Icons.account_tree_outlined),
      (StockFeatureView.stockPoint, 'Points', Icons.water_drop_outlined),
      (StockFeatureView.entry, 'Entry', Icons.post_add_outlined),
      (StockFeatureView.reports, 'Reports', Icons.analytics_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: data.map((d) {
        final selected = _view == d.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(d.$3,
                size: 16,
                color: selected ? Colors.white : AppTheme.textSecondary),
            label: Text(d.$2),
            selectedColor: AppTheme.primary,
            backgroundColor: AppTheme.surfaceCard,
            labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : AppTheme.textPrimary),
            side: BorderSide(
                color: selected ? AppTheme.primary : AppTheme.border),
            onSelected: (_) => setState(() => _view = d.$1),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildSummaryView() {
    final activeBatches = _batches.where((b) => b.status == 'active').length;
    final lowBatches = _batches.where((b) => b.isLow).length;
    return Column(
        key: const ValueKey('summary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 560 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.38,
            children: [
              _KpiCard(
                  title: 'Active Batches',
                  value: '$activeBatches',
                  subtitle: '$lowBatches low attention',
                  icon: Icons.qr_code_2,
                  color: AppTheme.primary),
              _KpiCard(
                  title: 'Stock Points',
                  value: '${_operationalPoints.length}',
                  subtitle: 'tank / pond / store',
                  icon: Icons.warehouse_outlined,
                  color: AppTheme.info),
              _KpiCard(
                  title: 'Feed Used',
                  value: '${_formatNumber(_totalFeedKg, decimals: 0)} kg',
                  subtitle: 'from movement stream',
                  icon: Icons.rice_bowl_outlined,
                  color: AppTheme.warning),
              _KpiCard(
                  title: 'Low Items',
                  value: '$_lowItemCount',
                  subtitle: 'below reorder level',
                  icon: Icons.warning_amber_rounded,
                  color:
                      _lowItemCount == 0 ? AppTheme.success : AppTheme.danger),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertPanel(),
          const SizedBox(height: 16),
          _buildMovementFeed(limit: 4),
        ]);
  }

  Widget _buildAlertPanel() {
    final lows = _items.where((i) => _isItemLow(i)).toList();
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_user_outlined,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('Operational Readiness',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary))),
          _MiniTag(_pendingSyncCount == 0 ? 'Clean' : 'Sync pending',
              _pendingSyncCount == 0 ? AppTheme.success : AppTheme.warning),
        ]),
        const SizedBox(height: 10),
        if (lows.isEmpty)
          const Text(
              'All item balances are above reorder levels. Stock-only operational movements are included in this dashboard.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
        else
          ...lows.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.priority_high_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          '${item.name} is at ${_formatNumber(_totalQtyForItem(item.id), decimals: 1)} ${item.primaryUom}. Reorder level: ${_formatNumber(item.reorderLevel, decimals: 1)}.',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textPrimary))),
                ]),
              )),
      ]),
    );
  }

  Widget _buildItemWiseView() {
    final visibleItems = _filteredItems();
    return Column(
        key: const ValueKey('items'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 12),
          _CardShell(
            padding: const EdgeInsets.all(0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Text('Item-wise Matrix',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                    'Horizontal scroll keeps mobile usable for many tanks/stores.',
                    style:
                        TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 44,
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 72,
                  columnSpacing: 14,
                  columns: [
                    const DataColumn(
                        label: SizedBox(width: 160, child: Text('Stock Item'))),
                    ..._operationalPoints.map((p) => DataColumn(
                        label: SizedBox(
                            width: 112,
                            child: Text(p.locationCode,
                                overflow: TextOverflow.ellipsis)))),
                    const DataColumn(
                        label: SizedBox(width: 86, child: Text('Total'))),
                  ],
                  rows: visibleItems
                      .map((item) => DataRow(cells: [
                            DataCell(SizedBox(
                              width: 160,
                              child: Row(children: [
                                _NatureDot(
                                    color: _natureColor(item.stockNature)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800),
                                          overflow: TextOverflow.ellipsis),
                                      Text(
                                          '${item.category} · ${item.primaryUom}',
                                          style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppTheme.textMuted),
                                          overflow: TextOverflow.ellipsis),
                                    ])),
                              ]),
                            )),
                            ..._operationalPoints.map((point) {
                              final qty = _qtyFor(item.id, point.id);
                              final biomass = _biomassFor(item.id, point.id);
                              final low = item.reorderLevel > 0 &&
                                  _totalQtyForItem(item.id) <=
                                      item.reorderLevel;
                              return DataCell(_MatrixCell(
                                  qty: qty,
                                  uom: item.primaryUom,
                                  biomassKg: biomass,
                                  isLow: low));
                            }),
                            DataCell(Text(
                                '${_formatNumber(_totalQtyForItem(item.id), decimals: 1)} ${item.primaryUom}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _isItemLow(item)
                                        ? AppTheme.danger
                                        : AppTheme.textPrimary))),
                          ]))
                      .toList(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _buildMovementFeed(limit: 5),
        ]);
  }

  Widget _buildFilterBar() => _CardShell(
        child: Column(children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search item, code, category, group'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _groupFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Stock Group',
                    prefixIcon: Icon(Icons.account_tree_outlined, size: 18)),
                items: _groups
                    .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (g) => setState(() => _groupFilter = g ?? 'All'),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('Low only'),
              selected: _showLowOnly,
              selectedColor: AppTheme.danger.withOpacity(0.15),
              checkmarkColor: AppTheme.danger,
              onSelected: (v) => setState(() => _showLowOnly = v),
            ),
          ]),
        ]),
      );

  Widget _buildCategoryView() {
    final groups = _items.map((i) => i.group).toSet().toList();
    return Column(
        key: const ValueKey('category'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category / Group Drill-down',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ...groups.map((g) {
            final groupItems = _items.where((i) => i.group == g).toList();
            final groupValue = groupItems.fold<double>(
                0, (sum, i) => sum + _totalQtyForItem(i.id) * i.standardCost);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CardShell(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _NatureDot(
                            color: _natureColor(groupItems.first.stockNature)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(g,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary))),
                        _MiniTag('₹${_formatNumber(groupValue, decimals: 0)}',
                            AppTheme.primary),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${groupItems.length} items · parallel stock-category model supported',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      ...groupItems.map((item) => _CategoryItemTile(
                          item: item,
                          qty: _totalQtyForItem(item.id),
                          color: _natureColor(item.stockNature))),
                    ]),
              ),
            );
          }),
        ]);
  }

  Widget _buildStockPointView() {
    final point = _selectedPoint ?? _operationalPoints.first;
    final pointBatches =
        _batches.where((b) => b.stockPointId == point.id).toList();
    final pointValue = pointBatches.fold<double>(
        0, (sum, b) => sum + b.currentQty * _itemById(b.itemId).standardCost);
    final pointBiomass = pointBatches
        .where((b) => _itemById(b.itemId).trackAvgWeight)
        .fold<double>(0, (sum, b) => sum + b.biomassKg);
    return Column(
        key: const ValueKey('stock-point'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardShell(
            child: DropdownButtonFormField<AquaStockPoint>(
              value: point,
              isExpanded: true,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.warehouse_outlined),
                  labelText: 'Select tank / pond / store'),
              items: _operationalPoints
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p.name} · ${p.friendlyType}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (p) => setState(() => _selectedPoint = p),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(
                    color: AppTheme.primary.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: pointBatches.isEmpty
                  ? null
                  : () => _showConsumptionSheet(point, pointBatches),
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              label: const Text('Record Consumption',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: _QuickMetric(
                    label: 'Type',
                    value: point.friendlyType,
                    icon: Icons.category_outlined,
                    color: AppTheme.info)),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickMetric(
                    label: 'Value',
                    value: '₹${_formatNumber(pointValue, decimals: 0)}',
                    icon: Icons.currency_rupee,
                    color: AppTheme.primary)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _QuickMetric(
                    label: 'Batches',
                    value: '${pointBatches.length}',
                    icon: Icons.qr_code_2,
                    color: AppTheme.warning)),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickMetric(
                    label: 'Biomass',
                    value: '${_formatNumber(pointBiomass, decimals: 1)} kg',
                    icon: Icons.bubble_chart_outlined,
                    color: AppTheme.success)),
          ]),
          const SizedBox(height: 14),
          if (pointBatches.isEmpty)
            const _EmptyMini(
                message: 'No active stock found in this stock point.')
          else
            ...pointBatches.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BatchCard(
                    batch: b, item: _itemById(b.itemId), point: point))),
        ]);
  }

  Widget _buildEntryView() {
    final item = _entryItem;
    final uom = _entryUom;
    final baseQty = _calculatedBaseQty;
    return _CardShell(
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Live Stock Movement',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary))),
            _MiniTag('5–7 fields', AppTheme.info),
          ]),
          const SizedBox(height: 6),
          const Text(
              'Issues and transfers update the selected item batch balance immediately.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<AquaVoucherType>(
            value: _voucherType,
            decoration: const InputDecoration(
                labelText: 'Voucher Type',
                prefixIcon: Icon(Icons.receipt_long_outlined)),
            items: AquaVoucherType.values
                .map((v) =>
                    DropdownMenuItem(value: v, child: Text(_voucherLabel(v))))
                .toList(),
            onChanged: (v) => setState(() {
              _voucherType = v ?? AquaVoucherType.receipt;
              _applyVoucherDefaults();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AquaStockItem>(
            value: item,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Stock Item',
                prefixIcon: Icon(Icons.inventory_2_outlined)),
            items: _items
                .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text('${i.name} · ${i.primaryUom}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (i) => setState(() {
              _entryItem = i;
              _entryUom = i == null ? null : _uomByCode(i.purchaseUom);
            }),
            validator: (v) => v == null ? 'Select stock item' : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _pointDropdown('From', _entryFromPoint,
                    (p) => setState(() => _entryFromPoint = p),
                    allowExternal: _voucherType == AquaVoucherType.receipt)),
            const SizedBox(width: 10),
            Expanded(
                child: _pointDropdown('To', _entryToPoint,
                    (p) => setState(() => _entryToPoint = p),
                    allowConsumption: _voucherType != AquaVoucherType.receipt &&
                        _voucherType != AquaVoucherType.transfer)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
                ],
                decoration: InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: const Icon(Icons.numbers),
                    suffixText: uom?.code),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0)
                    return 'Enter valid quantity';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<AquaUom>(
                value: uom,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'UoM'),
                items: _allowedUomsFor(item)
                    .map((u) => DropdownMenuItem(
                        value: u,
                        child:
                            Text(u.display, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (u) => setState(() => _entryUom = u),
                validator: (v) => v == null ? 'Select UoM' : null,
              ),
            ),
          ]),
          if (item != null && uom != null) ...[
            const SizedBox(height: 8),
            Text(
                'Base quantity: ${_formatNumber(baseQty, decimals: 3)} ${item.primaryUom}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Narration / Note',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingVoucher ? null : _postVoucher,
              icon: _savingVoucher
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt_rounded),
              label: Text(_savingVoucher ? 'Saving...' : 'Save Stock Movement'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildReportsView() {
    final reports = [
      'Stock Summary',
      'Godown Summary',
      'Batch Summary',
      'Movement Analysis',
      'Consumption'
    ];
    return Column(
        key: const ValueKey('reports'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardShell(
            child: DropdownButtonFormField<String>(
              value: _reportFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Report',
                  prefixIcon: Icon(Icons.analytics_outlined)),
              items: reports
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (r) =>
                  setState(() => _reportFilter = r ?? reports.first),
            ),
          ),
          const SizedBox(height: 12),
          if (_reportFilter == 'Stock Summary') _buildStockSummaryReport(),
          if (_reportFilter == 'Godown Summary') _buildGodownSummaryReport(),
          if (_reportFilter == 'Batch Summary') _buildBatchSummaryReport(),
          if (_reportFilter == 'Movement Analysis')
            _buildMovementAnalysisReport(),
          if (_reportFilter == 'Consumption') _buildConsumptionReport(),
        ]);
  }

  Widget _buildStockSummaryReport() => _ReportCard(
        title: 'Stock Summary',
        subtitle: 'Group, item and total balance across all stock points.',
        rows: _items
            .map((i) => [
                  _natureLabel(i.stockNature),
                  i.name,
                  '${_formatNumber(_totalQtyForItem(i.id), decimals: 2)} ${i.primaryUom}',
                  '₹${_formatNumber(_totalQtyForItem(i.id) * i.standardCost, decimals: 0)}'
                ])
            .toList(),
      );

  Widget _buildGodownSummaryReport() => _ReportCard(
        title: 'Godown / Stock-point Summary',
        subtitle:
            'Tally-like location roll-up for tanks, pond, feed store and equipment shed.',
        rows: _operationalPoints.map((p) {
          final qty = _batches
              .where((b) => b.stockPointId == p.id)
              .fold<double>(0, (sum, b) => sum + b.currentQty);
          final value = _batches
              .where((b) => b.stockPointId == p.id)
              .fold<double>(
                  0,
                  (sum, b) =>
                      sum + b.currentQty * _itemById(b.itemId).standardCost);
          return [
            p.locationCode,
            p.name,
            _formatNumber(qty, decimals: 2),
            '₹${_formatNumber(value, decimals: 0)}'
          ];
        }).toList(),
      );

  Widget _buildBatchSummaryReport() => _ReportCard(
        title: 'Batch Summary',
        subtitle:
            'Batch-level current quantity and stock point for every batch.',
        rows: _batches.map((b) {
          final item = _itemById(b.itemId);
          return [
            b.batchCode,
            item.name,
            '${_formatNumber(b.currentQty, decimals: 1)} ${item.primaryUom}',
            _pointById(b.stockPointId).name
          ];
        }).toList(),
      );

  Widget _buildMovementAnalysisReport() => _ReportCard(
        title: 'Movement Analysis',
        subtitle:
            'Includes stock-only operational vouchers, not only accounting-linked entries.',
        rows: _allMovements
            .map((m) => [
                  m.voucherNo,
                  m.type,
                  '${m.fromPoint} → ${m.toPoint}',
                  '${_formatNumber(m.qtyInBase, decimals: 2)} ${m.uom}'
                ])
            .toList(),
      );

  Widget _buildConsumptionReport() {
    if (_consumptions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.remove_circle_outline,
                size: 40, color: AppTheme.textMuted),
            SizedBox(height: 8),
            Text('No consumption recorded yet',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    final totalQty = _consumptions.fold<double>(
        0, (sum, c) => sum + c.quantity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _QuickMetric(
                label: 'Entries',
                value: '${_consumptions.length}',
                icon: Icons.receipt_long_outlined,
                color: AppTheme.info),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickMetric(
                  label: 'Total Qty',
                  value: _formatNumber(totalQty, decimals: 1),
                  icon: Icons.numbers,
                  color: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReportCard(
          title: 'Consumption Report',
          subtitle: 'Batch quantity consumed with proof, newest first.',
          rows: _consumptions
              .take(30)
              .map((c) => [
                    c.batchCode,
                    c.itemName,
                    '${_formatNumber(c.quantity, decimals: 1)} · ${c.stockPointName}',
                    c.reason
                  ])
              .toList(),
        ),
      ],
    );
  }

  Widget _pointDropdown(String label, AquaStockPoint? value,
      ValueChanged<AquaStockPoint?> onChanged,
      {bool allowExternal = false, bool allowConsumption = false}) {
    return DropdownButtonFormField<AquaStockPoint?>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowExternal)
          const DropdownMenuItem<AquaStockPoint?>(
              value: null, child: Text('External')),
        if (allowConsumption)
          const DropdownMenuItem<AquaStockPoint?>(
              value: null, child: Text('Ledger / Consumption')),
        ..._operationalPoints.map((p) => DropdownMenuItem<AquaStockPoint?>(
            value: p,
            child: Text(p.locationCode, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
      validator: (_) {
        if (_voucherType == AquaVoucherType.receipt &&
            label == 'To' &&
            _entryToPoint == null) return 'Required';
        if (_voucherType == AquaVoucherType.transfer &&
            (_entryFromPoint == null || _entryToPoint == null))
          return 'Required';
        if (_voucherType != AquaVoucherType.receipt &&
            _voucherType != AquaVoucherType.transfer &&
            label == 'From' &&
            _entryFromPoint == null) return 'Required';
        return null;
      },
    );
  }

  Widget _buildMovementFeed({int limit = 5}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Movement Analysis',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          _MiniTag('append-only', AppTheme.success),
        ]),
        const SizedBox(height: 10),
        ..._allMovements.take(limit).map((m) => _MovementFeedTile(
            movement: m, onTap: () => _showMovementDetails(m))),
      ]);

  Future<void> _postVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _entryItem;
    final uom = _entryUom;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (item == null || uom == null || qty <= 0) return;
    if (_voucherType == AquaVoucherType.receipt) {
      _showSnack(
          'Receipt creation needs supplier/GIN intake fields. Use GIN for new stock receipts.',
          AppTheme.warning,
          Icons.info_outline);
      return;
    }
    if (_voucherType == AquaVoucherType.transfer &&
        _entryFromPoint?.id == _entryToPoint?.id) {
      _showSnack('From and To stock points cannot be the same for transfer.',
          AppTheme.danger, Icons.error_outline);
      return;
    }
    final available = _entryFromPoint == null
        ? double.infinity
        : _qtyFor(item.id, _entryFromPoint!.id);
    if (_voucherType != AquaVoucherType.receipt &&
        available.isFinite &&
        uom.toBase(qty) > available) {
      _showSnack(
          'Insufficient stock. Available: ${_formatNumber(available, decimals: 2)} ${item.primaryUom}.',
          AppTheme.danger,
          Icons.error_outline);
      return;
    }
    final matchingBatches = _batches
        .where((batch) =>
            batch.itemId == item.id &&
            (_entryFromPoint == null ||
                batch.stockPointId == _entryFromPoint!.id) &&
            batch.currentQty > 0)
        .toList();
    if (matchingBatches.isEmpty) {
      _showSnack('No live batch stock is available for this item/source.',
          AppTheme.danger, Icons.error_outline);
      return;
    }
    setState(() => _savingVoucher = true);

    final now = DateTime.now();
    final voucherNo = _makeVoucherNo(_voucherType, now);
    final baseQty = uom.toBase(qty);
    final batch = matchingBatches.first;
    try {
      await _stockRepo.issueBatchStock(
        itemId: item.id,
        batchBalanceId: _batchBalanceIdFor(batch),
        batchId: batch.batchCode,
        stockPointId: batch.stockPointId,
        quantity: baseQty,
        looseQuantity: 0,
        movementType: _voucherLabel(_voucherType).toLowerCase(),
        reason: _noteCtrl.text.trim(),
        referenceId: voucherNo,
        toStockPointId: _entryToPoint?.id,
      );
      await _loadLiveStock();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingVoucher = false);
      _showSnack('Stock movement failed: $error', AppTheme.danger,
          Icons.error_outline);
      return;
    }
    if (!mounted) return;
    setState(() {
      _noteCtrl.clear();
      _savingVoucher = false;
    });
    _showSnack('$voucherNo recorded against ${batch.batchCode}.',
        AppTheme.success, Icons.check_circle_outline);
  }

  Future<void> _syncNow() async {
    if (_syncState == AquaSyncState.syncing) return;
    setState(() {
      _syncState = AquaSyncState.syncing;
      _lastSyncError = null;
    });
    await _loadLiveStock();
    if (!mounted) return;
    setState(() {
      _syncState = AquaSyncState.success;
      _lastSyncTs = 'Just now';
      _serverCursor = 'chg_${DateTime.now().millisecondsSinceEpoch % 1000000}';
    });
    _showSnack(
        'Live stock refreshed.', AppTheme.success, Icons.cloud_done_outlined);
  }

  Future<void> _simulatePullRefresh() async {
    await _loadLiveStock();
    if (!mounted) return;
    setState(() {
      _lastSyncTs = 'Just now';
      _serverCursor = 'chg_${DateTime.now().millisecondsSinceEpoch % 1000000}';
      _syncState = AquaSyncState.idle;
    });
  }

  void _applyVoucherDefaults() {
    final firstPoint =
        _operationalPoints.isEmpty ? null : _operationalPoints.first;
    final secondPoint =
        _operationalPoints.length > 1 ? _operationalPoints[1] : firstPoint;
    switch (_voucherType) {
      case AquaVoucherType.receipt:
        _entryFromPoint = null;
        _entryToPoint = firstPoint;
        break;
      case AquaVoucherType.issue:
      case AquaVoucherType.mortality:
      case AquaVoucherType.harvest:
      case AquaVoucherType.adjustment:
      case AquaVoucherType.physicalVerification:
        _entryFromPoint = firstPoint;
        _entryToPoint = null;
        break;
      case AquaVoucherType.transfer:
        _entryFromPoint = firstPoint;
        _entryToPoint = secondPoint;
        break;
    }
  }

  void _showMovementDetails(AquaMovementLine m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.voucherNo,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              _DetailLine('Type', m.type),
              _DetailLine('Item', m.itemName),
              _DetailLine('Movement', '${m.fromPoint} → ${m.toPoint}'),
              _DetailLine('Batch', m.batchCode),
              _DetailLine('Qty in base UoM',
                  '${_formatNumber(m.qtyInBase, decimals: 3)} ${m.uom}'),
              _DetailLine('Idempotency key', m.idempotencyKey),
              _DetailLine('Payload hash', m.payloadHash),
              _DetailLine('Status', m.synced ? 'Synced' : 'Pending sync'),
            ]),
      ),
    );
  }

  List<AquaStockItem> _filteredItems() {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((i) {
      final groupOk = _groupFilter == 'All' || i.group == _groupFilter;
      final lowOk = !_showLowOnly || _isItemLow(i);
      final searchOk = q.isEmpty ||
          '${i.name} ${i.code} ${i.group} ${i.category}'
              .toLowerCase()
              .contains(q);
      return groupOk && lowOk && searchOk;
    }).toList();
  }

  List<AquaUom> _allowedUomsFor(AquaStockItem? item) {
    if (item == null) return _uoms;
    return _uoms
        .where((u) =>
            u.code == item.primaryUom ||
            u.code == item.purchaseUom ||
            u.baseCode == item.primaryUom)
        .toList();
  }

  double get _calculatedBaseQty {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return (_entryUom ?? _uoms.first).toBase(qty);
  }

  double _qtyFor(String itemId, String pointId) => _batches
      .where((b) => b.itemId == itemId && b.stockPointId == pointId)
      .fold<double>(0, (sum, b) => sum + b.currentQty);
  double _totalQtyForItem(String itemId) => _batches
      .where((b) => b.itemId == itemId)
      .fold<double>(0, (sum, b) => sum + b.currentQty);
  double _biomassFor(String itemId, String pointId) => _batches
      .where((b) => b.itemId == itemId && b.stockPointId == pointId)
      .fold<double>(0, (sum, b) => sum + b.biomassKg);
  bool _isItemLow(AquaStockItem item) =>
      item.reorderLevel > 0 && _totalQtyForItem(item.id) <= item.reorderLevel;

  Color _natureColor(String nature) {
    switch (nature) {
      case 'live':
        return const Color(0xFF0F766E);
      case 'consumable':
        return AppTheme.warning;
      case 'harvest':
        return const Color(0xFFFF6B6B);
      case 'equipment':
        return AppTheme.textSecondary;
      default:
        return AppTheme.primary;
    }
  }

  String _natureLabel(String nature) => nature.isEmpty
      ? nature
      : '${nature[0].toUpperCase()}${nature.substring(1)}';

  String _voucherLabel(AquaVoucherType type) {
    switch (type) {
      case AquaVoucherType.receipt:
        return 'Receipt';
      case AquaVoucherType.issue:
        return 'Issue';
      case AquaVoucherType.transfer:
        return 'Transfer';
      case AquaVoucherType.mortality:
        return 'Mortality';
      case AquaVoucherType.harvest:
        return 'Harvest';
      case AquaVoucherType.adjustment:
        return 'Adjustment';
      case AquaVoucherType.physicalVerification:
        return 'Physical Verification';
    }
  }

  String _makeVoucherNo(AquaVoucherType type, DateTime now) {
    final prefix = switch (type) {
      AquaVoucherType.receipt => 'RCP',
      AquaVoucherType.issue => 'ISS',
      AquaVoucherType.transfer => 'TRF',
      AquaVoucherType.mortality => 'MOR',
      AquaVoucherType.harvest => 'HAR',
      AquaVoucherType.adjustment => 'ADJ',
      AquaVoucherType.physicalVerification => 'PHY',
    };
    return 'STK-$prefix-${now.year}-${(now.millisecondsSinceEpoch % 90000 + 10000)}';
  }

  String _makeBatchCode(AquaStockItem item, DateTime now) {
    final point = _entryToPoint ?? _entryFromPoint;
    final loc = point?.locationCode.replaceAll('-', '') ?? 'LEDGER';
    return '${item.code}-$loc-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatNumber(double value, {int decimals = 1}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final rgx = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final whole = parts.first.replaceAllMapped(rgx, (m) => ',');
    if (decimals == 0) return whole;
    final frac =
        parts.length > 1 ? parts.last.replaceFirst(RegExp(r'0+$'), '') : '';
    return frac.isEmpty ? whole : '$whole.$frac';
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg))
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  const _KpiCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 18)),
            const Spacer(),
            Icon(Icons.trending_up_rounded,
                color: color.withOpacity(0.7), size: 16),
          ]),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: color),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis),
          Text(subtitle,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _SyncPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SyncPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: color))
        ]),
      );
}

class _QuickMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _QuickMetric(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      );
}

class _MatrixCell extends StatelessWidget {
  final double qty, biomassKg;
  final String uom;
  final bool isLow;
  const _MatrixCell(
      {required this.qty,
      required this.uom,
      required this.biomassKg,
      required this.isLow});

  @override
  Widget build(BuildContext context) {
    if (qty <= 0)
      return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    final color = isLow ? AppTheme.danger : AppTheme.success;
    final formatted = qty >= 100000
        ? '${(qty / 100000).toStringAsFixed(2)}L'
        : qty >= 1000
            ? '${(qty / 1000).toStringAsFixed(1)}k'
            : qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$formatted $uom',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color),
                overflow: TextOverflow.ellipsis),
            if (biomassKg > 0)
              Text('${biomassKg.toStringAsFixed(0)} kg bio',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

class _CategoryItemTile extends StatelessWidget {
  final AquaStockItem item;
  final double qty;
  final Color color;
  const _CategoryItemTile(
      {required this.item, required this.qty, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          _NatureDot(color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${item.category} · ${item.code}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
                '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} ${item.primaryUom}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            _MiniTag(item.stockNature, color),
          ]),
        ]),
      );
}

class _BatchCard extends StatelessWidget {
  final AquaBatchBalance batch;
  final AquaStockItem item;
  final AquaStockPoint point;
  const _BatchCard(
      {required this.batch, required this.item, required this.point});

  @override
  Widget build(BuildContext context) {
    final color = batch.isLow ? AppTheme.danger : AppTheme.success;
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(item.name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis)),
          _MiniTag(batch.synced ? 'synced' : 'pending',
              batch.synced ? AppTheme.success : AppTheme.warning,
              icon: batch.synced
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined),
        ]),
        const SizedBox(height: 4),
        Text('${batch.batchCode} · ${point.name}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _InlineMetric(
                  'Current',
                  '${batch.currentQty.toStringAsFixed(0)} ${item.primaryUom}',
                  color)),
          Expanded(
              child: _InlineMetric(
                  'Biomass',
                  item.trackAvgWeight
                      ? '${batch.biomassKg.toStringAsFixed(1)} kg'
                      : 'N/A',
                  AppTheme.info)),
          Expanded(
              child: _InlineMetric(
                  'Survival',
                  '${batch.survivalPct.toStringAsFixed(1)}%',
                  batch.survivalPct < 95
                      ? AppTheme.warning
                      : AppTheme.success)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MiniTag(
              'FCR ${batch.fcr == 0 ? 'N/A' : batch.fcr.toStringAsFixed(2)}',
              AppTheme.primary),
          _MiniTag('Harvest: ${batch.expectedHarvestDate}', AppTheme.info),
          _MiniTag('Mortality ${batch.mortalityCount.toStringAsFixed(0)}',
              AppTheme.warning),
        ]),
      ]),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InlineMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis),
      ]);
}

class _MovementFeedTile extends StatelessWidget {
  final AquaMovementLine movement;
  final VoidCallback? onTap;
  const _MovementFeedTile({required this.movement, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = movement.synced ? AppTheme.success : AppTheme.warning;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(
                  movement.synced
                      ? Icons.check_circle_outline
                      : Icons.schedule_outlined,
                  color: color,
                  size: 19)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(movement.itemName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis)),
                  _MiniTag(movement.type, color),
                ]),
                const SizedBox(height: 3),
                Text(
                    '${movement.fromPoint} → ${movement.toPoint} · ${movement.qtyInBase.toStringAsFixed(movement.qtyInBase.truncateToDouble() == movement.qtyInBase ? 0 : 2)} ${movement.uom} · ${movement.date}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
                Text(movement.note,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
              ])),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textMuted, size: 18),
        ]),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title, subtitle;
  final List<List<String>> rows;
  const _ReportCard(
      {required this.title, required this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) => _CardShell(
        padding: const EdgeInsets.all(0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(subtitle,
                style:
                    const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ),
          const Divider(height: 1),
          ...rows.map((r) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: Text(r[0],
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 3,
                      child: Text(r.length > 1 ? r[1] : '',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 3,
                      child: Text(r.length > 2 ? r[2] : '',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis)),
                  Expanded(
                      flex: 2,
                      child: Text(r.length > 3 ? r[3] : '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary),
                          overflow: TextOverflow.ellipsis)),
                ]),
              )),
        ]),
      );
}

class _NatureDot extends StatelessWidget {
  final Color color;
  const _NatureDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DetailLine extends StatelessWidget {
  final String label, value;
  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 112,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary))),
        ]),
      );
}

class _EmptyMini extends StatelessWidget {
  final String message;
  const _EmptyMini({required this.message});

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Center(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)))),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB — OTHER CONSUMABLES
// ══════════════════════════════════════════════════════════════════════════════
class OtherConsumableRecord {
  final String id;
  final String itemName;
  final String itemCode;
  final String uom;
  final String reason;
  final DateTime submittedAt;
  final List<OtherConsumableAllocation> allocations;
  final String status;
  final String? photoName;

  const OtherConsumableRecord({
    required this.id,
    required this.itemName,
    required this.itemCode,
    required this.uom,
    required this.reason,
    required this.submittedAt,
    required this.allocations,
    this.status = 'Submitted to HOD',
    this.photoName,
  });

  double get totalQty =>
      allocations.fold<double>(0, (sum, a) => sum + a.quantity);
}

class OtherConsumableAllocation {
  final String batchBalanceId;
  final String itemId;
  final String stockPointId;
  final String stockPointName;
  final String location;
  final String batchId;
  final double availableQty;
  final double looseQty;
  final double quantity;

  const OtherConsumableAllocation({
    required this.batchBalanceId,
    required this.itemId,
    required this.stockPointId,
    required this.stockPointName,
    required this.location,
    required this.batchId,
    required this.availableQty,
    required this.looseQty,
    required this.quantity,
  });
}

class _OtherConsumablesTab extends StatefulWidget {
  const _OtherConsumablesTab();

  @override
  State<_OtherConsumablesTab> createState() => _OtherConsumablesTabState();
}

class _OtherConsumablesTabState extends State<_OtherConsumablesTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _stockRepo = StockInventoryRepository();

  StockInventoryItem? _selectedItem;
  RealtimeChannel? _stockChannel;
  List<StockInventoryItem> _liveItems = [];
  List<StockBatchBalance> _liveBatches = [];
  PickedDeviceFile? _photo;
  final Map<String, OtherConsumableAllocation> _selectedAllocations = {};
  final List<OtherConsumableRecord> _submittedRecords = [];
  bool _loadingStock = true;
  bool _isSubmitting = false;
  String? _stockError;
  String _purposeFilter = 'All';

  static const List<String> _purposeFilters = [
    'All',
    'Maintenance',
    'Repair Work',
    'Emergency Use',
    'Trial / Testing',
    'Cleaning',
    'Other Farm Purpose',
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveStock();
    _stockChannel = _stockRepo.watchBatchBalances(_loadLiveStock);
  }

  @override
  void dispose() {
    _stockRepo.stopWatching(_stockChannel);
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLiveStock() async {
    try {
      final items = await _stockRepo.fetchItems();
      final batches = await _stockRepo.fetchBatchBalances();
      if (!mounted) return;
      setState(() {
        _liveItems = items;
        _liveBatches = batches;
        _loadingStock = false;
        _stockError = null;
        _selectedAllocations.removeWhere((key, allocation) {
          final live = _liveBatches.where((batch) => batch.id == key);
          if (live.isEmpty) return true;
          return allocation.quantity > live.first.availableQty;
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingStock = false;
        _stockError =
            'Live stock is unavailable. Check Supabase stock tables and realtime policies.';
      });
    }
  }

  List<StockInventoryItem> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _liveItems.where((item) {
      final text =
          '${item.name} ${item.code} ${item.group} ${item.category} ${item.brand}'
              .toLowerCase();
      return q.isEmpty || text.contains(q);
    }).toList();
  }

  double get _totalSelectedQty =>
      _selectedAllocations.values.fold<double>(0, (sum, a) => sum + a.quantity);

  List<StockBatchBalance> get _availableBatches {
    final item = _selectedItem;
    if (item == null) return const [];
    return _liveBatches
        .where((batch) => batch.itemId == item.id && batch.availableQty > 0)
        .toList();
  }

  void _selectItem(StockInventoryItem? item) {
    setState(() {
      _selectedItem = item;
      _selectedAllocations.clear();
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await pickHodMapDeviceFile();
    if (!mounted || picked == null) return;
    if (picked.bytes.isEmpty || !_isPhotoExtension(picked.extension)) {
      _showSnack(
          'Choose a JPG or PNG photo.', AppTheme.danger, Icons.error_outline);
      return;
    }
    setState(() => _photo = picked);
    _showSnack('Photo attached: ${picked.name}', AppTheme.success,
        Icons.check_circle_outline);
  }

  void _removePhoto() => setState(() => _photo = null);

  bool _isPhotoExtension(String extension) {
    final ext = extension.toLowerCase();
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  Future<void> _openQuantitySheet(StockBatchBalance batch) async {
    final item = _selectedItem;
    if (item == null) {
      _showSnack('Choose an item first.', AppTheme.warning, Icons.info_outline);
      return;
    }

    final available = batch.availableQty;
    final existing = _selectedAllocations[batch.id];
    final ctrl = TextEditingController(
      text: existing == null ? '' : _cleanNumber(existing.quantity),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(batch.stockPointName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    '${item.name} · ${batch.location} · Batch ${batch.batchId}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 14),
                _InfoBox(
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.info,
                  bgColor: AppTheme.infoBg,
                  text:
                      'Available stock: ${_cleanNumber(available)} ${item.uom}. Enter quantity consumed for other purpose.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
                  ],
                  decoration: InputDecoration(
                    labelText: 'Consumed Quantity',
                    suffixText: item.uom,
                    prefixIcon: const Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  if (existing != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _selectedAllocations.remove(batch.id));
                          Navigator.pop(ctx);
                          _showSnack('Removed ${batch.batchId} from selection.',
                              AppTheme.warning, Icons.remove_circle_outline);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final qty = double.tryParse(ctrl.text.trim()) ?? 0;
                        if (qty <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Enter a valid quantity.'),
                            backgroundColor: AppTheme.danger,
                          ));
                          return;
                        }
                        if (qty > available) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(
                                'Quantity cannot exceed ${_cleanNumber(available)} ${item.uom}.'),
                            backgroundColor: AppTheme.danger,
                          ));
                          return;
                        }
                        setState(() {
                          _selectedAllocations[batch.id] =
                              OtherConsumableAllocation(
                            batchBalanceId: batch.id,
                            itemId: batch.itemId,
                            stockPointId: batch.stockPointId,
                            stockPointName: batch.stockPointName,
                            location: batch.location,
                            batchId: batch.batchId,
                            availableQty: available,
                            looseQty: batch.looseQty,
                            quantity: qty,
                          );
                        });
                        Navigator.pop(ctx);
                        _showSnack('Quantity added from ${batch.batchId}.',
                            AppTheme.success, Icons.check_circle_outline);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Add Quantity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ]),
        );
      },
    );
    ctrl.dispose();
  }

  Future<void> _submitOtherConsumption() async {
    if (_selectedItem == null) {
      _showSnack(
          'Choose item first.', AppTheme.warning, Icons.inventory_2_outlined);
      return;
    }
    if (_selectedAllocations.isEmpty) {
      _showSnack('Select at least one stock point and enter quantity.',
          AppTheme.warning, Icons.warehouse_outlined);
      return;
    }
    if (_photo == null) {
      _showSnack('Attach a photo before submitting.', AppTheme.warning,
          Icons.add_a_photo_outlined);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final item = _selectedItem!;
    final now = DateTime.now();
    final recordId =
        'OTC-${now.year}-${now.millisecondsSinceEpoch % 90000 + 10000}';

    setState(() => _isSubmitting = true);
    try {
      for (final allocation in _selectedAllocations.values) {
        await _stockRepo.issueBatchStock(
          itemId: allocation.itemId,
          batchBalanceId: allocation.batchBalanceId,
          batchId: allocation.batchId,
          stockPointId: allocation.stockPointId,
          quantity: allocation.quantity,
          looseQuantity: 0,
          movementType: 'other_consumption',
          reason: _reasonCtrl.text.trim(),
          referenceId: recordId,
          photoName: _photo?.name,
        );
      }
      await _loadLiveStock();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack(
          'Stock update failed: $error', AppTheme.danger, Icons.error_outline);
      return;
    }
    if (!mounted) return;

    final record = OtherConsumableRecord(
      id: recordId,
      itemName: item.name,
      itemCode: item.code,
      uom: item.uom,
      reason: _reasonCtrl.text.trim(),
      submittedAt: now,
      allocations: _selectedAllocations.values.toList(growable: false),
      photoName: _photo?.name,
    );

    setState(() {
      _submittedRecords.insert(0, record);
      _selectedItem = null;
      _photo = null;
      _selectedAllocations.clear();
      _purposeFilter = 'All';
      _reasonCtrl.clear();
      _searchCtrl.clear();
      _isSubmitting = false;
    });
    _showSnack('${record.id} submitted to Reports and HOD.', AppTheme.success,
        Icons.send_outlined);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildItemStep(),
          if (_selectedItem != null) ...[
            const SizedBox(height: 16),
            _buildItemStockStep(),
            const SizedBox(height: 16),
            _buildStockPointStep(),
            const SizedBox(height: 16),
            _buildReasonStep(),
            const SizedBox(height: 16),
            _buildPhotoStep(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
          ],
          if (_submittedRecords.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildSubmittedSection(),
          ],
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.danger.withOpacity(0.12),
              AppTheme.warning.withOpacity(0.07)
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.danger.withOpacity(0.18)),
          ),
          child: const Icon(Icons.outbound_outlined,
              color: AppTheme.danger, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Other Consumables',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text(
                'Record stock consumed for other farm purposes and send to HOD reports.',
                style:
                    TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]);

  Widget _buildSummaryCard() {
    final totalSubmitted = _submittedRecords.length;
    final submittedQty =
        _submittedRecords.fold<double>(0, (sum, r) => sum + r.totalQty);
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _QuickMetric(
                  label: 'Submitted',
                  value: '$totalSubmitted records',
                  icon: Icons.fact_check_outlined,
                  color: AppTheme.success)),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickMetric(
                  label: 'Selected Qty',
                  value: _selectedItem == null
                      ? '0'
                      : '${_cleanNumber(_totalSelectedQty)} ${_selectedItem!.uom}',
                  icon: Icons.shopping_bag_outlined,
                  color: AppTheme.primary)),
        ]),
        const SizedBox(height: 12),
        _InfoBox(
          icon: _stockError == null
              ? Icons.sensors_outlined
              : Icons.error_outline,
          color: _stockError == null ? AppTheme.info : AppTheme.danger,
          bgColor: _stockError == null ? AppTheme.infoBg : AppTheme.dangerBg,
          text: _stockError ??
              'Live batch-wise stock is loaded from Supabase and updates when stock_batch_balances changes.',
        ),
        if (submittedQty > 0) ...[
          const SizedBox(height: 10),
          Text(
              'Total submitted quantity this session: ${_cleanNumber(submittedQty)} units across selected UoMs.',
              style: const TextStyle(
                  fontSize: 11.5, color: AppTheme.textSecondary)),
        ],
      ]),
    );
  }

  Widget _buildItemStep() => _buildStepCard(
        step: '1',
        title: 'Others — Choose Item',
        color: AppTheme.danger,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_loadingStock)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Search available stock item, code, group, brand',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<StockInventoryItem>(
            value: _selectedItem,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Choose Item',
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
            ),
            items: _filteredItems
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text('${item.name} · ${item.uom}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged:
                _loadingStock || _stockError != null ? null : _selectItem,
          ),
          if (!_loadingStock && _filteredItems.isEmpty) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.inventory_2_outlined,
              color: AppTheme.warning,
              bgColor: AppTheme.warningBg,
              text:
                  'No live stock items found. Add records in stock_items and stock_batch_balances.',
            ),
          ],
          if (_selectedItem != null) ...[
            const SizedBox(height: 12),
            _SelectedItemCard(item: _selectedItem!),
          ],
        ]),
      );

  Widget _buildItemStockStep() {
    final item = _selectedItem;
    if (item == null) return const SizedBox.shrink();

    final rows = _availableBatches;
    final totalStock =
        rows.fold<double>(0, (sum, row) => sum + row.availableQty);
    final totalLoose = rows.fold<double>(0, (sum, row) => sum + row.looseQty);

    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: _QuickMetric(
              label: 'Stock',
              value: '${_cleanNumber(totalStock)} ${item.uom}',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickMetric(
              label: 'Loose Items',
              value: '${_cleanNumber(totalLoose)} ${item.uom}',
              icon: Icons.scatter_plot_outlined,
              color: AppTheme.warning,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(
            child: Text('Batch-wise Stock',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
          ),
          _MiniTag(item.code, AppTheme.info),
        ]),
        const SizedBox(height: 10),
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.qr_code_2_outlined,
                    size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${row.batchId} · ${row.stockPointName}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                _MiniTag('${_cleanNumber(row.availableQty)} ${item.uom}',
                    AppTheme.success),
              ]),
            )),
        if (rows.isEmpty)
          _InfoBox(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.warning,
            bgColor: AppTheme.warningBg,
            text: 'This item has no available live batch stock.',
          ),
      ]),
    );
  }

  Widget _buildStockPointStep() => _buildStepCard(
        step: '2',
        title: 'Available Batches',
        color: AppTheme.primary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tap a live batch to enter consumed quantity.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ..._availableBatches.map((batch) {
            final selected = _selectedAllocations[batch.id];
            final available = batch.availableQty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _openQuantitySheet(batch),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected == null
                        ? AppTheme.surfaceCard
                        : AppTheme.successBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected == null
                            ? AppTheme.border
                            : AppTheme.success.withOpacity(0.35)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (selected == null
                                ? AppTheme.primary
                                : AppTheme.success)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                          selected == null
                              ? Icons.warehouse_outlined
                              : Icons.check_circle_outline,
                          color: selected == null
                              ? AppTheme.primary
                              : AppTheme.success,
                          size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(batch.stockPointName,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 3),
                          Text(
                              '${batch.location} · Batch ${batch.batchId} · Available ${_cleanNumber(available)} ${_selectedItem!.uom}',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ])),
                    if (selected != null)
                      _MiniTag(
                          '${_cleanNumber(selected.quantity)} ${_selectedItem!.uom}',
                          AppTheme.success)
                    else
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textMuted),
                  ]),
                ),
              ),
            );
          }),
          if (_selectedAllocations.isNotEmpty) ...[
            const SizedBox(height: 4),
            _InfoBox(
              icon: Icons.calculate_outlined,
              color: AppTheme.success,
              bgColor: AppTheme.successBg,
              text:
                  'Total selected: ${_cleanNumber(_totalSelectedQty)} ${_selectedItem!.uom} from ${_selectedAllocations.length} stock point${_selectedAllocations.length > 1 ? 's' : ''}.',
            ),
          ],
          if (_availableBatches.isEmpty)
            _InfoBox(
              icon: Icons.inventory_2_outlined,
              color: AppTheme.warning,
              bgColor: AppTheme.warningBg,
              text:
                  'No batch has positive available stock for this selected item.',
            ),
        ]),
      );

  Widget _buildReasonStep() => _buildStepCard(
        step: '3',
        title: 'Reason & Purpose',
        color: AppTheme.warning,
        child: Column(children: [
          DropdownButtonFormField<String>(
            value: _purposeFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Purpose Type',
              prefixIcon: Icon(Icons.category_outlined, size: 20),
            ),
            items: _purposeFilters
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() {
              _purposeFilter = v ?? 'All';
              if (_purposeFilter != 'All' && _reasonCtrl.text.trim().isEmpty) {
                _reasonCtrl.text = _purposeFilter;
              }
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Example: emergency repair of aerator near Pond-A1',
              prefixIcon: Icon(Icons.notes_outlined, size: 20),
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().length < 4)
                ? 'Enter clear reason for other consumption'
                : null,
          ),
        ]),
      );

  Widget _buildPhotoStep() => _buildStepCard(
        step: '4',
        title: 'Photo Upload',
        color: AppTheme.info,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: _photo == null ? AppTheme.info : AppTheme.success,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _photo == null ? AppTheme.infoBg : AppTheme.successBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _photo == null
                    ? const Row(children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: AppTheme.info, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Tap to upload consumption photo',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.info)),
                        ),
                      ])
                    : _SelectedPhotoPreview(
                        file: _photo!,
                        onRemove: _removePhoto,
                      ),
              ),
            ),
          ),
          if (_photo == null) ...[
            const SizedBox(height: 10),
            _InfoBox(
              icon: Icons.info_outline,
              color: AppTheme.warning,
              bgColor: AppTheme.warningBg,
              text: 'Photo proof is required before submitting this record.',
            ),
          ],
        ]),
      );

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitOtherConsumption,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_outlined),
          label: Text(
              _isSubmitting ? 'Submitting...' : 'Submit Other Consumption'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
        ),
      );

  Widget _buildSubmittedSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Submitted Other Consumables',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          _MiniTag('Reports + HOD', AppTheme.success,
              icon: Icons.verified_outlined),
        ]),
        const SizedBox(height: 10),
        ..._submittedRecords
            .map((record) => _OtherConsumableRecordTile(record: record)),
      ]);

  String _cleanNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg))
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }
}

class _SelectedItemCard extends StatelessWidget {
  final StockInventoryItem item;
  const _SelectedItemCard({required this.item});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.infoBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.info.withOpacity(0.22)),
        ),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppTheme.info, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    '${item.code} · ${item.group} / ${item.category} · ${item.brand}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ])),
          _MiniTag(item.uom, AppTheme.info),
        ]),
      );
}

class _SelectedPhotoPreview extends StatelessWidget {
  final PickedDeviceFile file;
  final VoidCallback onRemove;

  const _SelectedPhotoPreview({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final typed_data.Uint8List bytes = file.bytes;
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          bytes,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(file.name,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(_formatFileSize(file.size),
              style:
                  const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        ]),
      ),
      const SizedBox(width: 8),
      TextButton.icon(
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded, size: 16),
        label: const Text('Remove'),
        style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
      ),
    ]);
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final radius = Radius.circular(14);
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect.deflate(0.6), radius));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 7).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _OtherConsumableRecordTile extends StatelessWidget {
  final OtherConsumableRecord record;
  const _OtherConsumableRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final h = record.submittedAt.hour.toString().padLeft(2, '0');
    final m = record.submittedAt.minute.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.outbound_outlined,
                color: AppTheme.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(record.itemName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis),
                Text('${record.id} · Today $h:$m',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis),
              ])),
          _MiniTag(record.status, AppTheme.success),
        ]),
        const SizedBox(height: 10),
        Text('Reason: ${record.reason}',
            style:
                const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MiniTag(
              'Total ${record.totalQty.toStringAsFixed(record.totalQty.truncateToDouble() == record.totalQty ? 0 : 2)} ${record.uom}',
              AppTheme.danger),
          _MiniTag(
              '${record.allocations.length} stock point${record.allocations.length > 1 ? 's' : ''}',
              AppTheme.info),
          _MiniTag(record.itemCode, AppTheme.textSecondary),
          if (record.photoName != null)
            _MiniTag(record.photoName!, AppTheme.success,
                icon: Icons.image_outlined),
        ]),
        const SizedBox(height: 8),
        ...record.allocations.map((a) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.subdirectory_arrow_right,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${a.stockPointName} · Batch ${a.batchId}',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                    '${a.quantity.toStringAsFixed(a.quantity.truncateToDouble() == a.quantity ? 0 : 2)} ${record.uom}',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ]),
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — RAISE ORDER (Modified to show only HOD raised orders)
// ══════════════════════════════════════════════════════════════════════════════
class _RaiseOrderTab extends StatelessWidget {
  final List<StockPoint> stockPoints;
  final List<StockMovement> movements;

  const _RaiseOrderTab({
    required this.stockPoints,
    required this.movements,
  });

  @override
  Widget build(BuildContext context) {
    final raisedOrders = _ordersFromMovements();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildOrderSummary(raisedOrders),
          const SizedBox(height: 18),
          if (raisedOrders.isEmpty)
            _buildEmptyState()
          else
            ...raisedOrders.map(
              (order) => _HODOrderTile(
                order: order,
                onTap: () => _showRaisedOrderDetails(context, order),
              ),
            ),
        ],
      ),
    );
  }

  List<RaisedOrderRecord> _ordersFromMovements() {
    final hodMovements = movements
        .where((movement) => movement.by.toLowerCase().contains('hod'))
        .toList();

    return List<RaisedOrderRecord>.generate(hodMovements.length, (index) {
      final movement = hodMovements[index];
      final stockPoint = stockPoints.isEmpty
          ? 'N/A'
          : stockPoints[index % stockPoints.length].name;
      return RaisedOrderRecord(
        id: 'ORD-2024-${(index + 1).toString().padLeft(3, '0')}',
        stockPoint: stockPoint,
        approvedBy: movement.by,
        approvedAt: _dateFromMovementLabel(movement.date),
        status: 'HOD Approved',
        items: [
          RaisedOrderItem(
            itemName: movement.item,
            batch: movement.batch,
            quantity: movement.quantity,
          ),
        ],
      );
    });
  }

  DateTime _dateFromMovementLabel(String label) {
    final now = DateTime.now();
    final lower = label.toLowerCase();
    if (lower.contains('yesterday')) {
      return now.subtract(const Duration(days: 1));
    }
    if (lower.contains('today')) return now;
    return now;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildHeader() => Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.warning.withOpacity(0.12),
              AppTheme.warning.withOpacity(0.06)
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.warning.withOpacity(0.18)),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add_shopping_cart,
              color: AppTheme.warning, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Raise Order',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text('Tap an approved order to view its full item list',
                style:
                    TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]);

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.infoBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppTheme.info, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOD Approved Orders Only',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.info)),
                SizedBox(height: 2),
                Text(
                    'Each order card opens a detailed item list with batch and quantity.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ]),
      );

  Widget _buildOrderSummary(List<RaisedOrderRecord> orders) {
    final totalItems =
        orders.fold<int>(0, (sum, order) => sum + order.totalItems);
    final totalQty =
        orders.fold<int>(0, (sum, order) => sum + order.totalQuantity);
    return Row(children: [
      Expanded(
        child: _QuickMetric(
          label: 'Approved Orders',
          value: '${orders.length}',
          icon: Icons.verified_outlined,
          color: AppTheme.success,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickMetric(
          label: 'Line Items',
          value: '$totalItems',
          icon: Icons.list_alt_rounded,
          color: AppTheme.warning,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _QuickMetric(
          label: 'Total Qty',
          value: '$totalQty',
          icon: Icons.inventory_2_outlined,
          color: AppTheme.info,
        ),
      ),
    ]);
  }

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        alignment: Alignment.center,
        child: Column(children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.add_shopping_cart,
                size: 48, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          const Text('No HOD Approved Orders',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Orders approved by HOD will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        ]),
      );

  void _showRaisedOrderDetails(
    BuildContext context,
    RaisedOrderRecord order,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: AppTheme.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Raised Order Details',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 2),
                        Text(order.id,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _MiniTag(order.status, AppTheme.success,
                      icon: Icons.verified_outlined),
                ]),
                const SizedBox(height: 16),
                _CardShell(
                  child: Column(children: [
                    _InfoLine(label: 'Stock Point', value: order.stockPoint),
                    const SizedBox(height: 8),
                    _InfoLine(label: 'Approved By', value: order.approvedBy),
                    const SizedBox(height: 8),
                    _InfoLine(
                        label: 'Approved On',
                        value: _formatDate(order.approvedAt)),
                    const SizedBox(height: 8),
                    _InfoLine(
                        label: 'Total Items', value: '${order.totalItems}'),
                    const SizedBox(height: 8),
                    _InfoLine(
                        label: 'Total Qty',
                        value: '${order.totalQuantity} units'),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Order Items',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                ...order.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.subtleShadow,
                    ),
                    child: Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text('${index + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.warning)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.itemName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 3),
                            Text('Batch: ${item.batch}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      Text('${item.quantity} ${item.unit}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textPrimary)),
                    ]),
                  );
                }),
                const SizedBox(height: 6),
                const HodApprovalBadge(
                    text: 'This raised order has been approved by HOD'),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HODOrderTile extends StatelessWidget {
  final RaisedOrderRecord order;
  final VoidCallback onTap;

  const _HODOrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: AppTheme.warning, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.id,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(order.stockPoint,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                _MiniTag('View Items', AppTheme.info,
                    icon: Icons.open_in_new_rounded),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child:
                      _InfoLine(label: 'Items', value: '${order.totalItems}'),
                ),
                Expanded(
                  child: _InfoLine(
                      label: 'Quantity', value: '${order.totalQuantity} units'),
                ),
              ]),
              const SizedBox(height: 8),
              _InfoLine(label: 'Approved By', value: order.approvedBy),
              const SizedBox(height: 12),
              const HodApprovalBadge(
                  text: 'Tap to view the complete raised-order item list'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  const _InfoLine(
      {required this.label, required this.value, this.compact = false});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 70 : 85,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary)),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — RETURN
// ══════════════════════════════════════════════════════════════════════════════
class _ReturnTab extends StatefulWidget {
  const _ReturnTab();

  @override
  State<_ReturnTab> createState() => _ReturnTabState();
}

class _ReturnTabState extends State<_ReturnTab> {
  final _formKey = GlobalKey<FormState>();
  final _stockRepo = StockInventoryRepository();
  RealtimeChannel? _stockChannel;

  StockPoint? _selectedStockPoint;
  final _batchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _loading = true;
  String? _loadError;

  List<StockPoint> _liveStockPoints = [];
  List<StockBatchBalance> _liveBalances = [];
  List<SubmissionRecord> _recentReturns = [];
  List<ReturnItemDraft> _returnItems = [];
  String _returnId = _generateId('RET');

  static String _generateId(String prefix) {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return '$prefix-2024-$n';
  }

  static const List<String> _fallbackItems = [
    'Engine Oil',
    'Bolts & Nuts',
    'Hydraulic Fluid',
    'Grease',
    'Coolant',
  ];

  @override
  void initState() {
    super.initState();
    _stockChannel = _stockRepo.watchBatchBalances(_loadLive);
    _loadLive();
  }

  @override
  void dispose() {
    _stockRepo.stopWatching(_stockChannel);
    for (final item in _returnItems) {
      item.dispose();
    }
    _batchCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLive() async {
    try {
      final items = await _stockRepo.fetchItems();
      final balances = await _stockRepo.fetchBatchBalances();
      List<StockMovementRecord> movements = [];
      try {
        movements = await _stockRepo.fetchMovements(limit: 50);
      } catch (_) {
        // Movement history is best-effort; returns still load.
      }
      if (!mounted) return;
      setState(() {
        _liveBalances = balances;
        final byPoint = <String, StockPoint>{};
        for (final balance in balances) {
          final existing = byPoint[balance.stockPointName];
          if (existing == null) {
            byPoint[balance.stockPointName] = StockPoint(
              id: balance.stockPointId,
              name: balance.stockPointName,
              location: balance.location,
              batchId: balance.batchId,
              onHand: balance.availableQty.round(),
              todayUsage: 0,
              reorderLevel: 0,
              totalIn: 0,
              totalOut: 0,
            );
          }
        }
        _liveStockPoints = byPoint.values.toList();

        final names = <String>{for (final item in items) item.name};
        for (final fallback in _fallbackItems) {
          names.add(fallback);
        }
        for (final draft in _returnItems) {
          draft.dispose();
        }
        _returnItems = names
            .map((name) => ReturnItemDraft(itemName: name))
            .toList(growable: false);

        _recentReturns = movements
            .where((m) => m.movementType == 'return')
            .take(20)
            .map((m) => SubmissionRecord(
                  id: m.referenceId,
                  type: SubmissionType.returnStock,
                  stockPoint: m.stockPointId,
                  item: m.itemId,
                  quantity: m.quantity.round(),
                  purpose: m.reason,
                  submittedAt: m.createdAt ?? DateTime.now(),
                  status: 'Recorded',
                ))
            .toList();
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Live stock is unavailable: $error';
      });
    }
  }

  int get _selectedItemCount =>
      _returnItems.where((item) => item.selected).length;

  int get _selectedTotalQuantity => _returnItems
      .where((item) => item.selected)
      .fold<int>(0, (sum, item) => sum + item.quantity);

  Future<void> _submitReturn() async {
    final selectedItems = _returnItems.where((item) => item.selected).toList();

    if (selectedItems.isEmpty) {
      _showSnackbar('Select at least one item to return.', AppTheme.danger,
          Icons.error_outline);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final invalidQuantity = selectedItems.any((item) => item.quantity <= 0);
    if (invalidQuantity) {
      _showSnackbar('Enter valid quantity for every selected item.',
          AppTheme.danger, Icons.error_outline);
      return;
    }

    final stockPoint = _selectedStockPoint;
    if (stockPoint == null) {
      _showSnackbar('Please select a stock point.', AppTheme.danger,
          Icons.error_outline);
      return;
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final saved = <SubmissionRecord>[];
    String? failure;

    for (var index = 0; index < selectedItems.length; index++) {
      final item = selectedItems[index];
      final matches = _liveBalances.where((balance) =>
          balance.stockPointName.trim().toLowerCase() ==
              stockPoint.name.trim().toLowerCase() &&
          balance.itemName == item.itemName);
      if (matches.isEmpty) {
        failure = 'No stock balance for ${item.itemName} at '
            '${stockPoint.name}.';
        break;
      }
      final balance = matches.first;
      final ok = await _stockRepo.returnStock(
        siteId: null,
        balance: balance,
        quantity: item.quantity.toDouble(),
        reason: _reasonCtrl.text.trim().isEmpty
            ? 'Supervisor return'
            : _reasonCtrl.text.trim(),
        referenceId: '$_returnId-${index + 1}',
      );
      if (!ok) {
        failure = 'Failed to record return for ${item.itemName}.';
        break;
      }
      saved.add(SubmissionRecord(
        id: '$_returnId-${index + 1}',
        type: SubmissionType.returnStock,
        stockPoint: stockPoint.name,
        item: item.itemName,
        quantity: item.quantity,
        purpose:
            _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        submittedAt: now,
        status: 'Recorded',
      ));
    }

    if (!mounted) return;
    if (failure != null) {
      setState(() => _isSubmitting = false);
      _showSnackbar(failure, AppTheme.danger, Icons.error_outline);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _recentReturns.insertAll(0, saved);
    });

    _showSnackbar(
      'Return $_returnId recorded with ${saved.length} item${saved.length == 1 ? '' : 's'}!',
      AppTheme.success,
      Icons.check_circle_outline,
    );
    unawaited(_loadLive());
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _selectedStockPoint = null;
      _returnId = _generateId('RET');
      for (final item in _returnItems) {
        item.selected = false;
        item.quantityController.clear();
      }
    });
    _batchCtrl.clear();
    _reasonCtrl.clear();
  }

  void _showSnackbar(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 40, color: AppTheme.textMuted),
              const SizedBox(height: 10),
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _loadLive();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAutoIdBanner(_returnId, AppTheme.success, AppTheme.successBg,
              Icons.loop_outlined),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1',
            title: 'Source Stock Point & Batch',
            color: AppTheme.success,
            child: _buildSourceFields(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Select Return Items',
            color: AppTheme.success,
            child: _buildReturnDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Submit for HOD Approval',
            color: AppTheme.success,
            child: _buildSubmissionInfo(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          if (_recentReturns.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Submitted This Session',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            ..._recentReturns.map((r) => _SubmissionTile(record: r)),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: const Icon(Icons.assignment_return,
              color: AppTheme.success, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Return Stock',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          Text('Select multiple items and enter quantity for each',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ])),
      ]);

  Widget _buildSourceFields() => Column(children: [
        DropdownButtonFormField<StockPoint>(
          value: _selectedStockPoint,
          hint: const Text('Select originating stock point',
              style: TextStyle(fontSize: 13)),
          isExpanded: true,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.warehouse_outlined, size: 18)),
          items: _liveStockPoints
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(
                      '${p.name} · Available ${p.remaining}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() {
              _selectedStockPoint = v;
              if (v != null) _batchCtrl.text = v.batchId;
            });
          },
          validator: (v) => v == null ? 'Please select a stock point' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _batchCtrl,
          decoration: const InputDecoration(
            labelText: 'Original Batch ID',
            hintText: 'e.g. B-042',
            prefixIcon: Icon(Icons.link_outlined, size: 18),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter batch ID' : null,
        ),
        const SizedBox(height: 10),
        const HodApprovalBadge(),
      ]);

  Widget _buildReturnDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.info.withOpacity(0.18)),
            ),
            child: Row(children: [
              const Icon(Icons.playlist_add_check_rounded,
                  color: AppTheme.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_selectedItemCount selected • Total quantity: $_selectedTotalQuantity',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.info,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          ..._returnItems.map(_buildReturnItemSelector),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Return Reason',
              hintText: 'Explain why stock is being returned…',
              prefixIcon: Icon(Icons.notes_outlined, size: 18),
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please provide a reason'
                : null,
          ),
        ],
      );

  Widget _buildReturnItemSelector(ReturnItemDraft item) {
    final selected = item.selected;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.successBg : AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              selected ? AppTheme.success.withOpacity(0.36) : AppTheme.border,
        ),
        boxShadow: selected ? AppTheme.subtleShadow : null,
      ),
      child: Row(children: [
        Checkbox(
          value: selected,
          activeColor: AppTheme.success,
          onChanged: (value) {
            setState(() {
              item.selected = value ?? false;
              if (!item.selected) item.quantityController.clear();
            });
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.itemName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 3),
              Text(
                _batchCtrl.text.trim().isEmpty
                    ? 'Batch will be linked after stock point selection'
                    : 'Batch: ${_batchCtrl.text.trim()}',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: TextFormField(
            controller: item.quantityController,
            enabled: selected,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Qty',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: (_) => setState(() {}),
            validator: (_) {
              if (!item.selected) return null;
              if (item.quantity <= 0) return 'Qty';
              return null;
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildSubmissionInfo() => Column(children: [
        const HodApprovalBadge(),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.info_outline,
          color: AppTheme.info,
          bgColor: AppTheme.infoBg,
          text:
              'Selected items are submitted together under one return action. Each line item keeps its own quantity for accurate HOD review.',
        ),
      ]);

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          child: _isSubmitting
              ? const _LoadingIndicator()
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.keyboard_return, size: 20),
                      SizedBox(width: 10),
                      Text('Submit Selected Items',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — GIN LIST
// ══════════════════════════════════════════════════════════════════════════════
class _GINTab extends StatelessWidget {
  final List<GINStockPointPending> ginStockPoints;
  const _GINTab({required this.ginStockPoints});

  @override
  Widget build(BuildContext context) {
    if (ginStockPoints.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: AppTheme.success.withOpacity(0.6)),
          const SizedBox(height: 16),
          const Text('No pending Goods Inward Notes',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
        ]),
      );
    }

    final totalBills =
        ginStockPoints.fold(0, (s, sp) => s + sp.pendingBills.length);

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        color: AppTheme.surface,
        child: Row(children: [
          _MiniTag('$totalBills Pending Bill${totalBills > 1 ? "s" : ""}',
              AppTheme.warning,
              icon: Icons.pending_actions),
          const Spacer(),
          Text(
              '${ginStockPoints.length} Stock Point${ginStockPoints.length > 1 ? "s" : ""}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ginStockPoints.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final sp = ginStockPoints[i];
            final totalItems =
                sp.pendingBills.fold(0, (s, b) => s + b.items.length);
            final hasShortage = sp.pendingBills.any((b) => b.items
                .any((it) => it.status == ReconciliationStatus.shortage));
            return _GINStockPointCard(
              stockPoint: sp,
              totalItems: totalItems,
              hasShortage: hasShortage,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => GINStockPointDetailsScreen(stockPoint: sp)),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _GINStockPointCard extends StatelessWidget {
  final GINStockPointPending stockPoint;
  final int totalItems;
  final bool hasShortage;
  final VoidCallback onTap;

  const _GINStockPointCard({
    required this.stockPoint,
    required this.totalItems,
    required this.hasShortage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: hasShortage
                  ? AppTheme.warning.withOpacity(0.4)
                  : AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child:
                const Icon(Icons.warehouse, color: AppTheme.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stockPoint.stockPointName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _MiniTag(
                    '${stockPoint.pendingBills.length} bill${stockPoint.pendingBills.length > 1 ? "s" : ""}',
                    AppTheme.info),
                _MiniTag('$totalItems items', AppTheme.textSecondary),
                if (hasShortage) _MiniTag('⚠ Shortage', AppTheme.warning),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.chevron_right,
                color: AppTheme.textMuted, size: 20),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GIN DRILL-DOWN — STOCK POINT DETAILS
// ══════════════════════════════════════════════════════════════════════════════
class GINStockPointDetailsScreen extends StatelessWidget {
  final GINStockPointPending stockPoint;
  const GINStockPointDetailsScreen({super.key, required this.stockPoint});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(stockPoint.stockPointName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: _InfoBox(
            icon: Icons.info_outline,
            color: AppTheme.info,
            bgColor: AppTheme.infoBg,
            text:
                '${stockPoint.pendingBills.length} bill${stockPoint.pendingBills.length > 1 ? "s" : ""} pending GIN verification',
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: stockPoint.pendingBills.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final bill = stockPoint.pendingBills[i];
              final shortages = bill.items
                  .where((it) => it.status == ReconciliationStatus.shortage)
                  .length;
              final matched = bill.items
                  .where((it) => it.status == ReconciliationStatus.matched)
                  .length;
              return _GINBillCard(
                bill: bill,
                shortages: shortages,
                matched: matched,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => GINBillDetailsScreen(bill: bill)),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _GINBillCard extends StatelessWidget {
  final GINBill bill;
  final int shortages, matched;
  final VoidCallback onTap;

  const _GINBillCard({
    required this.bill,
    required this.shortages,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: shortages > 0
                  ? AppTheme.warning.withOpacity(0.35)
                  : AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.receipt, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Bill #${bill.billNumber}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(bill.supplierName,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _MiniTag('${bill.items.length} items', AppTheme.info),
                  if (matched > 0)
                    _MiniTag('$matched matched', AppTheme.success),
                  if (shortages > 0)
                    _MiniTag('$shortages shortage', AppTheme.warning),
                ]),
              ])),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GIN BILL DETAILS
// ══════════════════════════════════════════════════════════════════════════════
class GINBillDetailsScreen extends StatefulWidget {
  final GINBill bill;
  const GINBillDetailsScreen({super.key, required this.bill});

  @override
  State<GINBillDetailsScreen> createState() => _GINBillDetailsScreenState();
}

class _GINBillDetailsScreenState extends State<GINBillDetailsScreen> {
  late final List<TextEditingController> _rcvdCtrl;

  final List<UploadedDocument> _docs = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rcvdCtrl = List.generate(widget.bill.items.length, (i) {
      final ctrl = TextEditingController(
          text: widget.bill.items[i].receivedQty.toStringAsFixed(0));
      ctrl.addListener(() {
        if (!mounted) return;
        final val = double.tryParse(ctrl.text);
        if (val != null && val >= 0) {
          setState(() {
            widget.bill.items[i].receivedQty = val;
            // Editing received qty changes the diff → action must be re-picked.
            widget.bill.items[i].actionTaken = null;
          });
        }
      });
      return ctrl;
    });
  }

  @override
  void dispose() {
    for (final c in _rcvdCtrl) c.dispose();
    super.dispose();
  }

  int get _matchedCount => widget.bill.items
      .where((i) => i.status == ReconciliationStatus.matched)
      .length;
  int get _shortageCount => widget.bill.items
      .where((i) => i.status == ReconciliationStatus.shortage)
      .length;
  int get _excessCount => widget.bill.items
      .where((i) => i.status == ReconciliationStatus.excess)
      .length;

  int get _reorderCount => widget.bill.items
      .where((i) => i.actionTaken == ReconciliationAction.reorder)
      .length;
  int get _extraCount => widget.bill.items
      .where((i) => i.actionTaken == ReconciliationAction.extra)
      .length;
  int get _doneCount => widget.bill.items
      .where((i) => i.actionTaken == ReconciliationAction.done)
      .length;

  bool get _allMatched => _shortageCount == 0 && _excessCount == 0;

  /// Every line must have an explicit action picked (Reorder / Extra / Done)
  /// before the GIN can be submitted.
  bool get _allActionsTaken => widget.bill.items.every((item) => item.resolved);

  /// Lines still waiting for an action pick.
  int get _pendingActionCount =>
      widget.bill.items.where((i) => !i.resolved).length;

  bool get _canSubmit => _docs.isNotEmpty && _allActionsTaken;

  void _uploadPhoto() => _addDoc('Photo_Goods');
  void _uploadInvoice() => _addDoc('Invoice');

  void _addDoc(String label) {
    final now = DateTime.now();
    setState(() => _docs.add(UploadedDocument(
          name: '${label}_${now.millisecondsSinceEpoch}.jpg',
          uploadedAt: now,
        )));
    _showSnackbar('$label uploaded successfully', AppTheme.success,
        Icons.check_circle_outline);
  }

  void _removeDoc(int index) => setState(() => _docs.removeAt(index));

  /// Toggles the action on a bill line. First tap confirms the suggested
  /// action; a second tap on the filled chip clears it so the user can re-pick.
  void _toggleAction(int index) {
    setState(() {
      final item = widget.bill.items[index];
      item.actionTaken = item.actionTaken == null ? item.suggestedAction : null;
    });
  }

  void _onSubmit() {
    for (var i = 0; i < widget.bill.items.length; i++) {
      if (_rcvdCtrl[i].text.trim().isEmpty) {
        _showSnackbar(
            'Enter received qty for "${widget.bill.items[i].itemName}"',
            AppTheme.danger,
            Icons.error_outline);
        return;
      }
    }
    if (_docs.isEmpty) {
      _showSnackbar('Upload at least one document before submitting.',
          AppTheme.danger, Icons.error_outline);
      return;
    }
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GINConfirmDialog(
        matchedCount: _matchedCount,
        shortageCount: _shortageCount,
        excessCount: _excessCount,
        reorderCount: _reorderCount,
        extraCount: _extraCount,
        doneCount: _doneCount,
        docCount: _docs.length,
        allMatched: _allMatched,
        onReview: () => Navigator.pop(ctx),
        onConfirm: () {
          Navigator.pop(ctx);
          _submitGIN();
        },
      ),
    );
  }

  Future<void> _submitGIN() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    _showSnackbar('Goods Inward Note submitted successfully!', AppTheme.success,
        Icons.check_circle);
    Navigator.pop(context);
  }

  void _showSnackbar(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Bill #${widget.bill.billNumber}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_allMatched ? AppTheme.success : AppTheme.warning)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _allMatched ? Icons.check_circle : Icons.warning_amber,
                    size: 14,
                    color: _allMatched ? AppTheme.success : AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _allMatched ? 'All Matched' : '$_shortageCount Shortage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _allMatched ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSupplierBanner(),
              const SizedBox(height: 20),
              _buildReconciliationSection(),
              const SizedBox(height: 20),
              _buildDocumentSection(),
              const SizedBox(height: 24),
            ]),
          ),
        ),
        _buildBottomBar(),
      ]),
    );
  }

  Widget _buildSupplierBanner() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppTheme.info.withOpacity(0.08),
            AppTheme.infoBg,
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.info.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Icon(Icons.business_outlined,
                color: AppTheme.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.bill.supplierName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  _infoPill(Icons.tag, 'Bill #${widget.bill.billNumber}',
                      AppTheme.info),
                  _infoPill(Icons.inventory_2_outlined,
                      '${widget.bill.items.length} items', AppTheme.success),
                ]),
              ])),
        ]),
      );

  Widget _infoPill(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildReconciliationSection() {
    final pending = _pendingActionCount;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Item Reconciliation',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const Spacer(),
        if (_matchedCount > 0) _buildChip('$_matchedCount ✓', AppTheme.success),
        if (_shortageCount > 0) ...[
          const SizedBox(width: 6),
          _buildChip('$_shortageCount ⚠', AppTheme.warning),
        ],
        if (_excessCount > 0) ...[
          const SizedBox(width: 6),
          _buildChip('$_excessCount ↑', AppTheme.info),
        ],
      ]),
      const SizedBox(height: 6),
      const Text(
          'Tap the "RCVD" cells to update quantities  ·  Tap an action to resolve each line',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      if (pending > 0 || _reorderCount > 0 || _extraCount > 0) ...[
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pending > 0 ? AppTheme.warningBg : AppTheme.successBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (pending > 0 ? AppTheme.warning : AppTheme.success)
                    .withOpacity(0.35)),
          ),
          child: Row(children: [
            Icon(
              pending > 0 ? Icons.info_outline : Icons.check_circle_outline,
              color: pending > 0 ? AppTheme.warning : AppTheme.success,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pending > 0
                    ? '$pending line${pending > 1 ? "s" : ""} need${pending == 1 ? "s" : ""} an action — '
                        'tap Reorder (shortage), Extra (excess) or Done to enable Submit.'
                    : 'All lines resolved. You can now submit.',
                style: TextStyle(
                  fontSize: 12,
                  color: pending > 0 ? AppTheme.warning : AppTheme.success,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        clipBehavior: Clip.hardEdge,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTableHeader(),
                  ...List.generate(
                      widget.bill.items.length,
                      (i) => _buildTableRow(
                          widget.bill.items[i], _rcvdCtrl[i], i)),
                  _buildTableFooter(),
                ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _buildLegend(),
    ]);
  }

  Widget _buildChip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  static const _colW = <double>[24, 120, 52, 52, 64, 58, 58, 64, 96];
  static const _gap = 8.0;

  Widget _buildTableHeader() {
    const s = TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: AppTheme.textSecondary);
    const sE = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary);
    final headers = [
      ('No.', s, TextAlign.left),
      ('ITEM', s, TextAlign.left),
      ('ORD', s, TextAlign.center),
      ('BILLED', s, TextAlign.center),
      ('RCVD ✎', sE, TextAlign.center),
      ('DIFF\nBld−Rcvd', s, TextAlign.center),
      ('DIFF\nOrd−Rcvd', s, TextAlign.center),
      ('STATUS', s, TextAlign.center),
      ('ACTION', s, TextAlign.center),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: List.generate(headers.length, (i) {
          final (label, style, align) = headers[i];
          return Padding(
            padding: EdgeInsets.only(right: i < headers.length - 1 ? _gap : 0),
            child: SizedBox(
              width: _colW[i],
              child: Text(label, style: style, textAlign: align),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableRow(GINBillItem item, TextEditingController ctrl, int idx) {
    final status = item.status;
    final Color statusColor = status == ReconciliationStatus.matched
        ? AppTheme.success
        : status == ReconciliationStatus.shortage
            ? AppTheme.warning
            : AppTheme.info;
    final rowBg = idx.isEven ? Colors.white : AppTheme.surface.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.resolved ? AppTheme.successBg.withOpacity(0.5) : rowBg,
        border:
            Border(bottom: BorderSide(color: AppTheme.border.withOpacity(0.5))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[0],
            child: Text('${item.sno}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[1],
            child: Text(item.itemName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[2],
            child: Text(item.orderedQty.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[3],
            child: Text(item.billedQty.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[4],
            height: 38,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                  filled: false,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[5],
            child: _DiffBadge(diff: item.diffBilledReceived),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[6],
            child: _DiffBadge(
              diff: item.diffOrderedReceived,
              positiveColor: AppTheme.danger,
              negativeColor: AppTheme.info,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[7],
            child: _StatusBadge(status: status, color: statusColor),
          ),
        ),
        SizedBox(
          width: _colW[8],
          child: _buildActionCell(item, idx),
        ),
      ]),
    );
  }

  /// Single context button per bill line. Defaults to the action suggested by
  /// the received-vs-ordered diff (Reorder / Extra / Done). One tap confirms
  /// (filled ✓), a second tap clears it so the user can re-pick.
  Widget _buildActionCell(GINBillItem item, int idx) {
    final action = item.actionTaken;
    final suggested = item.suggestedAction;
    final (label, icon, color) = _actionVisual(action ?? suggested);
    final confirmed = action != null;

    return GestureDetector(
      onTap: () => _toggleAction(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: confirmed ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: confirmed ? color : color.withOpacity(0.4),
              width: confirmed ? 0.8 : 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(confirmed ? Icons.check_circle : icon,
                size: 12, color: confirmed ? Colors.white : color),
            const SizedBox(width: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: confirmed ? Colors.white : color)),
          ],
        ),
      ),
    );
  }

  /// Label / icon / color triplet for a reconciliation action.
  (String, IconData, Color) _actionVisual(ReconciliationAction action) {
    switch (action) {
      case ReconciliationAction.reorder:
        return ('Reorder', Icons.replay_circle_filled, AppTheme.warning);
      case ReconciliationAction.extra:
        return ('Extra', Icons.add_circle_outline_rounded, AppTheme.info);
      case ReconciliationAction.done:
        return ('Done', Icons.check_circle_outline_rounded, AppTheme.success);
    }
  }

  Widget _buildTableFooter() {
    final totalOrdered =
        widget.bill.items.fold(0.0, (s, i) => s + i.orderedQty);
    final totalBilled = widget.bill.items.fold(0.0, (s, i) => s + i.billedQty);
    final totalReceived =
        widget.bill.items.fold(0.0, (s, i) => s + i.receivedQty);

    const ts = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.04),
        border: Border(
            top: BorderSide(
                color: AppTheme.primary.withOpacity(0.2), width: 1.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: _colW[0] + _gap),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[1],
            child: const Text('TOTAL',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
              width: _colW[2],
              child: Text(totalOrdered.toStringAsFixed(0),
                  textAlign: TextAlign.center, style: ts)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
              width: _colW[3],
              child: Text(totalBilled.toStringAsFixed(0),
                  textAlign: TextAlign.center, style: ts)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
              width: _colW[4],
              child: Text(totalReceived.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: ts.copyWith(fontSize: 13))),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
              width: _colW[5],
              child: _DiffBadge(diff: totalBilled - totalReceived)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
              width: _colW[6],
              child: _DiffBadge(
                diff: totalOrdered - totalReceived,
                positiveColor: AppTheme.danger,
                negativeColor: AppTheme.info,
              )),
        ),
        SizedBox(width: _colW[7] + _gap),
        SizedBox(width: _colW[8]),
      ]),
    );
  }

  Widget _buildLegend() => Wrap(spacing: 10, runSpacing: 6, children: [
        _legendItem('Reorder', AppTheme.warning),
        _legendItem('Extra', AppTheme.info),
        _legendItem('Done', AppTheme.success),
        const Text(
            'RCVD ✎ = editable  ·  tap an action to confirm, tap again to clear',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ]);

  Widget _legendItem(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]);

  Widget _buildDocumentSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Upload Documents',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const Spacer(),
        if (_docs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${_docs.length} uploaded',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success)),
          ),
      ]),
      const SizedBox(height: 4),
      const Text('Upload a photo of goods received and/or the invoice.',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: _UploadButton(
          icon: Icons.camera_alt_outlined,
          label: 'Photo of Goods',
          color: AppTheme.warning,
          onTap: _uploadPhoto,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _UploadButton(
          icon: Icons.receipt_long_outlined,
          label: 'Invoice',
          color: AppTheme.info,
          onTap: _uploadInvoice,
        )),
      ]),
      if (_docs.isNotEmpty) ...[
        const SizedBox(height: 14),
        ...List.generate(_docs.length, (i) => _buildDocTile(_docs[i], i)),
      ],
      if (_docs.isEmpty) ...[
        const SizedBox(height: 10),
        _InfoBox(
          icon: Icons.error_outline,
          color: AppTheme.danger,
          bgColor: AppTheme.dangerBg,
          text: 'At least one document is required to submit.',
        ),
      ],
    ]);
  }

  Widget _buildDocTile(UploadedDocument doc, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        const Icon(Icons.insert_drive_file_outlined,
            size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis),
            Text(_formatTime(doc.uploadedAt),
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ]),
        ),
        const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _removeDoc(index),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.close, size: 13, color: AppTheme.danger),
          ),
        ),
      ]),
    );
  }

  Widget _buildBottomBar() {
    final pending = _pendingActionCount;

    String? disabledHint;
    if (_docs.isEmpty && !_allActionsTaken) {
      disabledHint =
          'Upload a doc & resolve $pending line${pending == 1 ? "" : "s"}';
    } else if (_docs.isEmpty) {
      disabledHint = 'Upload at least one document';
    } else if (!_allActionsTaken) {
      disabledHint =
          'Resolve $pending line${pending > 1 ? "s" : ""} above (Reorder / Extra / Done)';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _bottomStat('Items', '${widget.bill.items.length}', AppTheme.info),
          _bottomStat('Done', '$_doneCount', AppTheme.success),
          if (_reorderCount > 0)
            _bottomStat('Reorder', '$_reorderCount', AppTheme.warning),
          if (_extraCount > 0)
            _bottomStat('Extra', '$_extraCount', AppTheme.info),
          _bottomStat('Docs', '${_docs.length}',
              _docs.isEmpty ? AppTheme.danger : AppTheme.success),
        ]),
        if (disabledHint != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(disabledHint,
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canSubmit && !_isSubmitting ? _onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _canSubmit ? AppTheme.success : AppTheme.textMuted,
            ),
            child: _isSubmitting
                ? const _LoadingIndicator()
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.fact_check_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _canSubmit
                          ? 'Submit Goods Inward Note'
                          : 'Review Required Before Submit',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _bottomStat(String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]);

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Today at $h:$m';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SIMPLE UPLOAD BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _UploadButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _UploadButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GIN CONFIRM DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _GINConfirmDialog extends StatelessWidget {
  final int matchedCount, shortageCount, excessCount, docCount;
  final int reorderCount, extraCount, doneCount;
  final bool allMatched;
  final VoidCallback onReview, onConfirm;

  const _GINConfirmDialog({
    required this.matchedCount,
    required this.shortageCount,
    required this.excessCount,
    required this.reorderCount,
    required this.extraCount,
    required this.doneCount,
    required this.docCount,
    required this.allMatched,
    required this.onReview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.fact_check_outlined,
                      color: AppTheme.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Confirm GIN Submission',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reconciliation Summary',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary)),
                      const SizedBox(height: 10),
                      _summaryRow(Icons.check_circle, '$doneCount marked Done',
                          AppTheme.success),
                      if (reorderCount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow(
                            Icons.replay_circle_filled,
                            '$reorderCount to Reorder (shortage)',
                            AppTheme.warning),
                      ],
                      if (extraCount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow(
                            Icons.add_circle_outline_rounded,
                            '$extraCount Extra (excess received)',
                            AppTheme.info),
                      ],
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _summaryRow(
                          Icons.upload_file,
                          '$docCount document${docCount > 1 ? "s" : ""} attached',
                          AppTheme.info),
                    ]),
              ),
              if (!allMatched) ...[
                const SizedBox(height: 12),
                _InfoBox(
                  icon: Icons.info_outline,
                  color: AppTheme.warning,
                  bgColor: AppTheme.warningBg,
                  text:
                      'Reconciliation actions recorded. HOD will be notified for review.',
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReview,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Review Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit GIN',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String text, Color color) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ),
      ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _CardShell({required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 0.8),
          boxShadow: AppTheme.cardShadow,
        ),
        child: child,
      );
}

Widget _buildStepCard({
  required String step,
  required String title,
  required Color color,
  required Widget child,
}) =>
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(step,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );

Widget _buildAutoIdBanner(
        String id, Color color, Color bgColor, IconData icon) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Auto-generated ID',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          Text(id,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ]),
      ]),
    );

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MiniTag(this.label, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color, bgColor;
  final String text;
  const _InfoBox({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color, height: 1.4)),
          ),
        ]),
      );
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _DiffBadge extends StatelessWidget {
  final double diff;
  final Color positiveColor;
  final Color negativeColor;

  const _DiffBadge({
    required this.diff,
    this.positiveColor = AppTheme.warning,
    this.negativeColor = AppTheme.info,
  });

  @override
  Widget build(BuildContext context) {
    if (diff == 0) {
      return const Center(
          child: Icon(Icons.check, size: 16, color: AppTheme.success));
    }
    final isPositive = diff > 0;
    final color = isPositive ? positiveColor : negativeColor;
    final sign = isPositive ? '−' : '+';
    final label = isPositive ? 'Short' : 'Excess';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$sign${diff.abs().toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color),
            textAlign: TextAlign.center),
        Text(label,
            style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.8)),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReconciliationStatus status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ReconciliationStatus.matched => '✓ OK',
      ReconciliationStatus.shortage => '⚠ Short',
      ReconciliationStatus.excess => '↑ Excess',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center),
    );
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

class _StatCell extends StatelessWidget {
  final _StatData data;
  const _StatCell({required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            data.color.withOpacity(0.06),
            data.color.withOpacity(0.02),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: data.color.withOpacity(0.2), width: 0.8),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Icon(data.icon, size: 14, color: data.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(data.label,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              Text(data.value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: data.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
      );
}

class _SubmissionTile extends StatelessWidget {
  final SubmissionRecord record;
  const _SubmissionTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isOrder = record.type == SubmissionType.order;
    final color = isOrder ? AppTheme.warning : AppTheme.success;
    final icon = isOrder ? Icons.add_shopping_cart : Icons.keyboard_return;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(record.id,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _MiniTag(record.status, AppTheme.warning),
          ]),
          const SizedBox(height: 2),
          Text(
              '${record.item}  ·  ${record.quantity} units  ·  ${record.stockPoint}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════════
// INTERNAL TRANSFER — GIN RECEIVING + HISTORY UPGRADE
// ══════════════════════════════════════════════════════════════════════════════

enum TransferReceivingStatus { matched, shortage, excess }

class TransferLineItem {
  final String id;
  final String itemName;
  final String batch;
  final String unit;
  final int quantity;
  final int looseQuantity;
  final String quality;
  final int? deliveredQuantity;
  final int? receivedQuantity;
  final bool isReceived;
  final String receivingNote;

  const TransferLineItem({
    required this.id,
    required this.itemName,
    required this.batch,
    required this.unit,
    required this.quantity,
    this.looseQuantity = 0,
    required this.quality,
    this.deliveredQuantity,
    this.receivedQuantity,
    this.isReceived = false,
    this.receivingNote = '',
  });

  TransferLineItem copyWith({
    String? id,
    String? itemName,
    String? batch,
    String? unit,
    int? quantity,
    int? looseQuantity,
    String? quality,
    int? deliveredQuantity,
    int? receivedQuantity,
    bool? isReceived,
    String? receivingNote,
  }) {
    return TransferLineItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      batch: batch ?? this.batch,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      looseQuantity: looseQuantity ?? this.looseQuantity,
      quality: quality ?? this.quality,
      deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      isReceived: isReceived ?? this.isReceived,
      receivingNote: receivingNote ?? this.receivingNote,
    );
  }

  int get totalRequested => quantity + looseQuantity;
  int get totalDelivered => deliveredQuantity ?? totalRequested;
  int get totalReceived => receivedQuantity ?? 0;
  int get diffDeliveredReceived => totalDelivered - totalReceived;

  TransferReceivingStatus get receivingStatus {
    if (totalDelivered == totalReceived) return TransferReceivingStatus.matched;
    return totalReceived < totalDelivered
        ? TransferReceivingStatus.shortage
        : TransferReceivingStatus.excess;
  }

  bool get hasReceivingDiscrepancy =>
      isReceived && receivingStatus != TransferReceivingStatus.matched;

  String get requestedLabel {
    final loose = looseQuantity > 0 ? ' + $looseQuantity loose' : '';
    return '$quantity $unit$loose';
  }
}

class TransferRecord {
  final String id;
  final String internalNumber;
  final String invoiceNumber;
  final String fromPoint;
  final String toPoint;
  final String status;
  final DateTime initiatedAt;
  final String initiatedBy;
  final String notes;
  final String? photoPath;
  final String? deliveredBy;
  final String? receivedBy;
  final String? deliveryRemark;
  final String? receivingRemark;
  final DateTime? deliveryUpdatedAt;
  final DateTime? receivedAt;
  final List<TransferLineItem> items;

  const TransferRecord({
    required this.id,
    required this.internalNumber,
    required this.invoiceNumber,
    required this.fromPoint,
    required this.toPoint,
    required this.status,
    required this.initiatedAt,
    required this.items,
    this.initiatedBy = 'Mobile User',
    this.notes = '',
    this.photoPath,
    this.deliveredBy,
    this.receivedBy,
    this.deliveryRemark,
    this.receivingRemark,
    this.deliveryUpdatedAt,
    this.receivedAt,
  });

  TransferRecord copyWith({
    String? id,
    String? internalNumber,
    String? invoiceNumber,
    String? fromPoint,
    String? toPoint,
    String? status,
    DateTime? initiatedAt,
    String? initiatedBy,
    String? notes,
    String? photoPath,
    String? deliveredBy,
    String? receivedBy,
    String? deliveryRemark,
    String? receivingRemark,
    DateTime? deliveryUpdatedAt,
    DateTime? receivedAt,
    List<TransferLineItem>? items,
  }) {
    return TransferRecord(
      id: id ?? this.id,
      internalNumber: internalNumber ?? this.internalNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      fromPoint: fromPoint ?? this.fromPoint,
      toPoint: toPoint ?? this.toPoint,
      status: status ?? this.status,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      deliveredBy: deliveredBy ?? this.deliveredBy,
      receivedBy: receivedBy ?? this.receivedBy,
      deliveryRemark: deliveryRemark ?? this.deliveryRemark,
      receivingRemark: receivingRemark ?? this.receivingRemark,
      deliveryUpdatedAt: deliveryUpdatedAt ?? this.deliveryUpdatedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      items: items ?? this.items,
    );
  }

  bool get isDeliveryOpen =>
      status == 'Pending Delivery' ||
      status == 'In Transit' ||
      status == 'Delayed' ||
      status == 'Delivered';

  bool get isReadyForReceiving =>
      status == 'Delivered' ||
      status == 'Short Received' ||
      status == 'Received';

  bool get isCompleted =>
      status == 'Received' ||
      status == 'Short Received' ||
      status == 'Rejected';

  bool get isCancelled => status == 'Cancelled' || status == 'Rejected';

  int get totalGoods => items.length;

  int get totalRequestedQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.totalRequested);

  int get totalDeliveredQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.totalDelivered);

  int get totalReceivedQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.totalReceived);

  int get verifiedGoodsCount => items.where((item) => item.isReceived).length;

  bool get hasReceivingDiscrepancy =>
      items.any((item) => item.hasReceivingDiscrepancy);

  String get goodsSummary {
    if (items.isEmpty) return 'No goods';
    if (items.length == 1) return items.first.itemName;
    return '${items.first.itemName} + ${items.length - 1} more';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INTERNAL TRANSFER MAIN TAB
// ══════════════════════════════════════════════════════════════════════════════

class InternalTransferTab extends StatefulWidget {
  const InternalTransferTab({super.key});

  @override
  State<InternalTransferTab> createState() => _InternalTransferTabState();
}

class _InternalTransferTabState extends State<InternalTransferTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<TransferRecord> _records = [
    TransferRecord(
      id: 'TRF-0041',
      internalNumber: 'INT-10041',
      invoiceNumber: 'INV-IT-10041',
      fromPoint: 'Site A — North',
      toPoint: 'Site B — South',
      status: 'Pending Delivery',
      initiatedAt: DateTime.now().subtract(const Duration(hours: 5)),
      initiatedBy: 'Rajesh',
      notes: 'Required for generator shift.',
      items: const [
        TransferLineItem(
          id: 'LINE-0041-1',
          itemName: 'Diesel',
          batch: 'BATCH-001',
          unit: 'Litres',
          quantity: 50,
          quality: 'Premium',
        ),
        TransferLineItem(
          id: 'LINE-0041-2',
          itemName: 'Engine Oil',
          batch: 'BATCH-002',
          unit: 'Quarts',
          quantity: 6,
          looseQuantity: 1,
          quality: 'Sealed',
        ),
      ],
    ),
    TransferRecord(
      id: 'TRF-0043',
      internalNumber: 'INT-10043',
      invoiceNumber: 'INV-IT-10043',
      fromPoint: 'Site B — South',
      toPoint: 'Site A — North',
      status: 'Delivered',
      initiatedAt: DateTime.now().subtract(const Duration(days: 1)),
      initiatedBy: 'Supervisor Kumar',
      deliveredBy: 'Delivery Boy - Suresh',
      deliveryRemark: 'Delivered at Site A gate.',
      deliveryUpdatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      items: const [
        TransferLineItem(
          id: 'LINE-0043-1',
          itemName: 'Hydraulic Fluid',
          batch: 'BATCH-003',
          unit: 'Gallons',
          quantity: 8,
          quality: 'Good',
          deliveredQuantity: 8,
        ),
        TransferLineItem(
          id: 'LINE-0043-2',
          itemName: 'Coolant',
          batch: 'BATCH-006',
          unit: 'Litres',
          quantity: 15,
          quality: 'Good',
          deliveredQuantity: 15,
        ),
      ],
    ),
    TransferRecord(
      id: 'TRF-0044',
      internalNumber: 'INT-10044',
      invoiceNumber: 'INV-IT-10044',
      fromPoint: 'Warehouse Main',
      toPoint: 'Field Store',
      status: 'Received',
      initiatedAt: DateTime.now().subtract(const Duration(days: 3)),
      initiatedBy: 'Admin',
      deliveredBy: 'Driver Ramesh',
      receivedBy: 'Field Store Incharge',
      deliveryRemark: 'Delivered completely.',
      receivingRemark: 'All goods verified and received.',
      deliveryUpdatedAt:
          DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      receivedAt: DateTime.now().subtract(const Duration(days: 2)),
      items: const [
        TransferLineItem(
          id: 'LINE-0044-1',
          itemName: 'Feed Bags',
          batch: 'BATCH-007',
          unit: 'Bags',
          quantity: 20,
          quality: 'Good',
          deliveredQuantity: 20,
          receivedQuantity: 20,
          isReceived: true,
        ),
        TransferLineItem(
          id: 'LINE-0044-2',
          itemName: 'Aerator Spare Kit',
          batch: 'BATCH-008',
          unit: 'Sets',
          quantity: 2,
          quality: 'Sealed',
          deliveredQuantity: 2,
          receivedQuantity: 2,
          isReceived: true,
        ),
      ],
    ),
    TransferRecord(
      id: 'TRF-0045',
      internalNumber: 'INT-10045',
      invoiceNumber: 'INV-IT-10045',
      fromPoint: 'Feed Store',
      toPoint: 'Pond-A1',
      status: 'Short Received',
      initiatedAt: DateTime.now().subtract(const Duration(days: 4)),
      initiatedBy: 'Mobile User',
      deliveredBy: 'Driver Nani',
      receivedBy: 'Pond Supervisor',
      deliveryUpdatedAt: DateTime.now().subtract(const Duration(days: 3)),
      receivedAt: DateTime.now().subtract(const Duration(days: 3, hours: -2)),
      receivingRemark: 'One bag damaged during unloading.',
      items: const [
        TransferLineItem(
          id: 'LINE-0045-1',
          itemName: 'Feed Bags',
          batch: 'BATCH-009',
          unit: 'Bags',
          quantity: 25,
          quality: 'Good',
          deliveredQuantity: 25,
          receivedQuantity: 24,
          isReceived: true,
          receivingNote: 'One bag damaged',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addTransfer(TransferRecord record) {
    setState(() => _records.insert(0, record));
    _tabController.animateTo(1);
    _showSnackbar(
      'Transfer invoice created with ${record.totalGoods} goods.',
      AppTheme.success,
    );
  }

  void _updateTransfer(TransferRecord record) {
    setState(() {
      final index = _records.indexWhere((item) => item.id == record.id);
      if (index != -1) _records[index] = record;
    });
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final deliveryCount = _records
        .where((record) => record.isDeliveryOpen && !record.isCancelled)
        .length;
    final receivingCount =
        _records.where((record) => record.isReadyForReceiving).length;
    final historyCount = _records
        .where((record) =>
            record.deliveryUpdatedAt != null || record.receivedAt != null)
        .length;

    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 2.5,
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'New Transfer', icon: Icon(Icons.send_outlined)),
              Tab(
                  text: 'Delivering ($deliveryCount)',
                  icon: const Icon(Icons.local_shipping)),
              Tab(
                  text: 'Receiving ($receivingCount)',
                  icon: const Icon(Icons.inventory)),
              Tab(
                  text: 'History ($historyCount)',
                  icon: const Icon(Icons.table_chart_outlined)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NewTransferTab(onCreated: _addTransfer),
              _DeliveringTab(records: _records, onUpdate: _updateTransfer),
              _ReceivingTab(records: _records, onUpdate: _updateTransfer),
              _InternalTransferHistoryTab(records: _records),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// NEW TRANSFER TAB
// ══════════════════════════════════════════════════════════════════════════════

class _NewTransferTab extends StatefulWidget {
  final ValueChanged<TransferRecord> onCreated;
  const _NewTransferTab({required this.onCreated});

  @override
  State<_NewTransferTab> createState() => _NewTransferTabState();
}

class _NewTransferTabState extends State<_NewTransferTab> {
  String? _fromPoint;
  String? _toPoint;
  String? _selectedItem;
  String? _selectedBatch;
  String _selectedQuality = 'Good';
  bool _initiated = false;
  String? _photoPath;
  final _stockRepo = StockInventoryRepository();
  RealtimeChannel? _stockChannel;
  List<StockInventoryItem> _liveItems = [];
  List<StockBatchBalance> _liveBatches = [];
  bool _loadingStock = true;
  String? _stockError;

  final TextEditingController _transferIdController = TextEditingController();
  final TextEditingController _internalNumberController =
      TextEditingController();
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _looseQuantityController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<TransferLineItem> _pendingItems = [];

  final List<String> _stockPoints = [
    'Site A — North',
    'Site B — South',
    'Warehouse Main',
    'Field Store',
    'Feed Store',
    'Equipment Shed',
  ];

  List<Map<String, dynamic>> get _items => _liveItems
      .map((item) => {
            'id': item.id,
            'name': item.name,
            'icon': _iconForStockItem(item),
            'unit': item.uom,
          })
      .toList();

  List<String> get _batchOptions =>
      _liveBatches.map((batch) => batch.batchId).toSet().toList();

  final List<String> _qualityOptions = [
    'Premium',
    'Good',
    'Standard',
    'Sealed',
    'Needs Check',
  ];

  @override
  void initState() {
    super.initState();
    _resetTransferIds();
    _loadLiveStock();
    _stockChannel = _stockRepo.watchBatchBalances(_loadLiveStock);
  }

  @override
  void dispose() {
    _stockRepo.stopWatching(_stockChannel);
    _transferIdController.dispose();
    _internalNumberController.dispose();
    _invoiceNumberController.dispose();
    _quantityController.dispose();
    _looseQuantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveStock() async {
    try {
      final items = await _stockRepo.fetchItems();
      final batches = await _stockRepo.fetchBatchBalances();
      if (!mounted) return;
      setState(() {
        _liveItems = items;
        _liveBatches = batches;
        _loadingStock = false;
        _stockError = null;
        if (_selectedItem != null &&
            !_liveItems.any((item) => item.id == _selectedItem)) {
          _selectedItem = null;
          _selectedBatch = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingStock = false;
        _stockError =
            'Live stock is unavailable. Check Supabase stock tables and realtime policies.';
      });
    }
  }

  void _resetTransferIds() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final transferSuffix = now % 9000 + 1000;
    final internalSuffix = now % 90000 + 10000;
    _transferIdController.text = 'TRF-$transferSuffix';
    _internalNumberController.text = 'INT-$internalSuffix';
    _invoiceNumberController.text = 'INV-IT-$internalSuffix';
  }

  Map<String, dynamic>? get _selectedItemData {
    if (_selectedItem == null) return null;
    return _items.firstWhere(
      (item) => item['id'] == _selectedItem,
      orElse: () => {
        'id': '',
        'name': '',
        'icon': Icons.help,
        'unit': 'units',
      },
    );
  }

  StockInventoryItem? get _selectedStockItem {
    if (_selectedItem == null) return null;
    for (final item in _liveItems) {
      if (item.id == _selectedItem) return item;
    }
    return null;
  }

  List<StockBatchBalance> _batchesForItem(String itemId) {
    return _liveBatches
        .where((batch) => batch.itemId == itemId && batch.availableQty > 0)
        .toList();
  }

  IconData _iconForStockItem(StockInventoryItem item) {
    final text = '${item.group} ${item.category} ${item.name}'.toLowerCase();
    if (text.contains('fuel') || text.contains('diesel')) {
      return Icons.local_gas_station;
    }
    if (text.contains('oil')) return Icons.oil_barrel;
    if (text.contains('feed')) return Icons.rice_bowl_outlined;
    if (text.contains('chemical') || text.contains('medicine')) {
      return Icons.science_outlined;
    }
    if (text.contains('equipment') || text.contains('spare')) {
      return Icons.build;
    }
    return Icons.inventory_2_outlined;
  }

  int get _totalPendingQty =>
      _pendingItems.fold<int>(0, (sum, item) => sum + item.totalRequested);

  void _addCurrentItemToPending() {
    final itemData = _selectedItemData;
    final stockItem = _selectedStockItem;
    if (_selectedItem == null ||
        stockItem == null ||
        _selectedBatch == null ||
        _quantityController.text.trim().isEmpty) {
      _showSnackbar('Select item, batch and quantity first.', AppTheme.warning);
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showSnackbar('Please enter a valid quantity.', AppTheme.warning);
      return;
    }

    final looseQuantity =
        int.tryParse(_looseQuantityController.text.trim()) ?? 0;
    final unit = (itemData?['unit'] ?? stockItem.uom).toString();
    final line = TransferLineItem(
      id: 'LINE-${DateTime.now().microsecondsSinceEpoch}',
      itemName: stockItem.name,
      batch: _selectedBatch!,
      unit: unit,
      quantity: quantity,
      looseQuantity: looseQuantity < 0 ? 0 : looseQuantity,
      quality: _selectedQuality,
    );

    setState(() {
      _pendingItems.add(line);
      _selectedItem = null;
      _selectedBatch = null;
      _selectedQuality = 'Good';
      _quantityController.clear();
      _looseQuantityController.clear();
    });

    _showSnackbar('Item added to transfer invoice.', AppTheme.success);
  }

  void _removePendingItem(TransferLineItem item) {
    setState(() => _pendingItems.removeWhere((line) => line.id == item.id));
  }

  Future<void> _handleInitiate() async {
    if (_fromPoint == null || _toPoint == null) {
      _showSnackbar(
          'Select source and destination stock points.', AppTheme.danger);
      return;
    }

    if (_fromPoint == _toPoint) {
      _showSnackbar(
          'Source and destination cannot be the same.', AppTheme.danger);
      return;
    }

    if (_pendingItems.isEmpty) {
      _showSnackbar('Add at least one item before initiating transfer.',
          AppTheme.warning);
      return;
    }

    final transferId = _transferIdController.text.trim();
    for (final line in _pendingItems) {
      final stockItem = _liveItems.where((item) => item.name == line.itemName);
      if (stockItem.isEmpty) {
        _showSnackbar(
            'Live stock item missing for ${line.itemName}.', AppTheme.danger);
        return;
      }
      final batch = _liveBatches.where((batch) =>
          batch.itemId == stockItem.first.id && batch.batchId == line.batch);
      if (batch.isEmpty) {
        _showSnackbar(
            'Live batch missing for ${line.itemName} / ${line.batch}.',
            AppTheme.danger);
        return;
      }
      if (line.quantity > batch.first.availableQty) {
        _showSnackbar(
            'Insufficient stock in ${line.batch}. Available ${_formatTransferQty(batch.first.availableQty)} ${line.unit}.',
            AppTheme.danger);
        return;
      }
    }

    try {
      for (final line in _pendingItems) {
        final stockItem =
            _liveItems.firstWhere((item) => item.name == line.itemName);
        final batch = _liveBatches.firstWhere((batch) =>
            batch.itemId == stockItem.id && batch.batchId == line.batch);
        await _stockRepo.issueBatchStock(
          itemId: stockItem.id,
          batchBalanceId: batch.id,
          batchId: batch.batchId,
          stockPointId: batch.stockPointId,
          quantity: line.quantity.toDouble(),
          looseQuantity: line.looseQuantity.toDouble(),
          movementType: 'internal_transfer',
          reason: _notesController.text.trim(),
          referenceId: transferId,
          toStockPointId: _toPoint,
          photoName: _photoPath,
        );
      }
      await _loadLiveStock();
    } catch (error) {
      _showSnackbar('Transfer stock update failed: $error', AppTheme.danger);
      return;
    }

    final record = TransferRecord(
      id: transferId,
      internalNumber: _internalNumberController.text.trim(),
      invoiceNumber: _invoiceNumberController.text.trim(),
      fromPoint: _fromPoint!,
      toPoint: _toPoint!,
      status: 'Pending Delivery',
      initiatedAt: DateTime.now(),
      initiatedBy: 'Mobile User',
      notes: _notesController.text.trim(),
      photoPath: _photoPath,
      items: List<TransferLineItem>.from(_pendingItems),
    );

    widget.onCreated(record);

    setState(() {
      _initiated = true;
      _fromPoint = null;
      _toPoint = null;
      _selectedItem = null;
      _selectedBatch = null;
      _selectedQuality = 'Good';
      _photoPath = null;
      _pendingItems.clear();
      _quantityController.clear();
      _looseQuantityController.clear();
      _notesController.clear();
      _resetTransferIds();
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedItemData = _selectedItemData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InternalHeader(
            emoji: '🔄',
            title: 'Internal Transfers',
            subtitle:
                'Create one transfer invoice with multiple goods, then track delivery and receiving',
            color: AppTheme.info,
          ),
          const SizedBox(height: 16),
          _ProcessInfoCard(
            color: AppTheme.info,
            icon: Icons.info_outline,
            title: 'Multi-item transfer flow',
            message:
                'Add one item or select many items at once. The delivery card opens as an invoice and the receiving card opens as a verification checklist.',
          ),
          const SizedBox(height: 20),
          _buildStepCard(
            step: '1',
            title: 'Transfer Identification',
            color: AppTheme.primary,
            child: _buildIdentificationFields(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2',
            title: 'Source & Destination',
            color: AppTheme.danger,
            child: _buildSourceDestination(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3',
            title: 'Goods / Items',
            color: AppTheme.warning,
            child: _buildItemDetailsList(selectedItemData),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '4',
            title: 'Invoice Goods Preview',
            color: AppTheme.primary,
            child: _buildPendingItemsPreview(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '5',
            title: 'Photo Upload (Optional)',
            color: AppTheme.info,
            child: _buildPhotoUpload(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '6',
            title: 'Notes & Initiate',
            color: AppTheme.success,
            child: _buildNotesAndInitiate(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          if (_initiated) ...[
            const SizedBox(height: 12),
            _ProcessInfoCard(
              color: AppTheme.success,
              icon: Icons.check_circle_outline,
              title: 'Transfer invoice created',
              message:
                  'The new transfer is now visible in Delivering. Tap the card there to open the invoice page.',
            ),
          ],
          const SizedBox(height: 16),
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
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color,
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
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

  Widget _buildIdentificationFields() {
    return Column(
      children: [
        TextFormField(
          controller: _transferIdController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Transfer ID',
            prefixIcon: Icon(Icons.qr_code_2),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _internalNumberController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Internal Number',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _invoiceNumberController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Invoice Number',
            prefixIcon: Icon(Icons.receipt_long_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceDestination() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _fromPoint,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'From Stock Point',
            prefixIcon: Icon(Icons.arrow_upward),
          ),
          items: _stockPoints
              .map((point) => DropdownMenuItem(
                    value: point,
                    child: Text(point, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _fromPoint = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _toPoint,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'To Stock Point',
            prefixIcon: Icon(Icons.arrow_downward),
          ),
          items: _stockPoints
              .map((point) => DropdownMenuItem(
                    value: point,
                    child: Text(point, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _toPoint = value),
        ),
        if (_fromPoint != null && _toPoint != null) ...[
          const SizedBox(height: 12),
          _RoutePreview(from: _fromPoint!, to: _toPoint!),
        ],
      ],
    );
  }

  Widget _buildItemDetailsList(Map<String, dynamic>? selectedItemData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingStock)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_stockError != null) ...[
          _InfoBox(
            icon: Icons.error_outline,
            color: AppTheme.danger,
            bgColor: AppTheme.dangerBg,
            text: _stockError!,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed:
                _loadingStock || _stockError != null ? null : _showBulkAddSheet,
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Add Multiple Items'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Single item entry',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ..._items.map((item) {
          final id = item['id'].toString();
          final name = item['name'].toString();
          final isSelected = _selectedItem == id;
          final stock = _batchesForItem(id);
          return Column(
            children: [
              _SelectableTransferItemTile(
                name: name,
                unit: item['unit'].toString(),
                icon: item['icon'] as IconData,
                selected: isSelected,
                onTap: () => setState(() {
                  _selectedItem = isSelected ? null : id;
                  _selectedBatch =
                      isSelected || stock.isEmpty ? null : stock.first.batchId;
                }),
              ),
              if (isSelected && stock.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ItemStockPanel(
                  itemName: name,
                  unit: item['unit'].toString(),
                  batches: stock,
                ),
                const SizedBox(height: 4),
              ],
            ],
          );
        }),
        if (_selectedItem != null) ...[
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final batchOptions = _batchesForItem(_selectedItem!)
                .map((stock) => stock.batchId)
                .toList();
            final options = batchOptions.isEmpty ? _batchOptions : batchOptions;
            if (_selectedBatch != null && !options.contains(_selectedBatch)) {
              _selectedBatch = options.first;
            }
            return DropdownButtonFormField<String>(
              value: _selectedBatch,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Batch',
                prefixIcon: Icon(Icons.qr_code),
              ),
              items: options
                  .map((batch) => DropdownMenuItem(
                        value: batch,
                        child: Text(batch),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedBatch = value),
            );
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedQuality,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Quality / Condition',
              prefixIcon: Icon(Icons.verified_outlined),
            ),
            items: _qualityOptions
                .map((quality) => DropdownMenuItem(
                      value: quality,
                      child: Text(quality),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedQuality = value ?? 'Good'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: const Icon(Icons.numbers),
                    suffixText: selectedItemData?['unit']?.toString(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _looseQuantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Loose Qty',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addCurrentItemToPending,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Add Item to Invoice'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPendingItemsPreview() {
    if (_pendingItems.isEmpty) {
      return const _InternalEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No goods added yet',
        message:
            'Use Add Multiple Items or select one item above and add it to the invoice.',
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InternalMiniMetric(
                label: 'Goods',
                value: '${_pendingItems.length}',
                icon: Icons.category_outlined,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InternalMiniMetric(
                label: 'Total Qty',
                value: '$_totalPendingQty',
                icon: Icons.numbers_rounded,
                color: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingItems.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.10),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: AppTheme.primary, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${item.batch} • ${item.quality} • ${item.requestedLabel}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removePendingItem(item),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.danger),
                  tooltip: 'Remove item',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showBulkAddSheet() {
    final selected = <String, bool>{};
    final qtyControllers = <String, TextEditingController>{};
    final looseControllers = <String, TextEditingController>{};
    final batchValues = <String, String>{};
    final qualityValues = <String, String>{};

    for (final item in _items) {
      final name = item['name'].toString();
      final id = item['id'].toString();
      final batches = _batchesForItem(id);
      selected[name] = false;
      qtyControllers[name] = TextEditingController();
      looseControllers[name] = TextEditingController();
      batchValues[name] = batches.isEmpty ? '' : batches.first.batchId;
      qualityValues[name] = 'Good';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final selectedCount =
                selected.values.where((value) => value == true).length;

            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.playlist_add_check_rounded,
                              color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Multiple Items at Once',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$selectedCount selected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._items.map((item) {
                      final name = item['name'].toString();
                      final id = item['id'].toString();
                      final unit = item['unit'].toString();
                      final isSelected = selected[name] ?? false;
                      final itemBatches = _batchesForItem(id);
                      final hasBatchStock = itemBatches.isNotEmpty;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withOpacity(0.06)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isSelected ? AppTheme.primary : AppTheme.border,
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: isSelected,
                              activeColor: AppTheme.primary,
                              onChanged: hasBatchStock
                                  ? (value) {
                                      sheetSetState(() {
                                        selected[name] = value ?? false;
                                      });
                                    }
                                  : null,
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                hasBatchStock ? unit : '$unit · no stock',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              secondary: Icon(
                                item['icon'] as IconData,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: qtyControllers[name],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Qty',
                                        suffixText: unit,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: looseControllers[name],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Loose',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: batchValues[name],
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Batch'),
                                      items: itemBatches
                                          .map((stock) => stock.batchId)
                                          .map((batch) => DropdownMenuItem(
                                                value: batch,
                                                child: Text(batch),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        sheetSetState(
                                            () => batchValues[name] = value);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: qualityValues[name],
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Quality'),
                                      items: _qualityOptions
                                          .map((quality) => DropdownMenuItem(
                                                value: quality,
                                                child: Text(quality),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        sheetSetState(
                                            () => qualityValues[name] = value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selectedCount == 0
                            ? null
                            : () {
                                final newLines = <TransferLineItem>[];
                                for (final item in _items) {
                                  final name = item['name'].toString();
                                  final id = item['id'].toString();
                                  if (selected[name] != true) continue;
                                  final itemBatches = _batchesForItem(id);
                                  if (itemBatches.isEmpty) continue;

                                  final qty = int.tryParse(
                                          qtyControllers[name]?.text.trim() ??
                                              '') ??
                                      0;
                                  if (qty <= 0) continue;

                                  final loose = int.tryParse(
                                          looseControllers[name]?.text.trim() ??
                                              '') ??
                                      0;

                                  newLines.add(
                                    TransferLineItem(
                                      id: 'LINE-${DateTime.now().microsecondsSinceEpoch}-${newLines.length}',
                                      itemName: name,
                                      batch: (batchValues[name]?.isNotEmpty ??
                                              false)
                                          ? batchValues[name]!
                                          : itemBatches.first.batchId,
                                      unit: item['unit'].toString(),
                                      quantity: qty,
                                      looseQuantity: loose < 0 ? 0 : loose,
                                      quality: qualityValues[name] ?? 'Good',
                                    ),
                                  );
                                }

                                if (newLines.isEmpty) {
                                  _showSnackbar(
                                    'Enter quantity for selected items.',
                                    AppTheme.warning,
                                  );
                                  return;
                                }

                                setState(() => _pendingItems.addAll(newLines));
                                Navigator.pop(context);
                                _showSnackbar(
                                  '${newLines.length} item(s) added to invoice.',
                                  AppTheme.success,
                                );
                              },
                        icon: const Icon(Icons.add_task_rounded),
                        label: const Text('Add Selected Items'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final controller in qtyControllers.values) {
        controller.dispose();
      }
      for (final controller in looseControllers.values) {
        controller.dispose();
      }
    });
  }

  Widget _buildPhotoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _photoPath =
                  'transfer_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
            });
            _showSnackbar(
                'Photo attached for transfer proof.', AppTheme.success);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _photoPath == null ? AppTheme.infoBg : AppTheme.successBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _photoPath == null
                    ? AppTheme.info.withOpacity(0.24)
                    : AppTheme.success.withOpacity(0.26),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _photoPath == null
                      ? Icons.add_a_photo_outlined
                      : Icons.image_outlined,
                  color: _photoPath == null ? AppTheme.info : AppTheme.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _photoPath == null
                        ? 'Tap to capture/upload goods photo proof'
                        : 'Attached: $_photoPath',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _photoPath == null ? AppTheme.info : AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesAndInitiate() {
    return Column(
      children: [
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Transfer Notes',
            hintText: 'Purpose, vehicle details, special handling notes...',
            prefixIcon: Icon(Icons.notes_outlined),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        _ProcessInfoCard(
          color: AppTheme.warning,
          icon: Icons.admin_panel_settings_outlined,
          title: 'Stock movement rule',
          message:
              'After initiation, the transfer will be visible in Delivering. Actual stock deduction can be connected later to backend approval or local ledger.',
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _handleInitiate,
        icon: const Icon(Icons.send_rounded),
        label:
            Text('Initiate Transfer Invoice (${_pendingItems.length} goods)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DELIVERING TAB + DELIVERY INVOICE PAGE
// ══════════════════════════════════════════════════════════════════════════════

class _DeliveringTab extends StatelessWidget {
  final List<TransferRecord> records;
  final ValueChanged<TransferRecord> onUpdate;

  const _DeliveringTab({
    required this.records,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryRecords = records
        .where((record) => record.isDeliveryOpen && !record.isCancelled)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ModuleHeader(
            emoji: '🚚',
            title: 'Delivering',
            subtitle:
                'Tap any delivery card to open full invoice format and update goods delivery',
            color: AppTheme.warning,
          ),
          const SizedBox(height: 16),
          if (deliveryRecords.isEmpty)
            _EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No delivery transfers',
              message: 'Newly initiated transfers will appear here.',
            )
          else
            ...deliveryRecords.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TransferRecordCard(
                  record: record,
                  accentColor: AppTheme.warning,
                  actionText: 'Open Invoice',
                  onTap: () async {
                    final updated = await Navigator.push<TransferRecord>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TransferDeliveryInvoicePage(record: record),
                      ),
                    );
                    if (updated != null) onUpdate(updated);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TransferDeliveryInvoicePage extends StatefulWidget {
  final TransferRecord record;

  const TransferDeliveryInvoicePage({
    super.key,
    required this.record,
  });

  @override
  State<TransferDeliveryInvoicePage> createState() =>
      _TransferDeliveryInvoicePageState();
}

class _TransferDeliveryInvoicePageState
    extends State<TransferDeliveryInvoicePage> {
  late TransferRecord _record;
  late String _selectedStatus;
  final _deliveredByController = TextEditingController();
  final _deliveryRemarkController = TextEditingController();
  final Map<String, TextEditingController> _deliveredQtyControllers = {};

  final List<String> _deliveryStatuses = const [
    'Pending Delivery',
    'In Transit',
    'Delivered',
    'Delayed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _selectedStatus = (_record.status == 'Received' ||
            _record.status == 'Short Received' ||
            _record.status == 'Rejected')
        ? 'Delivered'
        : _record.status;
    _deliveredByController.text = _record.deliveredBy ?? '';
    _deliveryRemarkController.text = _record.deliveryRemark ?? '';

    for (final item in _record.items) {
      _deliveredQtyControllers[item.id] = TextEditingController(
        text: '${item.deliveredQuantity ?? item.totalRequested}',
      );
    }
  }

  @override
  void dispose() {
    _deliveredByController.dispose();
    _deliveryRemarkController.dispose();
    for (final controller in _deliveredQtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveDelivery() {
    final updatedItems = _record.items.map((item) {
      final deliveredQty = int.tryParse(
            _deliveredQtyControllers[item.id]?.text.trim() ?? '',
          ) ??
          item.totalRequested;
      return item.copyWith(
          deliveredQuantity: deliveredQty < 0 ? 0 : deliveredQty);
    }).toList();

    final updated = _record.copyWith(
      status: _selectedStatus,
      deliveredBy: _deliveredByController.text.trim().isEmpty
          ? null
          : _deliveredByController.text.trim(),
      deliveryRemark: _deliveryRemarkController.text.trim(),
      deliveryUpdatedAt: DateTime.now(),
      items: updatedItems,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Delivery Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveDelivery,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            border: Border(top: BorderSide(color: AppTheme.border)),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ElevatedButton.icon(
            onPressed: _saveDelivery,
            icon: const Icon(Icons.local_shipping_outlined),
            label: Text(
              _selectedStatus == 'Delivered'
                  ? 'Save & Send to Receiving'
                  : 'Save Delivery Update',
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            _InvoiceHeaderCard(record: _record),
            const SizedBox(height: 14),
            _buildTransferInfo(),
            const SizedBox(height: 14),
            _buildStatusSelector(),
            const SizedBox(height: 14),
            _buildDeliveryForm(),
            const SizedBox(height: 14),
            _buildInvoiceGoodsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferInfo() {
    return _TransferPageCard(
      title: 'Transfer Information',
      icon: Icons.route_outlined,
      color: AppTheme.info,
      child: Column(
        children: [
          _InfoLine(label: 'Transfer ID', value: _record.id),
          _InfoLine(label: 'Internal No.', value: _record.internalNumber),
          _InfoLine(label: 'Invoice No.', value: _record.invoiceNumber),
          _InfoLine(label: 'From', value: _record.fromPoint),
          _InfoLine(label: 'To', value: _record.toPoint),
          _InfoLine(label: 'Initiated By', value: _record.initiatedBy),
          _InfoLine(
              label: 'Initiated At',
              value: _formatDateTime(_record.initiatedAt)),
          if (_record.notes.trim().isNotEmpty)
            _InfoLine(label: 'Notes', value: _record.notes),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return _TransferPageCard(
      title: 'Delivery Status',
      icon: Icons.fact_check_outlined,
      color: AppTheme.warning,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _deliveryStatuses.map((status) {
          final selected = _selectedStatus == status;
          final color = _statusColor(status);
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            selectedColor: color.withOpacity(0.15),
            side: BorderSide(color: selected ? color : AppTheme.border),
            label: Text(status),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? color : AppTheme.textSecondary,
            ),
            onSelected: (_) => setState(() => _selectedStatus = status),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeliveryForm() {
    return _TransferPageCard(
      title: 'Delivery Details',
      icon: Icons.person_pin_circle_outlined,
      color: AppTheme.primary,
      child: Column(
        children: [
          TextField(
            controller: _deliveredByController,
            decoration: const InputDecoration(
              labelText: 'Delivered By',
              hintText: 'Driver / delivery person name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deliveryRemarkController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Delivery Remark',
              hintText: 'Vehicle number, delay reason, delivery note...',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceGoodsList() {
    return _TransferPageCard(
      title: 'Goods Invoice List',
      icon: Icons.receipt_long_outlined,
      color: AppTheme.success,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                SizedBox(
                    width: 32,
                    child: Text('#',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(
                    flex: 3,
                    child: Text('Goods',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(
                    flex: 2,
                    child: Text('Batch',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(
                    flex: 2,
                    child: Text('Deliver Qty',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ..._record.items.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('$index',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        )),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${item.itemName}\n${item.quality} • Req: ${item.requestedLabel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.batch,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _deliveredQtyControllers[item.id],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: item.unit,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RECEIVING TAB + GIN-STYLE RECEIVING PAGE
// ══════════════════════════════════════════════════════════════════════════════

class _ReceivingTab extends StatelessWidget {
  final List<TransferRecord> records;
  final ValueChanged<TransferRecord> onUpdate;

  const _ReceivingTab({
    required this.records,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final receivingRecords =
        records.where((record) => record.isReadyForReceiving).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ModuleHeader(
            emoji: '📦',
            title: 'Receiving',
            subtitle:
                'Tap a card to verify goods in GIN table format with received quantity, difference, status and verification action',
            color: AppTheme.success,
          ),
          const SizedBox(height: 16),
          _InfoBox(
            icon: Icons.table_chart_outlined,
            color: AppTheme.info,
            bgColor: AppTheme.infoBg,
            text:
                'Receiving now follows GIN-style table verification. Each item has Req, Delivered, RCVD, Difference, Status, and Verify action.',
          ),
          const SizedBox(height: 16),
          if (receivingRecords.isEmpty)
            _EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No receiving transfers',
              message: 'Delivered transfers will appear here for verification.',
            )
          else
            ...receivingRecords.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TransferRecordCard(
                  record: record,
                  accentColor: AppTheme.success,
                  actionText:
                      record.isCompleted ? 'View GIN Table' : 'Verify Goods',
                  onTap: () async {
                    final updated = await Navigator.push<TransferRecord>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TransferReceivingVerificationPage(record: record),
                      ),
                    );
                    if (updated != null) onUpdate(updated);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TransferReceivingVerificationPage extends StatefulWidget {
  final TransferRecord record;

  const TransferReceivingVerificationPage({
    super.key,
    required this.record,
  });

  @override
  State<TransferReceivingVerificationPage> createState() =>
      _TransferReceivingVerificationPageState();
}

class _TransferReceivingVerificationPageState
    extends State<TransferReceivingVerificationPage> {
  late TransferRecord _record;
  final _receivedByController = TextEditingController();
  final _receivingRemarkController = TextEditingController();
  final Map<String, bool> _receivedChecks = {};
  final Map<String, TextEditingController> _receivedQtyControllers = {};
  final Map<String, TextEditingController> _itemNoteControllers = {};

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _receivedByController.text = _record.receivedBy ?? '';
    _receivingRemarkController.text = _record.receivingRemark ?? '';

    for (final item in _record.items) {
      _receivedChecks[item.id] = item.isReceived;
      _receivedQtyControllers[item.id] = TextEditingController(
        text: item.receivedQuantity == null
            ? '${item.deliveredQuantity ?? item.totalRequested}'
            : '${item.receivedQuantity}',
      );
      _itemNoteControllers[item.id] =
          TextEditingController(text: item.receivingNote);
    }
  }

  @override
  void dispose() {
    _receivedByController.dispose();
    _receivingRemarkController.dispose();
    for (final controller in _receivedQtyControllers.values) {
      controller.dispose();
    }
    for (final controller in _itemNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _checkedCount =>
      _receivedChecks.values.where((value) => value == true).length;

  bool get _readOnly => _record.isCompleted;

  bool get _canSubmit {
    if (_record.items.isEmpty || _readOnly) return false;
    if (_receivedByController.text.trim().isEmpty) return false;
    return _checkedCount > 0;
  }

  void _toggleVerify(int index) {
    final item = _record.items[index];
    setState(() {
      final current = _receivedChecks[item.id] ?? false;
      _receivedChecks[item.id] = !current;
      if (!current &&
          (_receivedQtyControllers[item.id]?.text.trim().isEmpty ?? true)) {
        _receivedQtyControllers[item.id]?.text = '${item.totalDelivered}';
      }
    });
  }

  void _submitReceiving() {
    if (_receivedByController.text.trim().isEmpty) {
      _showSnack(
        'Enter receiver name before submitting.',
        AppTheme.warning,
        Icons.person_outline,
      );
      return;
    }

    final updatedItems = _record.items.map((item) {
      final checked = _receivedChecks[item.id] ?? false;
      final qty = int.tryParse(
            _receivedQtyControllers[item.id]?.text.trim() ?? '',
          ) ??
          0;

      return item.copyWith(
        isReceived: checked,
        receivedQuantity: checked ? (qty < 0 ? 0 : qty) : 0,
        receivingNote: _itemNoteControllers[item.id]?.text.trim() ?? '',
      );
    }).toList();

    final totalItems = updatedItems.length;
    final checkedItems = updatedItems.where((item) => item.isReceived).length;
    final allQtyMatched = updatedItems.every((item) =>
        item.isReceived &&
        item.totalReceived >= (item.deliveredQuantity ?? item.totalRequested));

    String status;
    if (checkedItems == 0) {
      status = 'Rejected';
    } else if (checkedItems == totalItems && allQtyMatched) {
      status = 'Received';
    } else {
      status = 'Short Received';
    }

    final updated = _record.copyWith(
      status: status,
      receivedBy: _receivedByController.text.trim(),
      receivingRemark: _receivingRemarkController.text.trim(),
      receivedAt: DateTime.now(),
      items: updatedItems,
    );

    Navigator.pop(context, updated);
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Receiving Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_readOnly)
            TextButton.icon(
              onPressed: _canSubmit ? _submitReceiving : null,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Submit'),
            ),
        ],
      ),
      bottomNavigationBar: _readOnly
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  border: Border(top: BorderSide(color: AppTheme.border)),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ElevatedButton.icon(
                  onPressed: _canSubmit ? _submitReceiving : null,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                      'Submit Receiving ($_checkedCount/${_record.items.length})'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success),
                ),
              ),
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, _readOnly ? 24 : 100),
        child: Column(
          children: [
            _InvoiceHeaderCard(record: _record),
            const SizedBox(height: 14),
            _buildInfoCard(),
            const SizedBox(height: 14),
            _buildReceiverDetails(readOnly: _readOnly),
            const SizedBox(height: 14),
            _TransferPageCard(
              title: 'GIN-style Receiving Table',
              icon: Icons.table_chart_outlined,
              color: AppTheme.success,
              child: _InternalTransferReceivingTable(
                items: _record.items,
                receivedChecks: _receivedChecks,
                receivedControllers: _receivedQtyControllers,
                readOnly: _readOnly,
                onVerify: _toggleVerify,
              ),
            ),
            const SizedBox(height: 14),
            _buildItemNotes(readOnly: _readOnly),
            if (_readOnly) ...[
              const SizedBox(height: 14),
              _InfoBox(
                icon: Icons.verified_outlined,
                color: _statusColor(_record.status),
                bgColor: _statusColor(_record.status).withOpacity(0.10),
                text:
                    'Verification already submitted. Status: ${_record.status}. This record is visible in Internal Transfer History.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return _TransferPageCard(
      title: 'Transfer Information',
      icon: Icons.assignment_outlined,
      color: AppTheme.info,
      child: Column(
        children: [
          _InfoLine(label: 'Transfer ID', value: _record.id),
          _InfoLine(label: 'Internal No.', value: _record.internalNumber),
          _InfoLine(label: 'Invoice No.', value: _record.invoiceNumber),
          _InfoLine(label: 'From', value: _record.fromPoint),
          _InfoLine(label: 'To', value: _record.toPoint),
          _InfoLine(
              label: 'Delivered By',
              value: _record.deliveredBy ?? 'Not entered'),
          _InfoLine(
            label: 'Delivered At',
            value: _record.deliveryUpdatedAt == null
                ? 'Not updated'
                : _formatDateTime(_record.deliveryUpdatedAt!),
          ),
          if ((_record.deliveryRemark ?? '').trim().isNotEmpty)
            _InfoLine(label: 'Delivery Note', value: _record.deliveryRemark!),
        ],
      ),
    );
  }

  Widget _buildReceiverDetails({required bool readOnly}) {
    return _TransferPageCard(
      title: 'Receiver Details',
      icon: Icons.person_search_outlined,
      color: AppTheme.primary,
      child: Column(
        children: [
          TextField(
            controller: _receivedByController,
            readOnly: readOnly,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Received By',
              hintText: 'Receiver / store incharge name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receivingRemarkController,
            readOnly: readOnly,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Overall Receiving Note',
              hintText: 'Shortage, damage, missing goods, extra note...',
              prefixIcon: Icon(Icons.notes_outlined),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemNotes({required bool readOnly}) {
    return _TransferPageCard(
      title: 'Item Notes',
      icon: Icons.note_alt_outlined,
      color: AppTheme.warning,
      child: Column(
        children: _record.items.map((item) {
          final checked = _receivedChecks[item.id] ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: checked ? AppTheme.successBg : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: checked
                    ? AppTheme.success.withOpacity(0.28)
                    : AppTheme.border,
              ),
            ),
            child: TextField(
              controller: _itemNoteControllers[item.id],
              readOnly: readOnly || !checked,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '${item.itemName} Note',
                hintText: 'Damage / shortage / location note',
                prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                alignLabelWithHint: true,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GIN-STYLE RECEIVING TABLE FOR INTERNAL TRANSFER
// ══════════════════════════════════════════════════════════════════════════════

class _InternalTransferReceivingTable extends StatelessWidget {
  final List<TransferLineItem> items;
  final Map<String, bool> receivedChecks;
  final Map<String, TextEditingController> receivedControllers;
  final bool readOnly;
  final ValueChanged<int> onVerify;

  const _InternalTransferReceivingTable({
    required this.items,
    required this.receivedChecks,
    required this.receivedControllers,
    required this.readOnly,
    required this.onVerify,
  });

  static const _colW = <double>[28, 150, 58, 74, 70, 70, 78, 100];
  static const _gap = 8.0;

  int _receivedQty(TransferLineItem item) {
    final text = receivedControllers[item.id]?.text.trim() ?? '';
    return int.tryParse(text) ?? 0;
  }

  TransferReceivingStatus _rowStatus(TransferLineItem item) {
    final received = _receivedQty(item);
    if (received == item.totalDelivered) return TransferReceivingStatus.matched;
    return received < item.totalDelivered
        ? TransferReceivingStatus.shortage
        : TransferReceivingStatus.excess;
  }

  Color _rowStatusColor(TransferReceivingStatus status) {
    switch (status) {
      case TransferReceivingStatus.matched:
        return AppTheme.success;
      case TransferReceivingStatus.shortage:
        return AppTheme.warning;
      case TransferReceivingStatus.excess:
        return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalReq =
        items.fold<int>(0, (sum, item) => sum + item.totalRequested);
    final totalDelivered =
        items.fold<int>(0, (sum, item) => sum + item.totalDelivered);
    final totalReceived =
        items.fold<int>(0, (sum, item) => sum + _receivedQty(item));
    final verifiedCount =
        items.where((item) => receivedChecks[item.id] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _InternalMiniMetric(
                label: 'Verified',
                value: '$verifiedCount/${items.length}',
                icon: Icons.verified_outlined,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InternalMiniMetric(
                label: 'Delivered',
                value: '$totalDelivered',
                icon: Icons.local_shipping_outlined,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InternalMiniMetric(
                label: 'Received',
                value: '$totalReceived',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          clipBehavior: Clip.hardEdge,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  ...List.generate(items.length, (index) {
                    return _buildRow(items[index], index);
                  }),
                  _buildFooter(totalReq, totalDelivered, totalReceived),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildLegend(),
      ],
    );
  }

  Widget _buildHeader() {
    const headingStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: AppTheme.textSecondary,
    );
    const editableStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w900,
      color: AppTheme.primary,
    );

    final headers = [
      'No.',
      'ITEM',
      'REQ',
      'DELIVERED',
      'RCVD ✎',
      'DIFF',
      'STATUS',
      'VERIFY',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: List.generate(headers.length, (index) {
          return Padding(
            padding:
                EdgeInsets.only(right: index < headers.length - 1 ? _gap : 0),
            child: SizedBox(
              width: _colW[index],
              child: Text(
                headers[index],
                textAlign: index == 1 ? TextAlign.left : TextAlign.center,
                style: headers[index].contains('RCVD')
                    ? editableStyle
                    : headingStyle,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRow(TransferLineItem item, int index) {
    final verified = receivedChecks[item.id] == true;
    final received = _receivedQty(item);
    final diff = item.totalDelivered - received;
    final status = _rowStatus(item);
    final color = _rowStatusColor(status);
    final rowBg =
        index.isEven ? Colors.white : AppTheme.surface.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: verified ? AppTheme.successBg.withOpacity(0.5) : rowBg,
        border:
            Border(bottom: BorderSide(color: AppTheme.border.withOpacity(0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _tableCell('${index + 1}', 0),
          _tableCell('${item.itemName} · ${item.batch}', 1,
              align: TextAlign.left, bold: true),
          _tableCell('${item.totalRequested}', 2),
          _tableCell('${item.totalDelivered}', 3),
          Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _colW[4],
              height: 38,
              child: Container(
                decoration: BoxDecoration(
                  color: readOnly
                      ? AppTheme.surface
                      : AppTheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: readOnly
                        ? AppTheme.border
                        : AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: receivedControllers[item.id],
                  readOnly: readOnly || verified,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    filled: false,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _colW[5],
              child: _TransferDiffBadge(diff: diff),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _colW[6],
              child:
                  _TransferReceivingStatusBadge(status: status, color: color),
            ),
          ),
          SizedBox(
            width: _colW[7],
            child: verified
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: readOnly ? null : () => onVerify(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.warning
                            .withOpacity(readOnly ? 0.06 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.warning
                              .withOpacity(readOnly ? 0.18 : 0.4),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Verify',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color:
                              readOnly ? AppTheme.textMuted : AppTheme.warning,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(
    String text,
    int index, {
    TextAlign align = TextAlign.center,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: _gap),
      child: SizedBox(
        width: _colW[index],
        child: Text(
          text,
          textAlign: align,
          maxLines: index == 1 ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: index == 1 ? 11.5 : 12,
            color: index == 1 ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(int totalReq, int totalDelivered, int totalReceived) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.04),
        border: Border(
          top: BorderSide(color: AppTheme.primary.withOpacity(0.2), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: _colW[0] + _gap),
          Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _colW[1],
              child: const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          _footerCell(totalReq, 2),
          _footerCell(totalDelivered, 3),
          _footerCell(totalReceived, 4),
          Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: SizedBox(
              width: _colW[5],
              child: _TransferDiffBadge(diff: totalDelivered - totalReceived),
            ),
          ),
          SizedBox(width: _colW[6] + _gap),
          SizedBox(width: _colW[7]),
        ],
      ),
    );
  }

  Widget _footerCell(int value, int widthIndex) {
    return Padding(
      padding: const EdgeInsets.only(right: _gap),
      child: SizedBox(
        width: _colW[widthIndex],
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: const [
        _LegendItem(label: 'Matched', color: AppTheme.success),
        _LegendItem(label: 'Shortage', color: AppTheme.warning),
        _LegendItem(label: 'Excess', color: AppTheme.info),
        Text(
          'RCVD ✎ = editable received quantity · scroll table sideways for all columns',
          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _TransferDiffBadge extends StatelessWidget {
  final int diff;
  const _TransferDiffBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff == 0) {
      return const Center(
        child: Icon(Icons.check, size: 16, color: AppTheme.success),
      );
    }

    final isShort = diff > 0;
    final color = isShort ? AppTheme.warning : AppTheme.info;
    final sign = isShort ? '−' : '+';
    final label = isShort ? 'Short' : 'Excess';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign${diff.abs()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TransferReceivingStatusBadge extends StatelessWidget {
  final TransferReceivingStatus status;
  final Color color;

  const _TransferReceivingStatusBadge({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final label = status == TransferReceivingStatus.matched
        ? '✓ OK'
        : status == TransferReceivingStatus.shortage
            ? '⚠ Short'
            : '↑ Excess';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INTERNAL TRANSFER HISTORY TABLE
// ══════════════════════════════════════════════════════════════════════════════

class _InternalTransferHistoryTab extends StatefulWidget {
  final List<TransferRecord> records;
  const _InternalTransferHistoryTab({required this.records});

  @override
  State<_InternalTransferHistoryTab> createState() =>
      _InternalTransferHistoryTabState();
}

class _InternalTransferHistoryTabState
    extends State<_InternalTransferHistoryTab> {
  final _searchController = TextEditingController();
  String _statusFilter = 'All';

  final List<String> _filters = const [
    'All',
    'Pending Delivery',
    'In Transit',
    'Delivered',
    'Received',
    'Short Received',
    'Delayed',
    'Cancelled',
    'Rejected',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransferRecord> get _historyRecords {
    final query = _searchController.text.trim().toLowerCase();

    return widget.records.where((record) {
      final hasHistory = record.deliveryUpdatedAt != null ||
          record.receivedAt != null ||
          record.status == 'Delivered' ||
          record.status == 'Received' ||
          record.status == 'Short Received' ||
          record.status == 'Rejected' ||
          record.status == 'Cancelled';

      if (!hasHistory) return false;

      final filterOk = _statusFilter == 'All' || record.status == _statusFilter;
      final searchText =
          '${record.id} ${record.internalNumber} ${record.invoiceNumber} ${record.fromPoint} ${record.toPoint} ${record.status} ${record.goodsSummary}'
              .toLowerCase();
      final searchOk = query.isEmpty || searchText.contains(query);

      return filterOk && searchOk;
    }).toList()
      ..sort((a, b) {
        final ad = a.receivedAt ?? a.deliveryUpdatedAt ?? a.initiatedAt;
        final bd = b.receivedAt ?? b.deliveryUpdatedAt ?? b.initiatedAt;
        return bd.compareTo(ad);
      });
  }

  @override
  Widget build(BuildContext context) {
    final records = _historyRecords;
    final deliveredCount = widget.records
        .where((record) => record.deliveryUpdatedAt != null)
        .length;
    final receivedCount =
        widget.records.where((record) => record.receivedAt != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ModuleHeader(
            emoji: '📊',
            title: 'Internal Transfer History',
            subtitle:
                'Track delivered and received orders in table format with invoice, route, quantity and status',
            color: AppTheme.primary,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InternalMiniMetric(
                  label: 'Delivered Logs',
                  value: '$deliveredCount',
                  icon: Icons.local_shipping_outlined,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InternalMiniMetric(
                  label: 'Received Logs',
                  value: '$receivedCount',
                  icon: Icons.inventory_2_outlined,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 16),
          if (records.isEmpty)
            _EmptyState(
              icon: Icons.table_chart_outlined,
              title: 'No history records found',
              message:
                  'Delivered and received internal transfer orders will appear here.',
            )
          else
            _buildHistoryTable(records),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return _CardShell(
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search invoice, transfer ID, route, status...',
              prefixIcon: Icon(Icons.search_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _statusFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Status Filter',
              prefixIcon: Icon(Icons.filter_list_outlined),
            ),
            items: _filters
                .map((filter) =>
                    DropdownMenuItem(value: filter, child: Text(filter)))
                .toList(),
            onChanged: (value) =>
                setState(() => _statusFilter = value ?? 'All'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTable(List<TransferRecord> records) {
    return _CardShell(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: const Text(
              'Delivered / Received Orders Table',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 72,
              columnSpacing: 18,
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Invoice')),
                DataColumn(label: Text('Route')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Goods')),
                DataColumn(label: Text('Delivered')),
                DataColumn(label: Text('Received')),
                DataColumn(label: Text('Handled By')),
              ],
              rows: records.map((record) {
                final eventDate = record.receivedAt ??
                    record.deliveryUpdatedAt ??
                    record.initiatedAt;

                return DataRow(
                  cells: [
                    DataCell(Text(
                      _formatDateTime(eventDate),
                      style: const TextStyle(fontSize: 11),
                    )),
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          record.invoiceNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          record.id,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    )),
                    DataCell(SizedBox(
                      width: 170,
                      child: Text(
                        '${record.fromPoint} → ${record.toPoint}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    )),
                    DataCell(_TransferStatusBadge(status: record.status)),
                    DataCell(Text(
                      '${record.totalGoods}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    )),
                    DataCell(Text(
                      '${record.totalDeliveredQuantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warning,
                      ),
                    )),
                    DataCell(Text(
                      '${record.totalReceivedQuantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: record.status == 'Received'
                            ? AppTheme.success
                            : record.status == 'Short Received'
                                ? AppTheme.warning
                                : AppTheme.textSecondary,
                      ),
                    )),
                    DataCell(SizedBox(
                      width: 145,
                      child: Text(
                        record.receivedBy ??
                            record.deliveredBy ??
                            record.initiatedBy,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SMALL REUSABLE UI FOR INTERNAL TRANSFER
// ══════════════════════════════════════════════════════════════════════════════

class _ModuleHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _ModuleHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                )),
            const SizedBox(height: 4),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

class _SelectableTransferItemTile extends StatelessWidget {
  final String name;
  final String unit;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTransferItemTile({
    required this.name,
    required this.unit,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: selected ? AppTheme.warning.withOpacity(0.10) : AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppTheme.warning : AppTheme.border,
          width: selected ? 1.5 : 0.8,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: selected
              ? AppTheme.warning.withOpacity(0.16)
              : AppTheme.textMuted.withOpacity(0.12),
          child: Icon(
            icon,
            color: selected ? AppTheme.warning : AppTheme.textSecondary,
            size: 19,
          ),
        ),
        title: Text(name,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            )),
        subtitle: Text('Unit: $unit',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            )),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: selected ? AppTheme.warning : AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _ItemStockPanel extends StatelessWidget {
  final String itemName;
  final String unit;
  final List<StockBatchBalance> batches;

  const _ItemStockPanel({
    required this.itemName,
    required this.unit,
    required this.batches,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        batches.fold<double>(0, (sum, batch) => sum + batch.availableQty);
    final loose = batches.fold<double>(0, (sum, batch) => sum + batch.looseQty);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.info.withOpacity(0.24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined,
              size: 17, color: AppTheme.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Available Stock · $itemName',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          _MiniTag(
              'Total ${_formatTransferQty(total)} $unit', AppTheme.success),
          const SizedBox(width: 6),
          _MiniTag('Loose ${_formatTransferQty(loose)}', AppTheme.warning),
        ]),
        const SizedBox(height: 10),
        ...batches.map((batch) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                const Icon(Icons.subdirectory_arrow_right,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${batch.batchId} · ${batch.stockPointName}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${_formatTransferQty(batch.availableQty)} $unit',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ]),
            )),
        _InfoBox(
          icon: Icons.qr_code_2_outlined,
          color: AppTheme.info,
          bgColor: AppTheme.surfaceCard,
          text: 'The batch dropdown is filtered to these available batches.',
        ),
      ]),
    );
  }
}

String _formatTransferQty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _RoutePreview extends StatelessWidget {
  final String from;
  final String to;

  const _RoutePreview({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final invalid = from == to;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: invalid ? AppTheme.dangerBg : AppTheme.infoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: invalid
              ? AppTheme.danger.withOpacity(0.25)
              : AppTheme.info.withOpacity(0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            invalid ? Icons.error_outline : Icons.route_outlined,
            color: invalid ? AppTheme.danger : AppTheme.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              invalid
                  ? 'Invalid route: source and destination are same.'
                  : '$from  →  $to',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: invalid ? AppTheme.danger : AppTheme.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferRecordCard extends StatelessWidget {
  final TransferRecord record;
  final Color accentColor;
  final String actionText;
  final VoidCallback onTap;

  const _TransferRecordCard({
    required this.record,
    required this.accentColor,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: accentColor.withOpacity(0.12),
                  child: Icon(Icons.swap_horiz, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${record.id}\n${record.invoiceNumber}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _TransferStatusBadge(status: record.status),
              ]),
              const SizedBox(height: 12),
              Text(record.goodsSummary,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: record.items.take(4).map((item) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      '${item.itemName} • ${item.requestedLabel}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _InfoLine(
                        label: 'From', value: record.fromPoint, compact: true)),
                const SizedBox(width: 8),
                Expanded(
                    child: _InfoLine(
                        label: 'To', value: record.toPoint, compact: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _SmallMetricPill(
                  icon: Icons.category_outlined,
                  label: '${record.totalGoods} goods',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _SmallMetricPill(
                  icon: Icons.local_shipping_outlined,
                  label: '${record.totalDeliveredQuantity} delivered',
                  color: AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _SmallMetricPill(
                  icon: Icons.inventory_2_outlined,
                  label: '${record.totalReceivedQuantity} received',
                  color: AppTheme.success,
                ),
                const Spacer(),
                Row(children: [
                  Text(actionText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      )),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: accentColor),
                ]),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferStatusBadge extends StatelessWidget {
  final String status;

  const _TransferStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(status,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: color,
          )),
    );
  }
}

class _SmallMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SmallMetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _InternalMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InternalMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  )),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TransferPageCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _TransferPageCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                )),
          ),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _InvoiceHeaderCard extends StatelessWidget {
  final TransferRecord record;

  const _InvoiceHeaderCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(record.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.14), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.14),
            child: Icon(Icons.receipt_long_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(record.invoiceNumber,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                )),
          ),
          _TransferStatusBadge(status: record.status),
        ]),
        const SizedBox(height: 12),
        Text('${record.fromPoint}  →  ${record.toPoint}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            )),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _InternalMiniMetric(
              label: 'Goods',
              value: '${record.totalGoods}',
              icon: Icons.category_outlined,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InternalMiniMetric(
              label: 'Delivered',
              value: '${record.totalDeliveredQuantity}',
              icon: Icons.local_shipping_outlined,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InternalMiniMetric(
              label: 'Received',
              value: '${record.totalReceivedQuantity}',
              icon: Icons.inventory_2_outlined,
              color: AppTheme.success,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RESTORED HELPERS FOR MULTI-ITEM NEW TRANSFER FLOW
// ══════════════════════════════════════════════════════════════════════════════

class _InternalHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _InternalHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessInfoCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String message;

  const _ProcessInfoCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: color,
                    )),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InternalEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppTheme.textMuted),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              )),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              )),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Pending Delivery':
      return AppTheme.warning;
    case 'In Transit':
      return AppTheme.info;
    case 'Delivered':
      return AppTheme.primary;
    case 'Received':
      return AppTheme.success;
    case 'Short Received':
      return AppTheme.warning;
    case 'Delayed':
      return AppTheme.danger;
    case 'Cancelled':
    case 'Rejected':
      return AppTheme.danger;
    default:
      return AppTheme.textSecondary;
  }
}

String _formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

// ══════════════════════════════════════════════════════════════════════════════
// REAL WORKFLOW TABS — DB-backed + realtime
// View Orders (HOD placed) → Received → GIN review → Add to Stock
// Consumption (batch qty + photo) → auto stock update
// Internal Transfer → Delivered / Received stock updates
// ══════════════════════════════════════════════════════════════════════════════

/// Capture a photo with the camera via image_picker (works on mobile + web).
/// Returns raw bytes and extension, or null if cancelled/failed.
Future<({Uint8List bytes, String ext})?> _captureStockPhoto() async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    return (bytes: bytes, ext: ext);
  } catch (e) {
    debugPrint('Stock photo capture failed: $e');
    return null;
  }
}

void _stockSnack(BuildContext context, String message, Color color) {
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

// ─── VIEW ORDERS — orders placed by HOD ───────────────────────────────────────

class _ViewOrdersTab extends StatefulWidget {
  const _ViewOrdersTab();

  @override
  State<_ViewOrdersTab> createState() => _ViewOrdersTabState();
}

class _ViewOrdersTabState extends State<_ViewOrdersTab> {
  final _repo = StockInventoryRepository();
  List<StockOrder> _orders = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.watchOrders(_load);
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    final orders = await _repo.fetchOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _receiveOrder(StockOrder order) async {
    final ok = await _repo.markOrderReceived(order);
    if (!mounted) return;
    _stockSnack(
      context,
      ok
          ? 'Order received → GIN created. Review it in the GIN tab.'
          : 'Failed to receive order',
      ok ? AppTheme.success : AppTheme.danger,
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final placed = _orders.where((o) => o.status == 'placed').length;
    final received = _orders
        .where((o) => o.status == 'received' || o.status == 'added_to_stock')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.primary.withOpacity(0.14),
                    AppTheme.primary.withOpacity(0.06),
                  ]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.shopping_bag_outlined,
                    color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('View Orders',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                          'Orders placed by HOD — tap Received Order to move them into GIN review',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary)),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniTag('$placed Placed', AppTheme.warning,
                  icon: Icons.pending_actions),
              const SizedBox(width: 8),
              _MiniTag('$received Received', AppTheme.success,
                  icon: Icons.inventory_2_outlined),
            ],
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_orders.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 56, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text('No orders yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text(
                      'Orders placed by HOD for this site will appear here in realtime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            )
          else
            ..._orders.map((order) => _buildOrderCard(order)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(StockOrder order) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;
    switch (order.status) {
      case 'received':
        statusColor = AppTheme.info;
        statusIcon = Icons.fact_check_outlined;
        statusText = 'In GIN review';
        break;
      case 'added_to_stock':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Added to stock';
        break;
      case 'cancelled':
        statusColor = AppTheme.textMuted;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = AppTheme.warning;
        statusIcon = Icons.pending_outlined;
        statusText = 'Placed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(order.orderNo,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusText,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.category_outlined,
                  size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(order.itemName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ),
              Text(
                  '${_qty(order.quantity)} ${order.unit}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.qr_code_2,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('Batch ${order.batch}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 14),
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(order.stockPointName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          if (order.placedBy != null && order.placedBy!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text('Placed by ${order.placedBy}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textMuted)),
              ],
            ),
          ],
          if (order.status == 'placed') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _receiveOrder(order),
                icon: const Icon(Icons.download_done_rounded, size: 18),
                label: const Text('Received Order',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

// ─── GIN REVIEW — check received goods and add into stock ─────────────────────

class _GINReviewTab extends StatefulWidget {
  const _GINReviewTab();

  @override
  State<_GINReviewTab> createState() => _GINReviewTabState();
}

class _GINReviewTabState extends State<_GINReviewTab> {
  final _repo = StockInventoryRepository();
  List<StockGinBill> _bills = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = _repo.watchGinBills(_load);
  }

  @override
  void dispose() {
    _repo.stopWatching(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    final bills = await _repo.fetchGinBills();
    if (!mounted) return;
    setState(() {
      _bills = bills;
      _loading = false;
    });
  }

  Future<void> _openReview(StockGinBill bill) async {
    final qtyCtrl =
        TextEditingController(text: bill.quantity.toStringAsFixed(0));
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review Goods & Add to Stock',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            _DetailRow(label: 'GIN No', value: bill.ginNo),
            _DetailRow(label: 'Item', value: bill.itemName),
            _DetailRow(label: 'Batch', value: bill.batch),
            _DetailRow(label: 'Stock Point', value: bill.stockPointName),
            _DetailRow(
                label: 'Order Qty', value: '${bill.quantity} ${bill.unit}'),
            const SizedBox(height: 14),
            TextField(
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Received Quantity (${bill.unit})',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.numbers, size: 18),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text.trim()) ?? bill.quantity;
                  Navigator.pop(sheetContext, qty);
                },
                icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                label: const Text('Add to Stock',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
    qtyCtrl.dispose();
    if (result == null || !mounted) return;
    final ok = await _repo.reviewGinAddToStock(bill, overrideQuantity: result);
    if (!mounted) return;
    _stockSnack(
      context,
      ok
          ? '${bill.itemName} added to stock successfully'
          : 'Failed to add to stock',
      ok ? AppTheme.success : AppTheme.danger,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _bills.where((b) => b.status == 'pending_review').toList();
    final completed =
        _bills.where((b) => b.status == 'added_to_stock').toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: AppTheme.surface,
          child: Row(
            children: [
              _MiniTag('${pending.length} Pending Review', AppTheme.warning,
                  icon: Icons.fact_check_outlined),
              const Spacer(),
              Text('${completed.length} Added',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : pending.isEmpty && completed.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: AppTheme.textMuted),
                            SizedBox(height: 16),
                            Text('No Goods Inward Notes',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary)),
                            SizedBox(height: 4),
                            Text(
                                'Received orders appear here for item & quantity review.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted)),
                          ]),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      children: [
                        if (pending.isNotEmpty) ...[
                          const _SectionLabel('Pending Review',
                              Icons.fact_check_outlined,
                              AppTheme.warning),
                          ...pending.map((b) => _buildBillCard(b, pending: true)),
                        ],
                        if (completed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const _SectionLabel('Added to Stock',
                              Icons.check_circle_outline, AppTheme.success),
                          ...completed
                              .map((b) => _buildBillCard(b, pending: false)),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildBillCard(StockGinBill bill, {required bool pending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: pending ? AppTheme.warning : AppTheme.success,
            width: pending ? 1 : 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bill.ginNo,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
              if (!pending)
                const Icon(Icons.verified_outlined,
                    size: 18, color: AppTheme.success),
            ],
          ),
          const SizedBox(height: 10),
          Text(bill.itemName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.qr_code_2,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('Batch ${bill.batch}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const Spacer(),
              Text('${_qtyFmt(bill.quantity)} ${bill.unit}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: pending ? AppTheme.warning : AppTheme.success)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(bill.stockPointName,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          if (pending) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openReview(bill),
                icon: const Icon(Icons.add_to_photos_outlined, size: 18),
                label: const Text('Check Item & Add to Stock',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _qtyFmt(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

// ─── INTERNAL TRANSFER — deliver deducts sender, receive adds receiver ───────

class StockTransferTab extends StatefulWidget {
  const StockTransferTab({super.key});

  @override
  State<StockTransferTab> createState() => _StockTransferTabState();
}

class _StockTransferTabState extends State<StockTransferTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  List<StockTransfer> _transfers = [];
  List<StockBatchBalance> _balances = [];
  List<Map<String, dynamic>> _thavvuPoints = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
    _channel = _repo.watchTransfers(_load);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _repo.stopWatching(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    final transfers = await _repo.fetchTransfers();
    final balances = await _repo.fetchBatchBalances();
    // Enterprise transfer nodes: the Thavvu Points HOD created for the site.
    final siteId = await _contextService.resolveSiteId();
    final thavvuPoints = await _repo.fetchThavvuPointsForSite(siteId);
    if (!mounted) return;
    setState(() {
      _transfers = transfers;
      _balances = balances;
      _thavvuPoints = thavvuPoints;
      _loading = false;
    });
  }

  /// Stock points the signed-in supervisor can act on (they hold stock there).
  /// Drive is done from these points; receipt is done to these points.
  Set<String> get _myPointIds =>
      _balances.map((b) => b.stockPointId).toSet();

  /// Outbound transfers — I am the sender (from one of my points).
  List<StockTransfer> get _myDeliveries =>
      _transfers.where((t) => _myPointIds.contains(t.fromPointId)).toList();

  /// Inbound transfers — I am the receiver (to one of my points).
  List<StockTransfer> get _myReceives =>
      _transfers.where((t) => _myPointIds.contains(t.toPointId)).toList();

  Future<bool> _confirmDeliver(StockTransfer t) async {
    final ok = await _repo.markTransferDelivered(t);
    if (!mounted) return ok;
    _stockSnack(
      context,
      ok
          ? 'Delivered — stock deducted from ${t.fromPoint}. Awaiting receiver.'
          : 'Delivery failed — insufficient stock at ${t.fromPoint}',
      ok ? AppTheme.success : AppTheme.danger,
    );
    _load();
    return ok;
  }

  /// Opens the receiving checklist. Stock is added to the receiver point
  /// only after the checklist is verified and confirmed.
  Future<void> _openReceiveChecklist(StockTransfer t) async {
    final result = await showModalBottomSheet<_ReceiveChecklistResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiveChecklistSheet(transfer: t),
    );
    if (result == null || !mounted) return;
    final ok = await _repo.markTransferReceived(
      t,
      receivedQuantity: result.receivedQuantity,
      condition: result.condition,
      checklist: result.checkedItems,
      notes: result.notes.isEmpty ? null : result.notes,
      receivedByName: result.receiverName.isEmpty ? null : result.receiverName,
    );
    if (!mounted) return;
    _stockSnack(
      context,
      ok
          ? 'Received — ${_fmtQty(result.receivedQuantity)} added to ${t.toPoint}'
          : 'Failed to record receipt',
      ok ? AppTheme.success : AppTheme.danger,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: 'New Transfer'),
              Tab(text: 'Delivering'),
              Tab(text: 'Receiving'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNewTransfer(),
              _buildDelivering(),
              _buildReceiving(),
            ],
          ),
        ),
      ],
    );
  }

  // ── New Transfer ── (enterprise: between Thavvu Points)
  Widget _buildNewTransfer() {
    final points = <String, String>{}; // id -> name
    // Preferred: the Thavvu Points HOD created for the site.
    for (final p in _thavvuPoints) {
      final id = p['id']?.toString() ?? '';
      final name = p['point_name']?.toString() ?? '';
      if (id.isNotEmpty && name.isNotEmpty) points[id] = name;
    }
    // Fallback (pre-migration / no points yet): balance-backed stock points.
    if (points.length < 2) {
      for (final b in _balances) {
        points[b.stockPointId] = b.stockPointName;
      }
    }
    if (points.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Need at least two Thavvu Points (or stock points) to create a transfer. HOD creates Thavvu Points at the site.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _NewTransferForm(
        balances: _balances,
        points: points,
        repo: _repo,
        contextService: _contextService,
        onCreated: () {
          _load();
          _stockSnack(context, 'Transfer initiated — deliver it from the '
              'Delivering tab.', AppTheme.info);
          _tabController.animateTo(1);
        },
      ),
    );
  }

  // ── Delivering ── (ONLY transfers I send FROM my points)
  Widget _buildDelivering() {
    final outbound = _myDeliveries;
    final active = outbound.where((t) => t.status == 'initiated').toList();
    final delivered =
        outbound.where((t) => t.status == 'delivered').toList();
    final received =
        outbound.where((t) => t.status == 'received').toList();

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (active.isEmpty && delivered.isEmpty && received.isEmpty) {
      return const Center(
        child: Text('No deliveries from your stock points yet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (active.isNotEmpty) ...[
          const _SectionLabel('Pending Delivery',
              Icons.local_shipping_outlined, AppTheme.warning),
          ...active.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.sender,
                actionLabel: 'Mark Delivered',
                actionColor: AppTheme.primary,
                actionIcon: Icons.local_shipping_outlined,
                onAction: () => _confirmDeliver(t),
              )),
        ],
        if (delivered.isNotEmpty) ...[
          const _SectionLabel('Delivered — Awaiting Receive',
              Icons.move_to_inbox_outlined, AppTheme.info),
          ...delivered.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.sender,
                actionLabel: null,
                actionColor: null,
                actionIcon: null,
                onAction: null,
              )),
        ],
        if (received.isNotEmpty) ...[
          const _SectionLabel('Received ✓',
              Icons.check_circle_outline, AppTheme.success),
          ...received.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.sender,
                actionLabel: null,
                actionColor: null,
                actionIcon: null,
                onAction: null,
              )),
        ],
      ],
    );
  }

  // ── Receiving ── (ONLY transfers sent TO my points)
  Widget _buildReceiving() {
    final inbound = _myReceives;
    final awaiting =
        inbound.where((t) => t.status == 'initiated').toList();
    final toReceive =
        inbound.where((t) => t.status == 'delivered').toList();
    final received =
        inbound.where((t) => t.status == 'received').toList();

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (awaiting.isEmpty && toReceive.isEmpty && received.isEmpty) {
      return const Center(
        child: Text('No transfers to receive at your stock points yet.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (awaiting.isNotEmpty) ...[
          const _SectionLabel('In Transit — Awaiting Delivery',
              Icons.pending_outlined, AppTheme.info),
          ...awaiting.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.receiver,
                actionLabel: null,
                actionColor: null,
                actionIcon: null,
                onAction: null,
              )),
        ],
        if (toReceive.isNotEmpty) ...[
          const _SectionLabel('Ready to Receive',
              Icons.move_to_inbox_outlined, AppTheme.success),
          ...toReceive.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.receiver,
                actionLabel: 'Receive & Add to Stock',
                actionColor: AppTheme.success,
                actionIcon: Icons.fact_check_outlined,
                onAction: () => _openReceiveChecklist(t),
              )),
        ],
        if (received.isNotEmpty) ...[
          const _SectionLabel('Received ✓',
              Icons.check_circle_outline, AppTheme.textMuted),
          ...received.map((t) => _TransferCard(
                t: t,
                perspective: _TransferPerspective.receiver,
                actionLabel: null,
                actionColor: null,
                actionIcon: null,
                onAction: null,
              )),
        ],
      ],
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

enum _TransferPerspective { sender, receiver }

class _TransferCard extends StatelessWidget {
  final StockTransfer t;
  final _TransferPerspective perspective;
  final String? actionLabel;
  final Color? actionColor;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _TransferCard({
    required this.t,
    required this.perspective,
    required this.actionLabel,
    required this.actionColor,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.transferNo,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ),
              _MiniTag(
                t.status == 'initiated'
                    ? 'Initiated'
                    : t.status == 'delivered'
                        ? 'Delivered'
                        : 'Received',
                t.status == 'initiated'
                    ? AppTheme.warning
                    : t.status == 'delivered'
                        ? AppTheme.info
                        : AppTheme.success,
                icon: t.status == 'initiated'
                    ? Icons.pending_outlined
                    : t.status == 'delivered'
                        ? Icons.local_shipping_outlined
                        : Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(t.itemName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.qr_code_2,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('Batch ${t.batch}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const Spacer(),
              Text('${_qtyFmt(t.quantity)} ${t.unit}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.outbox_outlined,
                  size: 14, color: AppTheme.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.fromPoint,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
              const Icon(Icons.arrow_forward,
                  size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              const Icon(Icons.inbox_outlined,
                  size: 14, color: AppTheme.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t.toPoint,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          if (t.notes != null && t.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.notes!,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 10),
          _buildHandshakeRow(),
          if (t.status == 'received' && _hasReceiveDetails) ...[
            const SizedBox(height: 8),
            _buildReceiveDetails(),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Two-hop status chain: 🚚 Delivered ─▶ ✓ Received.
  /// From the SENDER's perspective the "Received" hop is the other side's
  /// action — it lights up when the receiver confirms (deliverer sees the
  /// received icon). From the RECEIVER's perspective the "Delivered" hop is
  /// the other side's action — it lights up when the sender delivers
  /// (receiver sees the delivered icon).
  Widget _buildHandshakeRow() {
    final delivered = t.status == 'delivered' || t.status == 'received';
    final received = t.status == 'received';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HandshakeHop(
              icon: Icons.local_shipping_outlined,
              label: 'Delivered',
              detail: _deliveredDetail,
              active: delivered,
              highlight:
                  perspective == _TransferPerspective.receiver && delivered,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward,
                size: 14, color: AppTheme.textMuted),
          ),
          Expanded(
            child: _HandshakeHop(
              icon: Icons.fact_check_outlined,
              label: 'Received',
              detail: _receivedDetail,
              active: received,
              highlight: perspective == _TransferPerspective.sender && received,
            ),
          ),
        ],
      ),
    );
  }

  String get _deliveredDetail {
    if (t.status != 'delivered' && t.status != 'received') return 'Pending';
    final who = t.deliveredBy ?? '';
    return who.isEmpty ? 'Confirmed' : 'by $who';
  }

  String get _receivedDetail {
    if (t.status != 'received') return 'Awaiting';
    final who = t.receivedByName ?? t.receivedBy ?? '';
    return who.isEmpty ? 'Confirmed' : 'by $who';
  }

  bool get _hasReceiveDetails =>
      t.receivedQuantity != null ||
      (t.receivedCondition?.isNotEmpty ?? false) ||
      t.receiveChecklist.isNotEmpty ||
      (t.receiveNotes?.isNotEmpty ?? false);

  Widget _buildReceiveDetails() {
    final chips = <Widget>[];
    if (t.receivedQuantity != null) {
      chips.add(_MiniTag(
        'Received ${_qtyFmt(t.receivedQuantity!)}',
        AppTheme.success,
        icon: Icons.check_circle_outline,
      ));
    }
    if (t.receivedCondition != null && t.receivedCondition!.isNotEmpty) {
      chips.add(_MiniTag(
        t.receivedCondition!,
        AppTheme.warning,
        icon: Icons.verified_outlined,
      ));
    }
    for (final item in t.receiveChecklist) {
      chips.add(_MiniTag(item, AppTheme.info, icon: Icons.check));
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: chips),
          if (t.receiveNotes != null && t.receiveNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(t.receiveNotes!,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  String _qtyFmt(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}

/// Two-hop status chain shown on every transfer card:
///   🚚 Delivered  ─▶  ✓ Received
/// From the SENDER's perspective the "Received" hop is the other side's
/// action — it lights up when the receiver confirms (deliverer sees the
/// received icon). From the RECEIVER's perspective the "Delivered" hop is
/// the other side's action — it lights up when the sender delivers
/// (receiver sees the delivered icon).
class _HandshakeHop extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  final bool active;
  final bool highlight;

  const _HandshakeHop({
    required this.icon,
    required this.label,
    required this.detail,
    required this.active,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.success : AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.success.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? AppTheme.textSecondary
                            : AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewTransferForm extends StatefulWidget {
  final List<StockBatchBalance> balances;
  final Map<String, String> points;
  final StockInventoryRepository repo;
  final AttendanceContextService contextService;
  final VoidCallback onCreated;

  const _NewTransferForm({
    required this.balances,
    required this.points,
    required this.repo,
    required this.contextService,
    required this.onCreated,
  });

  @override
  State<_NewTransferForm> createState() => _NewTransferFormState();
}

class _NewTransferFormState extends State<_NewTransferForm> {
  String? _fromPointId;
  String? _toPointId;
  StockBatchBalance? _balance;
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  List<String> get _fromOptions {
    final ids = <String>{};
    for (final b in widget.balances) {
      ids.add(b.stockPointId);
    }
    return ids.toList();
  }

  List<String> get _toOptions =>
      widget.points.keys.where((id) => id != _fromPointId).toList();

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_fromPointId == null ||
        _toPointId == null ||
        _balance == null) {
      _stockSnack(context, 'Select from point, item and to point.',
          AppTheme.warning);
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _stockSnack(context, 'Enter a valid quantity.', AppTheme.warning);
      return;
    }
    if (qty > _balance!.availableQty) {
      _stockSnack(
          context,
          'Quantity exceeds available (${_balance!.availableQty}).',
          AppTheme.warning);
      return;
    }
    setState(() => _saving = true);
    // The session Thavvu Point the supervisor is working on — every stock
    // row is scoped to it so reports aggregate per point.
    final sessionPointId = await widget.contextService.resolvePointId();
    final fromName = widget.points[_fromPointId] ?? _fromPointId!;
    final toName = widget.points[_toPointId] ?? _toPointId!;
    final ok = await widget.repo.createTransfer(
      transferNo: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
      siteId: null,
      fromPointId: _fromPointId!,
      fromPoint: fromName,
      toPointId: _toPointId!,
      toPoint: toName,
      fromThavvuPointId: _fromPointId,
      fromThavvuPoint: fromName,
      toThavvuPointId: _toPointId,
      toThavvuPoint: toName,
      itemId: _balance!.itemId,
      itemName: _balance!.itemName,
      batch: _balance!.batchId,
      quantity: qty,
      looseQuantity: 0,
      unit: 'units',
      notes: _notesCtrl.text.trim(),
      thavvuPointId: sessionPointId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _qtyCtrl.clear();
      _notesCtrl.clear();
      widget.onCreated();
    } else {
      _stockSnack(context, 'Failed to create transfer', AppTheme.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromBalances = _fromPointId == null
        ? <StockBatchBalance>[]
        : widget.balances
            .where((b) => b.stockPointId == _fromPointId)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create Internal Transfer',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        const Text(
            'Transfer stock between Thavvu Points. Delivered deducts the sender, received adds the receiver — tracked per point.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _fromPointId,
          decoration: _fieldDec('From Thavvu Point', Icons.outbox_outlined),
          items: _fromOptions
              .map((id) => DropdownMenuItem(
                  value: id, child: Text(widget.points[id] ?? id)))
              .toList(),
          onChanged: (v) => setState(() {
            _fromPointId = v;
            _balance = null;
            _toPointId = null;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _toPointId,
          decoration: _fieldDec('To Thavvu Point', Icons.inbox_outlined),
          items: _toOptions
              .map((id) => DropdownMenuItem(
                  value: id, child: Text(widget.points[id] ?? id)))
              .toList(),
          onChanged: (v) => setState(() => _toPointId = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _balance?.id,
          decoration: _fieldDec('Item / Batch', Icons.inventory_2_outlined),
          items: fromBalances
              .map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                        '${b.itemName} • ${b.batchId} (${b.availableQty})',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            final b = fromBalances.firstWhere((x) => x.id == v);
            setState(() => _balance = b);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _fieldDec('Quantity', Icons.numbers_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: _fieldDec('Notes (optional)', Icons.notes_outlined),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_outlined, size: 18),
            label: const Text('Initiate Transfer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}

// ─── CONSUMPTION SHEET — batch qty + photo proof → auto stock update ─────────

class _ConsumptionSheet extends StatefulWidget {
  final AquaStockPoint point;
  final List<AquaBatchBalance> batches;
  final String Function(String itemId) itemNameOf;
  final String Function(String itemId) itemCodeOf;
  final VoidCallback onDone;

  const _ConsumptionSheet({
    required this.point,
    required this.batches,
    required this.itemNameOf,
    required this.itemCodeOf,
    required this.onDone,
  });

  @override
  State<_ConsumptionSheet> createState() => _ConsumptionSheetState();
}

class _ConsumptionSheetState extends State<_ConsumptionSheet> {
  final _repo = StockInventoryRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  final _photoService = PhotoUploadService();
  AquaBatchBalance? _batch;
  final _qtyCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  ({Uint8List bytes, String ext})? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final photo = await _captureStockPhoto();
    if (photo == null) return;
    if (!mounted) return;
    setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    final batch = _batch;
    if (batch == null) {
      _stockSnack(context, 'Select a batch to consume.', AppTheme.warning);
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _stockSnack(context, 'Enter a valid quantity.', AppTheme.warning);
      return;
    }
    if (qty > batch.currentQty) {
      _stockSnack(
          context, 'Quantity exceeds available (${batch.currentQty}).',
          AppTheme.warning);
      return;
    }
    setState(() => _saving = true);

    // Upload the proof photo first (if captured).
    String? photoName;
    if (_photo != null) {
      photoName = await _photoService.uploadStockPhoto(
        'CONS-${DateTime.now().millisecondsSinceEpoch}',
        _photo!.bytes,
        context: 'consumption',
        ext: _photo!.ext,
      );
    }

    final balance = StockBatchBalance(
      id: batch.id,
      itemId: batch.itemId,
      itemName: widget.itemNameOf(batch.itemId),
      itemCode: widget.itemCodeOf(batch.itemId),
      stockPointId: batch.stockPointId,
      stockPointName: widget.point.name,
      location: widget.point.name,
      batchId: batch.batchCode,
      availableQty: batch.currentQty,
      looseQty: 0,
      updatedAt: null,
    );

    final ok = await _repo.recordConsumption(
      siteId: null,
      balance: balance,
      quantity: qty,
      looseQuantity: 0,
      reason: _reasonCtrl.text.trim().isEmpty
          ? 'Consumption'
          : _reasonCtrl.text.trim(),
      photoName: photoName,
      // Tag the consumption with the supervisor's session Thavvu Point so
      // stock consumption reports aggregate per point.
      thavvuPointId: await _contextService.resolvePointId(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _stockSnack(
      context,
      ok
          ? 'Consumption recorded — stock updated automatically'
          : 'Failed to record consumption',
      ok ? AppTheme.success : AppTheme.danger,
    );
    if (ok) {
      widget.onDone();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.remove_circle_outline,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                const Text('Record Consumption',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Consume from ${widget.point.name} with batch quantity and photo proof. Stock updates automatically.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _batch?.id,
              decoration: InputDecoration(
                labelText: 'Item / Batch',
                prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: widget.batches
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                            '${widget.itemNameOf(b.itemId)} • ${b.batchCode} (${b.currentQty})',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() =>
                    _batch = widget.batches.firstWhere((b) => b.id == v));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Batch Quantity',
                prefixIcon: const Icon(Icons.numbers_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Purpose / Reason',
                prefixIcon: const Icon(Icons.notes_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            // Photo proof
            InkWell(
              onTap: _capture,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _photo == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle,
                      color: _photo == null
                          ? AppTheme.primary
                          : AppTheme.success,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _photo == null
                            ? 'Capture photo proof'
                            : 'Photo captured ✓',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _photo == null
                                ? AppTheme.primary
                                : AppTheme.success),
                      ),
                    ),
                    if (_photo != null)
                      const Icon(Icons.camera_alt,
                          size: 16, color: AppTheme.success),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                    _saving ? 'Recording...' : 'Confirm Consumption',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── INTERNAL TRANSFER RECEIVE CHECKLIST ────────────────────────────────────
// The receiving person verifies the goods (quantity / batch / condition /
// packaging), records the actually received quantity and condition, and only
// then is stock added to the destination point.

class _ReceiveChecklistResult {
  final double receivedQuantity;
  final String condition;
  final List<String> checkedItems;
  final String notes;
  final String receiverName;

  const _ReceiveChecklistResult({
    required this.receivedQuantity,
    required this.condition,
    required this.checkedItems,
    required this.notes,
    required this.receiverName,
  });
}

class _ReceiveChecklistModel {
  final String label;
  bool checked;

  _ReceiveChecklistModel(this.label, {this.checked = false});
}

class _ReceiveChecklistSheet extends StatefulWidget {
  final StockTransfer transfer;

  const _ReceiveChecklistSheet({required this.transfer});

  @override
  State<_ReceiveChecklistSheet> createState() => _ReceiveChecklistSheetState();
}

class _ReceiveChecklistSheetState extends State<_ReceiveChecklistSheet> {
  late final List<_ReceiveChecklistModel> _checks;
  late final TextEditingController _qtyCtrl;
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _condition = 'Good condition';
  bool _saving = false;

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  @override
  void initState() {
    super.initState();
    _checks = [
      _ReceiveChecklistModel(
          'Quantity matches the transfer order (${_qty(widget.transfer.quantity)} ${widget.transfer.unit})'),
      _ReceiveChecklistModel('Batch number matches the transfer record'),
      _ReceiveChecklistModel('Items inspected and in good condition'),
      _ReceiveChecklistModel('Packaging / units counted correctly'),
    ];
    _qtyCtrl = TextEditingController(text: _qty(widget.transfer.quantity));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return qty > 0 &&
        _nameCtrl.text.trim().isNotEmpty &&
        _checks.every((c) => c.checked);
  }

  Future<void> _confirm() async {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _stockSnack(context, 'Enter a valid received quantity.',
          AppTheme.warning);
      return;
    }
    setState(() => _saving = true);
    // Allow the repository a moment to persist so the spinner is visible.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.pop(
      context,
      _ReceiveChecklistResult(
        receivedQuantity: qty,
        condition: _condition,
        checkedItems: _checks.where((c) => c.checked).map((c) => c.label).toList(),
        notes: _notesCtrl.text.trim(),
        receiverName: _nameCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Material(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fact_check_outlined,
                        color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Receive & Add to Stock',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        Text(
                            'Verify the goods before confirming the receipt',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.transferNo} • ${t.itemName}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Batch ${t.batch} • Ordered ${_qty(t.quantity)} ${t.unit}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Text('${t.fromPoint} → ${t.toPoint}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Verification Checklist',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              ..._checks.map((item) {
                return CheckboxListTile(
                  value: item.checked,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.success,
                  title: Text(item.label,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textPrimary,
                          height: 1.3)),
                  onChanged: (v) => setState(() => item.checked = v ?? false),
                );
              }),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Received Quantity',
                        prefixIcon: Icon(Icons.numbers_outlined, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: _condition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        prefixIcon: Icon(Icons.verified_outlined, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Good condition',
                            child: Text('Good condition')),
                        DropdownMenuItem(
                            value: 'Minor damage',
                            child: Text('Minor damage')),
                        DropdownMenuItem(
                            value: 'Short quantity',
                            child: Text('Short quantity')),
                        DropdownMenuItem(
                            value: 'Rejected',
                            child: Text('Rejected')),
                      ],
                      onChanged: (v) =>
                          setState(() => _condition = v ?? 'Good condition'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Received By (name)',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_saving || !_canConfirm) ? null : _confirm,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.inventory_outlined, size: 18),
                  label: const Text('Verify & Add to Stock',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only confirmed quantity is added to the destination stock point.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
