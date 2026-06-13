
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
// THEME
// ══════════════════════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  static const Color primary       = Color(0xFF4F6AF5);
  static const Color success       = Color(0xFF22C55E);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color danger        = Color(0xFFEF4444);
  static const Color info          = Color(0xFF3B82F6);

  static const Color surface       = Color(0xFFF8FAFC);
  static const Color surfaceCard   = Color(0xFFFFFFFF);
  static const Color border        = Color(0xFFE2E8F0);

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);

  static const Color successBg = Color(0xFFF0FDF4);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color dangerBg  = Color(0xFFFFF1F2);
  static const Color infoBg    = Color(0xFFEFF6FF);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
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
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: primary,
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
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
      {super.key,
      this.text = 'Requires HOD approval before processing'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppTheme.warning.withOpacity(0.25)),
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
  double get stockPercentage =>
      (reorderLevel == 0) ? 100 : ((remaining / reorderLevel) * 100).clamp(0, 200);
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

class GINBillItem {
  final int sno;
  final String itemName;
  final double orderedQty;
  final double billedQty;
  double receivedQty;
  bool acknowledged; // NEW: user must acknowledge discrepancies

  GINBillItem({
    required this.sno,
    required this.itemName,
    required this.orderedQty,
    required this.billedQty,
    required this.receivedQty,
    this.acknowledged = false,
  });

  double get diffBilledReceived  => billedQty  - receivedQty;
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

// Simplified: just a name + timestamp (no type categorisation)
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

// ══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class StockInventoryScreen extends StatefulWidget {
  const StockInventoryScreen({super.key});

  @override
  State<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends State<StockInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StockPoint? _selectedPoint;

  static const List<StockPoint> _stockPoints = [
    StockPoint(
        id: 'SP-001', name: 'Site A — North', location: 'North Block',
        batchId: 'B-042', onHand: 450, todayUsage: 12, reorderLevel: 20,
        totalIn: 750, totalOut: 300),
    StockPoint(
        id: 'SP-002', name: 'Site B — South', location: 'South Block',
        batchId: 'B-039', onHand: 200, todayUsage: 8, reorderLevel: 30,
        totalIn: 400, totalOut: 200),
    StockPoint(
        id: 'SP-003', name: 'Warehouse Main', location: 'Central Store',
        batchId: 'B-031', onHand: 18, todayUsage: 5, reorderLevel: 20,
        totalIn: 600, totalOut: 582),
    StockPoint(
        id: 'SP-004', name: 'Field Store', location: 'Field Office',
        batchId: 'B-044', onHand: 120, todayUsage: 20, reorderLevel: 15,
        totalIn: 300, totalOut: 180),
  ];

  static const List<StockMovement> _movements = [
    StockMovement(type: 'in',       item: 'Diesel',          quantity: 80,  batch: 'B-042', date: 'Today 9:10 AM',   by: 'HOD Approved'),
    StockMovement(type: 'out',      item: 'Diesel',          quantity: 12,  batch: 'B-042', date: 'Today 11:30 AM',  by: 'MCH-001'),
    StockMovement(type: 'in',       item: 'Engine Oil',      quantity: 20,  batch: 'B-041', date: 'Yesterday',       by: 'HOD Approved'),
    StockMovement(type: 'return',   item: 'Bolts & Nuts',    quantity: 5,   batch: 'B-038', date: '12 May',          by: 'RET-0089'),
    StockMovement(type: 'transfer', item: 'Hydraulic Fluid', quantity: 10,  batch: 'B-040', date: '11 May',          by: 'SP-001→SP-002'),
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
            GINBillItem(sno: 1, itemName: 'Floating Fish Feed (3mm)', orderedQty: 200, billedQty: 200, receivedQty: 180),
            GINBillItem(sno: 2, itemName: 'Sinking Pellets (5mm)',    orderedQty: 150, billedQty: 150, receivedQty: 150),
          ],
        ),
        GINBill(
          billNumber: 'BILL-2024-002',
          supplierName: 'Marine Equipments Co.',
          items: [
            GINBillItem(sno: 1, itemName: 'Aerator Pump (2HP)',   orderedQty: 5,  billedQty: 5,  receivedQty: 3),
            GINBillItem(sno: 2, itemName: 'Water Quality Sensor', orderedQty: 10, billedQty: 10, receivedQty: 10),
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
            GINBillItem(sno: 1, itemName: 'HDPE Net (100m roll)', orderedQty: 20, billedQty: 20, receivedQty: 15),
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
            GINBillItem(sno: 1, itemName: 'Oxytetracycline (1kg)', orderedQty: 50,  billedQty: 50,  receivedQty: 50),
            GINBillItem(sno: 2, itemName: 'Probiotics (500g)',      orderedQty: 30,  billedQty: 30,  receivedQty: 25),
            GINBillItem(sno: 3, itemName: 'Vitamin Premix',         orderedQty: 100, billedQty: 100, receivedQty: 95),
          ],
        ),
        GINBill(
          billNumber: 'BILL-2024-005',
          supplierName: 'AquaFeed Ltd.',
          items: [
            GINBillItem(sno: 1, itemName: 'Spirulina Powder (1kg)', orderedQty: 40, billedQty: 40, receivedQty: 40),
          ],
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      appBar: AppBar(
        title: const Text('Stock Inventory'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.maybePop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Stock',       icon: Icon(Icons.dashboard_customize_outlined, size: 18)),
            Tab(text: 'User Entry',  icon: Icon(Icons.edit_note,          size: 18)),
            Tab(text: 'Raise Order', icon: Icon(Icons.add_shopping_cart,   size: 18)),
            Tab(text: 'Return',      icon: Icon(Icons.assignment_return,   size: 18)),
            Tab(text: 'Other Consumables', icon: Icon(Icons.outbound_outlined, size: 18)),
            Tab(text: 'GIN',         icon: Icon(Icons.receipt_long,        size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _StockFeatureTab(),
          _ViewStockTab(
            points: _stockPoints,
            movements: _movements,
            selectedPoint: _selectedPoint,
            onSelect: (p) => setState(() => _selectedPoint = p),
          ),
          _RaiseOrderTab(stockPoints: _stockPoints),
          _ReturnTab(stockPoints: _stockPoints),
          _OtherConsumablesTab(stockPoints: _stockPoints),
          _GINTab(ginStockPoints: _ginStockPoints),
        ],
      ),
    );
  }
}



// ══════════════════════════════════════════════════════════════════════════════
// FEATURE TAB — STOCK
// Production-shaped, mobile-first, offline-first, Tally-like aquaculture stock UI.
// Includes:
//   • Item-wise matrix with search/filter
//   • Category/group drill-down
//   • Stock-point/tank batch dashboard
//   • Voucher entry with validation, UoM conversion, idempotency key, payload hash
//   • Local pending queue + manual sync simulation
//   • Reports: Stock Summary, Godown Summary, Batch Summary, Movement Analysis, FCR
// ══════════════════════════════════════════════════════════════════════════════

enum StockFeatureView { summary, itemWise, categoryWise, stockPoint, entry, reports }
enum AquaVoucherType { receipt, issue, transfer, mortality, harvest, adjustment, physicalVerification }
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
  final String id, code, name, group, category, primaryUom, purchaseUom, stockNature;
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
  final String batchCode, itemId, stockPointId, expectedHarvestDate, status;
  final double openingQty, currentQty, mortalityCount, avgWeightG, feedKg, totalIn, totalOut;
  final bool synced;

  const AquaBatchBalance({
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
  double get survivalPct => openingQty <= 0 ? 100 : ((openingQty - mortalityCount) / openingQty * 100).clamp(0, 100).toDouble();
  double get biomassGainKg => biomassKg <= 0 ? 0 : biomassKg;
  double get fcr => biomassGainKg <= 0 ? 0 : feedKg / biomassGainKg;
  bool get isLow => currentQty <= 0 || (openingQty > 0 && currentQty <= openingQty * 0.10);
}

class AquaMovementLine {
  final String id, voucherNo, idempotencyKey, payloadHash, type, itemName, batchCode, fromPoint, toPoint, date, enteredBy, note, uom;
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
    AquaUom(code: 'BAG500', name: 'Seed Bag 500 Nos', kind: 'alternate', baseCode: 'NOS', numerator: 500, decimals: 0),
    AquaUom(code: 'LAKH', name: 'Lakh Nos', kind: 'alternate', baseCode: 'NOS', numerator: 100000, decimals: 2),
    AquaUom(code: 'BAG25', name: 'Feed Bag 25 Kg', kind: 'alternate', baseCode: 'KG', numerator: 25, decimals: 2),
    AquaUom(code: 'SACK50', name: 'Sack 50 Kg', kind: 'alternate', baseCode: 'KG', numerator: 50, decimals: 2),
    AquaUom(code: 'CAN5', name: 'Can 5 Litres', kind: 'alternate', baseCode: 'LITRE', numerator: 5, decimals: 2),
  ];

  static const List<AquaStockPoint> _points = [
    AquaStockPoint(id: 'SP-SITE-01', name: 'Farm Site 1', type: 'site', parent: 'ROOT', locationCode: 'SITE-01'),
    AquaStockPoint(id: 'SP-T01', name: 'Tank-01 Nursery', type: 'nursery_tank', parent: 'Farm Site 1', locationCode: 'T01', capacityLitres: 65000),
    AquaStockPoint(id: 'SP-T02', name: 'Tank-02 Grow-Out', type: 'grow_out_tank', parent: 'Farm Site 1', locationCode: 'T02', capacityLitres: 125000),
    AquaStockPoint(id: 'SP-POND-A1', name: 'Pond-A1', type: 'pond', parent: 'Farm Site 1', locationCode: 'POND-A1'),
    AquaStockPoint(id: 'SP-FEED', name: 'Feed Warehouse', type: 'feed_store', parent: 'Farm Site 1', locationCode: 'FW-01'),
    AquaStockPoint(id: 'SP-EQ', name: 'Equipment Shed', type: 'equipment_shed', parent: 'Farm Site 1', locationCode: 'EQ-01'),
    AquaStockPoint(id: 'SP-HOLD', name: 'Harvest Holding Tank', type: 'harvest_holding', parent: 'Farm Site 1', locationCode: 'HH-01', capacityLitres: 35000),
  ];

  static const List<AquaStockItem> _items = [
    AquaStockItem(id: 'IT-ROHU', code: 'FISH-ROHU-FRY', name: 'Rohu Fry', group: 'Fish Seed', category: 'Carp Seed', primaryUom: 'NOS', purchaseUom: 'BAG500', stockNature: 'live', reorderLevel: 1000, maintainBatches: true, trackAvgWeight: true, standardCost: 0.85),
    AquaStockItem(id: 'IT-VAN', code: 'SHR-PL12', name: 'Vannamei PL-12', group: 'Fish Seed', category: 'Shrimp Post-Larvae', primaryUom: 'NOS', purchaseUom: 'LAKH', stockNature: 'live', reorderLevel: 50000, maintainBatches: true, trackAvgWeight: true, standardCost: 0.35),
    AquaStockItem(id: 'IT-FEED3', code: 'FD-GRW-3MM', name: 'Floating Pellet 3 mm', group: 'Feed', category: 'Grower Feed', primaryUom: 'KG', purchaseUom: 'BAG25', stockNature: 'consumable', reorderLevel: 300, maintainBatches: true, trackAvgWeight: false, standardCost: 62),
    AquaStockItem(id: 'IT-ZEO', code: 'CHEM-ZEO', name: 'Zeolite Powder', group: 'Chemicals & Medicines', category: 'Water Treatment', primaryUom: 'KG', purchaseUom: 'SACK50', stockNature: 'consumable', reorderLevel: 80, maintainBatches: true, trackAvgWeight: false, standardCost: 38),
    AquaStockItem(id: 'IT-PROB', code: 'MED-PROB-LIQ', name: 'Liquid Probiotic', group: 'Chemicals & Medicines', category: 'Treatment', primaryUom: 'LITRE', purchaseUom: 'CAN5', stockNature: 'consumable', reorderLevel: 40, maintainBatches: true, trackAvgWeight: false, standardCost: 410),
    AquaStockItem(id: 'IT-AER', code: 'EQ-AER-2HP', name: 'Paddle Wheel Aerator 2HP', group: 'Equipment', category: 'Aeration', primaryUom: 'NOS', purchaseUom: 'NOS', stockNature: 'equipment', reorderLevel: 2, maintainBatches: false, trackAvgWeight: false, standardCost: 38500),
    AquaStockItem(id: 'IT-HARV', code: 'HARV-PANG-KG', name: 'Pangasius Harvest >1 kg', group: 'Harvest', category: 'Table Fish', primaryUom: 'KG', purchaseUom: 'KG', stockNature: 'harvest', reorderLevel: 0, maintainBatches: true, trackAvgWeight: false, standardCost: 118),
  ];

  static const List<AquaBatchBalance> _batches = [
    AquaBatchBalance(batchCode: 'ROHU-T01-2026-MAY-01', itemId: 'IT-ROHU', stockPointId: 'SP-T01', expectedHarvestDate: '15 Nov 2026', status: 'active', openingQty: 10000, currentQty: 9725, mortalityCount: 175, avgWeightG: 36, feedKg: 185, totalIn: 10000, totalOut: 275, synced: true),
    AquaBatchBalance(batchCode: 'ROHU-T02-2026-MAY-28', itemId: 'IT-ROHU', stockPointId: 'SP-T02', expectedHarvestDate: '28 Dec 2026', status: 'active', openingQty: 5000, currentQty: 4860, mortalityCount: 85, avgWeightG: 112, feedKg: 430, totalIn: 5000, totalOut: 140, synced: false),
    AquaBatchBalance(batchCode: 'VAN-POND-A1-2026-MAY', itemId: 'IT-VAN', stockPointId: 'SP-POND-A1', expectedHarvestDate: '12 Sep 2026', status: 'active', openingQty: 300000, currentQty: 287500, mortalityCount: 8500, avgWeightG: 4.8, feedKg: 980, totalIn: 300000, totalOut: 12500, synced: true),
    AquaBatchBalance(batchCode: 'FEED-GRW-BAG25-042', itemId: 'IT-FEED3', stockPointId: 'SP-FEED', expectedHarvestDate: '30 Mar 2027', status: 'active', openingQty: 500, currentQty: 315, mortalityCount: 0, avgWeightG: 0, feedKg: 0, totalIn: 500, totalOut: 185, synced: true),
    AquaBatchBalance(batchCode: 'ZEO-SACK50-011', itemId: 'IT-ZEO', stockPointId: 'SP-FEED', expectedHarvestDate: '10 Jan 2027', status: 'active', openingQty: 180, currentQty: 64, mortalityCount: 0, avgWeightG: 0, feedKg: 0, totalIn: 180, totalOut: 116, synced: false),
    AquaBatchBalance(batchCode: 'PROB-CAN5-008', itemId: 'IT-PROB', stockPointId: 'SP-FEED', expectedHarvestDate: '20 Dec 2026', status: 'active', openingQty: 75, currentQty: 38, mortalityCount: 0, avgWeightG: 0, feedKg: 0, totalIn: 75, totalOut: 37, synced: true),
    AquaBatchBalance(batchCode: 'AER-FARM-2HP', itemId: 'IT-AER', stockPointId: 'SP-EQ', expectedHarvestDate: '-', status: 'active', openingQty: 8, currentQty: 6, mortalityCount: 0, avgWeightG: 0, feedKg: 0, totalIn: 8, totalOut: 2, synced: true),
    AquaBatchBalance(batchCode: 'HARV-HOLD-2026-MAY-27', itemId: 'IT-HARV', stockPointId: 'SP-HOLD', expectedHarvestDate: 'Ready', status: 'harvested', openingQty: 1450, currentQty: 860, mortalityCount: 0, avgWeightG: 0, feedKg: 0, totalIn: 1450, totalOut: 590, synced: true),
  ];

  static const List<AquaMovementLine> _seedMovements = [
    AquaMovementLine(id: 'MV-001', voucherNo: 'STK-RCP-2026-00401', idempotencyKey: 'idem-00401', payloadHash: 'sha256:a801', type: 'receipt', itemName: 'Rohu Fry', batchCode: 'ROHU-T01-2026-MAY-01', fromPoint: 'Supplier', toPoint: 'Tank-01 Nursery', date: 'Today 07:40', enteredBy: 'Mobile-01', note: 'Seed receipt posted offline and synced', uom: 'NOS', qty: 10000, qtyInBase: 10000, synced: true),
    AquaMovementLine(id: 'MV-002', voucherNo: 'STK-ISS-2026-00402', idempotencyKey: 'idem-00402', payloadHash: 'sha256:b123', type: 'issue', itemName: 'Floating Pellet 3 mm', batchCode: 'FEED-GRW-BAG25-042', fromPoint: 'Feed Warehouse', toPoint: 'Consumption', date: 'Today 09:20', enteredBy: 'Operator', note: 'Morning feed issue', uom: 'KG', qty: 35, qtyInBase: 35, synced: true),
    AquaMovementLine(id: 'MV-003', voucherNo: 'STK-MOR-2026-00403', idempotencyKey: 'idem-00403', payloadHash: 'sha256:cd55', type: 'mortality', itemName: 'Rohu Fry', batchCode: 'ROHU-T02-2026-MAY-28', fromPoint: 'Tank-02 Grow-Out', toPoint: 'Mortality Ledger', date: 'Today 11:05', enteredBy: 'Supervisor', note: 'Low DO suspected', uom: 'NOS', qty: 32, qtyInBase: 32, synced: false),
    AquaMovementLine(id: 'MV-004', voucherNo: 'STK-TRF-2026-00404', idempotencyKey: 'idem-00404', payloadHash: 'sha256:ed91', type: 'transfer', itemName: 'Rohu Fry', batchCode: 'ROHU-T02-2026-MAY-28', fromPoint: 'Tank-01 Nursery', toPoint: 'Tank-02 Grow-Out', date: 'Yesterday', enteredBy: 'HOD Approved', note: 'Nursery to grow-out transfer', uom: 'NOS', qty: 5000, qtyInBase: 5000, synced: true),
    AquaMovementLine(id: 'MV-005', voucherNo: 'STK-HAR-2026-00405', idempotencyKey: 'idem-00405', payloadHash: 'sha256:aa77', type: 'harvest', itemName: 'Pangasius Harvest >1 kg', batchCode: 'HARV-HOLD-2026-MAY-27', fromPoint: 'Harvest Holding Tank', toPoint: 'Sales', date: '27 May', enteredBy: 'Manager', note: 'Partial dispatch', uom: 'KG', qty: 590, qtyInBase: 590, synced: true),
  ];

  @override
  void initState() {
    super.initState();
    _entryItem = _items[2];
    _entryUom = _uomByCode(_items[2].purchaseUom);
    _entryFromPoint = _points.firstWhere((p) => p.id == 'SP-FEED');
    _entryToPoint = null;
    _selectedPoint = _points.firstWhere((p) => p.id == 'SP-T02');
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<AquaMovementLine> get _allMovements => [..._localQueue, ..._syncedDuringSession, ..._seedMovements];
  int get _pendingSyncCount => _localQueue.length + _seedMovements.where((m) => !m.synced).length + _batches.where((b) => !b.synced).length;
  int get _lowItemCount => _items.where((i) => _isItemLow(i)).length;
  double get _totalBiomass => _batches.where((b) => _itemById(b.itemId).trackAvgWeight).fold<double>(0, (sum, b) => sum + b.biomassKg);
  double get _totalFeedKg => _batches.fold<double>(0, (sum, b) => sum + b.feedKg);
  double get _inventoryValue => _items.fold<double>(0, (sum, i) => sum + (_totalQtyForItem(i.id) * i.standardCost));

  List<String> get _groups => ['All', ..._items.map((i) => i.group).toSet()];
  List<AquaStockPoint> get _operationalPoints => _points.where((p) => p.type != 'site').toList();

  AquaStockItem _itemById(String id) => _items.firstWhere((i) => i.id == id);
  AquaStockPoint _pointById(String id) => _points.firstWhere((p) => p.id == id);
  AquaUom _uomByCode(String code) => _uoms.firstWhere((u) => u.code == code, orElse: () => _uoms.first);

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
            gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.16), AppTheme.info.withOpacity(0.06)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Stock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text('Aquaculture stock ledger, batches, tank inventory and offline vouchers', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]);

  Widget _buildSyncStrip() {
    final stateColor = switch (_syncState) {
      AquaSyncState.idle => _pendingSyncCount == 0 ? AppTheme.success : AppTheme.warning,
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
          _SyncPill(icon: Icons.phone_android_rounded, label: 'Local-first', color: AppTheme.info),
          const SizedBox(width: 8),
          _SyncPill(icon: Icons.sync_rounded, label: stateText, color: stateColor),
          const Spacer(),
          Text('cursor: $_serverCursor', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        ]),
        if (_lastSyncError != null) ...[
          const SizedBox(height: 8),
          Text(_lastSyncError!, style: const TextStyle(fontSize: 11, color: AppTheme.danger)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuickMetric(label: 'Live Biomass', value: '${_formatNumber(_totalBiomass, decimals: 0)} kg', icon: Icons.bubble_chart_outlined, color: AppTheme.success)),
          const SizedBox(width: 10),
          Expanded(child: _QuickMetric(label: 'Inventory Value', value: '₹${_formatNumber(_inventoryValue, decimals: 0)}', icon: Icons.currency_rupee_rounded, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _syncState == AquaSyncState.syncing ? null : _syncNow, icon: const Icon(Icons.cloud_sync_outlined, size: 18), label: const Text('Sync now'))),
          const SizedBox(width: 10),
          Expanded(
            child: SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              value: _autoRetryEnabled,
              onChanged: (v) => setState(() => _autoRetryEnabled = v),
            ),
          ),
        ]),
        Text('last_sync_ts: $_lastSyncTs', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
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
      child: Row(children: data.map((d) {
        final selected = _view == d.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(d.$3, size: 16, color: selected ? Colors.white : AppTheme.textSecondary),
            label: Text(d.$2),
            selectedColor: AppTheme.primary,
            backgroundColor: AppTheme.surfaceCard,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppTheme.textPrimary),
            side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
            onSelected: (_) => setState(() => _view = d.$1),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildSummaryView() {
    final activeBatches = _batches.where((b) => b.status == 'active').length;
    final lowBatches = _batches.where((b) => b.isLow).length;
    return Column(key: const ValueKey('summary'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 560 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.38,
        children: [
          _KpiCard(title: 'Active Batches', value: '$activeBatches', subtitle: '$lowBatches low attention', icon: Icons.qr_code_2, color: AppTheme.primary),
          _KpiCard(title: 'Stock Points', value: '${_operationalPoints.length}', subtitle: 'tank / pond / store', icon: Icons.warehouse_outlined, color: AppTheme.info),
          _KpiCard(title: 'Feed Used', value: '${_formatNumber(_totalFeedKg, decimals: 0)} kg', subtitle: 'from movement stream', icon: Icons.rice_bowl_outlined, color: AppTheme.warning),
          _KpiCard(title: 'Low Items', value: '$_lowItemCount', subtitle: 'below reorder level', icon: Icons.warning_amber_rounded, color: _lowItemCount == 0 ? AppTheme.success : AppTheme.danger),
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
          const Icon(Icons.verified_user_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Operational Readiness', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
          _MiniTag(_pendingSyncCount == 0 ? 'Clean' : 'Sync pending', _pendingSyncCount == 0 ? AppTheme.success : AppTheme.warning),
        ]),
        const SizedBox(height: 10),
        if (lows.isEmpty)
          const Text('All item balances are above reorder levels. Stock-only operational movements are included in this dashboard.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
        else
          ...lows.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.priority_high_rounded, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${item.name} is at ${_formatNumber(_totalQtyForItem(item.id), decimals: 1)} ${item.primaryUom}. Reorder level: ${_formatNumber(item.reorderLevel, decimals: 1)}.', style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary))),
                ]),
              )),
      ]),
    );
  }

  Widget _buildItemWiseView() {
    final visibleItems = _filteredItems();
    return Column(key: const ValueKey('items'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildFilterBar(),
      const SizedBox(height: 12),
      _CardShell(
        padding: const EdgeInsets.all(0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Text('Item-wise Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text('Horizontal scroll keeps mobile usable for many tanks/stores.', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowMinHeight: 62,
              dataRowMaxHeight: 72,
              columnSpacing: 14,
              columns: [
                const DataColumn(label: SizedBox(width: 160, child: Text('Stock Item'))),
                ..._operationalPoints.map((p) => DataColumn(label: SizedBox(width: 112, child: Text(p.locationCode, overflow: TextOverflow.ellipsis)))),
                const DataColumn(label: SizedBox(width: 86, child: Text('Total'))),
              ],
              rows: visibleItems.map((item) => DataRow(cells: [
                    DataCell(SizedBox(
                      width: 160,
                      child: Row(children: [
                        _NatureDot(color: _natureColor(item.stockNature)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                          Text('${item.category} · ${item.primaryUom}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                        ])),
                      ]),
                    )),
                    ..._operationalPoints.map((point) {
                      final qty = _qtyFor(item.id, point.id);
                      final biomass = _biomassFor(item.id, point.id);
                      final low = item.reorderLevel > 0 && _totalQtyForItem(item.id) <= item.reorderLevel;
                      return DataCell(_MatrixCell(qty: qty, uom: item.primaryUom, biomassKg: biomass, isLow: low));
                    }),
                    DataCell(Text('${_formatNumber(_totalQtyForItem(item.id), decimals: 1)} ${item.primaryUom}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _isItemLow(item) ? AppTheme.danger : AppTheme.textPrimary))),
                  ])).toList(),
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
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search item, code, category, group'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _groupFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Stock Group', prefixIcon: Icon(Icons.account_tree_outlined, size: 18)),
                items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
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
    return Column(key: const ValueKey('category'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Category / Group Drill-down', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      const SizedBox(height: 12),
      ...groups.map((g) {
        final groupItems = _items.where((i) => i.group == g).toList();
        final groupValue = groupItems.fold<double>(0, (sum, i) => sum + _totalQtyForItem(i.id) * i.standardCost);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CardShell(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _NatureDot(color: _natureColor(groupItems.first.stockNature)),
                const SizedBox(width: 8),
                Expanded(child: Text(g, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
                _MiniTag('₹${_formatNumber(groupValue, decimals: 0)}', AppTheme.primary),
              ]),
              const SizedBox(height: 4),
              Text('${groupItems.length} items · parallel stock-category model supported', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              ...groupItems.map((item) => _CategoryItemTile(item: item, qty: _totalQtyForItem(item.id), color: _natureColor(item.stockNature))),
            ]),
          ),
        );
      }),
    ]);
  }

  Widget _buildStockPointView() {
    final point = _selectedPoint ?? _operationalPoints.first;
    final pointBatches = _batches.where((b) => b.stockPointId == point.id).toList();
    final pointValue = pointBatches.fold<double>(0, (sum, b) => sum + b.currentQty * _itemById(b.itemId).standardCost);
    final pointBiomass = pointBatches.where((b) => _itemById(b.itemId).trackAvgWeight).fold<double>(0, (sum, b) => sum + b.biomassKg);
    return Column(key: const ValueKey('stock-point'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardShell(
        child: DropdownButtonFormField<AquaStockPoint>(
          value: point,
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined), labelText: 'Select tank / pond / store'),
          items: _operationalPoints.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} · ${p.friendlyType}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (p) => setState(() => _selectedPoint = p),
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _QuickMetric(label: 'Type', value: point.friendlyType, icon: Icons.category_outlined, color: AppTheme.info)),
        const SizedBox(width: 10),
        Expanded(child: _QuickMetric(label: 'Value', value: '₹${_formatNumber(pointValue, decimals: 0)}', icon: Icons.currency_rupee, color: AppTheme.primary)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _QuickMetric(label: 'Batches', value: '${pointBatches.length}', icon: Icons.qr_code_2, color: AppTheme.warning)),
        const SizedBox(width: 10),
        Expanded(child: _QuickMetric(label: 'Biomass', value: '${_formatNumber(pointBiomass, decimals: 1)} kg', icon: Icons.bubble_chart_outlined, color: AppTheme.success)),
      ]),
      const SizedBox(height: 14),
      if (pointBatches.isEmpty)
        const _EmptyMini(message: 'No active stock found in this stock point.')
      else
        ...pointBatches.map((b) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _BatchCard(batch: b, item: _itemById(b.itemId), point: point))),
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
            const Expanded(child: Text('Offline Voucher Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
            _MiniTag('5–7 fields', AppTheme.info),
          ]),
          const SizedBox(height: 6),
          const Text('Voucher is committed to local queue first. Sync uses idempotency key + payload hash.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<AquaVoucherType>(
            value: _voucherType,
            decoration: const InputDecoration(labelText: 'Voucher Type', prefixIcon: Icon(Icons.receipt_long_outlined)),
            items: AquaVoucherType.values.map((v) => DropdownMenuItem(value: v, child: Text(_voucherLabel(v)))).toList(),
            onChanged: (v) => setState(() {
              _voucherType = v ?? AquaVoucherType.receipt;
              _applyVoucherDefaults();
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AquaStockItem>(
            value: item,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Stock Item', prefixIcon: Icon(Icons.inventory_2_outlined)),
            items: _items.map((i) => DropdownMenuItem(value: i, child: Text('${i.name} · ${i.primaryUom}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (i) => setState(() {
              _entryItem = i;
              _entryUom = i == null ? null : _uomByCode(i.purchaseUom);
            }),
            validator: (v) => v == null ? 'Select stock item' : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _pointDropdown('From', _entryFromPoint, (p) => setState(() => _entryFromPoint = p), allowExternal: _voucherType == AquaVoucherType.receipt)),
            const SizedBox(width: 10),
            Expanded(child: _pointDropdown('To', _entryToPoint, (p) => setState(() => _entryToPoint = p), allowConsumption: _voucherType != AquaVoucherType.receipt && _voucherType != AquaVoucherType.transfer)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
                decoration: InputDecoration(labelText: 'Quantity', prefixIcon: const Icon(Icons.numbers), suffixText: uom?.code),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter valid quantity';
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
                items: _allowedUomsFor(item).map((u) => DropdownMenuItem(value: u, child: Text(u.display, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (u) => setState(() => _entryUom = u),
                validator: (v) => v == null ? 'Select UoM' : null,
              ),
            ),
          ]),
          if (item != null && uom != null) ...[
            const SizedBox(height: 8),
            Text('Base quantity: ${_formatNumber(baseQty, decimals: 3)} ${item.primaryUom}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Narration / Note', prefixIcon: Icon(Icons.notes_outlined), alignLabelWithHint: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingVoucher ? null : _postVoucher,
              icon: _savingVoucher ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_rounded),
              label: Text(_savingVoucher ? 'Saving...' : 'Save Offline Voucher'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ),
          if (_localQueue.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(children: [
              Text('Local Queue (${_localQueue.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(onPressed: _syncState == AquaSyncState.syncing ? null : _syncNow, icon: const Icon(Icons.cloud_upload_outlined, size: 16), label: const Text('Push')),
            ]),
            ..._localQueue.map((m) => _MovementFeedTile(movement: m, onTap: () => _showMovementDetails(m))),
          ],
        ]),
      ),
    );
  }

  Widget _buildReportsView() {
    final reports = ['Stock Summary', 'Godown Summary', 'Batch Summary', 'Movement Analysis', 'FCR Report'];
    return Column(key: const ValueKey('reports'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardShell(
        child: DropdownButtonFormField<String>(
          value: _reportFilter,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Report', prefixIcon: Icon(Icons.analytics_outlined)),
          items: reports.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (r) => setState(() => _reportFilter = r ?? reports.first),
        ),
      ),
      const SizedBox(height: 12),
      if (_reportFilter == 'Stock Summary') _buildStockSummaryReport(),
      if (_reportFilter == 'Godown Summary') _buildGodownSummaryReport(),
      if (_reportFilter == 'Batch Summary') _buildBatchSummaryReport(),
      if (_reportFilter == 'Movement Analysis') _buildMovementAnalysisReport(),
      if (_reportFilter == 'FCR Report') _buildFcrReport(),
    ]);
  }

  Widget _buildStockSummaryReport() => _ReportCard(
        title: 'Stock Summary',
        subtitle: 'Group, item and total balance across all stock points.',
        rows: _items.map((i) => [_natureLabel(i.stockNature), i.name, '${_formatNumber(_totalQtyForItem(i.id), decimals: 2)} ${i.primaryUom}', '₹${_formatNumber(_totalQtyForItem(i.id) * i.standardCost, decimals: 0)}']).toList(),
      );

  Widget _buildGodownSummaryReport() => _ReportCard(
        title: 'Godown / Stock-point Summary',
        subtitle: 'Tally-like location roll-up for tanks, pond, feed store and equipment shed.',
        rows: _operationalPoints.map((p) {
          final qty = _batches.where((b) => b.stockPointId == p.id).fold<double>(0, (sum, b) => sum + b.currentQty);
          final value = _batches.where((b) => b.stockPointId == p.id).fold<double>(0, (sum, b) => sum + b.currentQty * _itemById(b.itemId).standardCost);
          return [p.locationCode, p.name, _formatNumber(qty, decimals: 2), '₹${_formatNumber(value, decimals: 0)}'];
        }).toList(),
      );

  Widget _buildBatchSummaryReport() => _ReportCard(
        title: 'Batch Summary',
        subtitle: 'Batch-level current quantity, biomass and expected harvest date.',
        rows: _batches.map((b) {
          final item = _itemById(b.itemId);
          return [b.batchCode, item.name, '${_formatNumber(b.currentQty, decimals: 1)} ${item.primaryUom}', item.trackAvgWeight ? '${_formatNumber(b.biomassKg, decimals: 1)} kg' : b.expectedHarvestDate];
        }).toList(),
      );

  Widget _buildMovementAnalysisReport() => _ReportCard(
        title: 'Movement Analysis',
        subtitle: 'Includes stock-only operational vouchers, not only accounting-linked entries.',
        rows: _allMovements.map((m) => [m.voucherNo, m.type, '${m.fromPoint} → ${m.toPoint}', '${_formatNumber(m.qtyInBase, decimals: 2)} ${m.uom}']).toList(),
      );

  Widget _buildFcrReport() => _ReportCard(
        title: 'FCR Report',
        subtitle: 'Feed conversion ratio = feed kg / biomass gain kg for live batches.',
        rows: _batches.where((b) => _itemById(b.itemId).trackAvgWeight).map((b) => [b.batchCode, _pointById(b.stockPointId).locationCode, '${_formatNumber(b.feedKg, decimals: 1)} kg feed', b.fcr == 0 ? 'N/A' : b.fcr.toStringAsFixed(3)]).toList(),
      );

  Widget _pointDropdown(String label, AquaStockPoint? value, ValueChanged<AquaStockPoint?> onChanged, {bool allowExternal = false, bool allowConsumption = false}) {
    return DropdownButtonFormField<AquaStockPoint?>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowExternal) const DropdownMenuItem<AquaStockPoint?>(value: null, child: Text('External')),
        if (allowConsumption) const DropdownMenuItem<AquaStockPoint?>(value: null, child: Text('Ledger / Consumption')),
        ..._operationalPoints.map((p) => DropdownMenuItem<AquaStockPoint?>(value: p, child: Text(p.locationCode, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: onChanged,
      validator: (_) {
        if (_voucherType == AquaVoucherType.receipt && label == 'To' && _entryToPoint == null) return 'Required';
        if (_voucherType == AquaVoucherType.transfer && (_entryFromPoint == null || _entryToPoint == null)) return 'Required';
        if (_voucherType != AquaVoucherType.receipt && _voucherType != AquaVoucherType.transfer && label == 'From' && _entryFromPoint == null) return 'Required';
        return null;
      },
    );
  }

  Widget _buildMovementFeed({int limit = 5}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Movement Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const Spacer(),
          _MiniTag('append-only', AppTheme.success),
        ]),
        const SizedBox(height: 10),
        ..._allMovements.take(limit).map((m) => _MovementFeedTile(movement: m, onTap: () => _showMovementDetails(m))),
      ]);

  Future<void> _postVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _entryItem;
    final uom = _entryUom;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (item == null || uom == null || qty <= 0) return;
    if (_voucherType == AquaVoucherType.transfer && _entryFromPoint?.id == _entryToPoint?.id) {
      _showSnack('From and To stock points cannot be the same for transfer.', AppTheme.danger, Icons.error_outline);
      return;
    }
    final available = _entryFromPoint == null ? double.infinity : _qtyFor(item.id, _entryFromPoint!.id);
    if (_voucherType != AquaVoucherType.receipt && available.isFinite && uom.toBase(qty) > available) {
      _showSnack('Insufficient stock. Available: ${_formatNumber(available, decimals: 2)} ${item.primaryUom}.', AppTheme.danger, Icons.error_outline);
      return;
    }
    setState(() => _savingVoucher = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    final now = DateTime.now();
    final voucherNo = _makeVoucherNo(_voucherType, now);
    final baseQty = uom.toBase(qty);
    final payload = '${_voucherLabel(_voucherType)}|${item.code}|$qty|${uom.code}|${_entryFromPoint?.id}|${_entryToPoint?.id}|${now.millisecondsSinceEpoch}';
    final line = AquaMovementLine(
      id: 'LOCAL-${now.millisecondsSinceEpoch}',
      voucherNo: voucherNo,
      idempotencyKey: 'idem-${voucherNo.toLowerCase()}-${now.microsecondsSinceEpoch}',
      payloadHash: 'sha256:${payload.hashCode.abs().toRadixString(16)}',
      type: _voucherLabel(_voucherType).toLowerCase(),
      itemName: item.name,
      batchCode: item.maintainBatches ? _makeBatchCode(item, now) : '-',
      fromPoint: _entryFromPoint?.name ?? (_voucherType == AquaVoucherType.receipt ? 'External' : 'Ledger'),
      toPoint: _entryToPoint?.name ?? (_voucherType == AquaVoucherType.receipt ? 'Stock Point' : 'Ledger / Consumption'),
      date: 'Just now',
      enteredBy: 'Local device',
      note: _noteCtrl.text.trim().isEmpty ? 'Queued for sync' : _noteCtrl.text.trim(),
      uom: item.primaryUom,
      qty: qty,
      qtyInBase: baseQty,
      synced: false,
    );
    setState(() {
      _localQueue.insert(0, line);
      _noteCtrl.clear();
      _savingVoucher = false;
    });
    _showSnack('$voucherNo saved locally. Pending sync updated.', AppTheme.success, Icons.check_circle_outline);
  }

  Future<void> _syncNow() async {
    if (_syncState == AquaSyncState.syncing) return;
    setState(() {
      _syncState = AquaSyncState.syncing;
      _lastSyncError = null;
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (_localQueue.isEmpty) {
      setState(() {
        _syncState = AquaSyncState.success;
        _lastSyncTs = 'Just now';
        _serverCursor = 'chg_${DateTime.now().millisecondsSinceEpoch % 1000000}';
      });
      _showSnack('Pull completed. No local vouchers waiting.', AppTheme.info, Icons.cloud_done_outlined);
      return;
    }
    setState(() {
      _syncedDuringSession.insertAll(0, _localQueue.map((m) => m.copyWithSynced()));
      _localQueue.clear();
      _syncState = AquaSyncState.success;
      _lastSyncTs = 'Just now';
      _serverCursor = 'chg_${DateTime.now().millisecondsSinceEpoch % 1000000}';
    });
    _showSnack('Queue pushed successfully. Server cursor updated.', AppTheme.success, Icons.cloud_done_outlined);
  }

  Future<void> _simulatePullRefresh() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _lastSyncTs = 'Just now';
      _serverCursor = 'chg_${DateTime.now().millisecondsSinceEpoch % 1000000}';
      _syncState = AquaSyncState.idle;
    });
  }

  void _applyVoucherDefaults() {
    switch (_voucherType) {
      case AquaVoucherType.receipt:
        _entryFromPoint = null;
        _entryToPoint = _points.firstWhere((p) => p.id == 'SP-FEED');
        break;
      case AquaVoucherType.issue:
      case AquaVoucherType.mortality:
      case AquaVoucherType.harvest:
      case AquaVoucherType.adjustment:
      case AquaVoucherType.physicalVerification:
        _entryFromPoint = _points.firstWhere((p) => p.id == 'SP-FEED');
        _entryToPoint = null;
        break;
      case AquaVoucherType.transfer:
        _entryFromPoint = _points.firstWhere((p) => p.id == 'SP-T01');
        _entryToPoint = _points.firstWhere((p) => p.id == 'SP-T02');
        break;
    }
  }

  void _showMovementDetails(AquaMovementLine m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.voucherNo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          _DetailLine('Type', m.type),
          _DetailLine('Item', m.itemName),
          _DetailLine('Movement', '${m.fromPoint} → ${m.toPoint}'),
          _DetailLine('Batch', m.batchCode),
          _DetailLine('Qty in base UoM', '${_formatNumber(m.qtyInBase, decimals: 3)} ${m.uom}'),
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
      final searchOk = q.isEmpty || '${i.name} ${i.code} ${i.group} ${i.category}'.toLowerCase().contains(q);
      return groupOk && lowOk && searchOk;
    }).toList();
  }

  List<AquaUom> _allowedUomsFor(AquaStockItem? item) {
    if (item == null) return _uoms;
    return _uoms.where((u) => u.code == item.primaryUom || u.code == item.purchaseUom || u.baseCode == item.primaryUom).toList();
  }

  double get _calculatedBaseQty {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return (_entryUom ?? _uoms.first).toBase(qty);
  }

  double _qtyFor(String itemId, String pointId) => _batches.where((b) => b.itemId == itemId && b.stockPointId == pointId).fold<double>(0, (sum, b) => sum + b.currentQty);
  double _totalQtyForItem(String itemId) => _batches.where((b) => b.itemId == itemId).fold<double>(0, (sum, b) => sum + b.currentQty);
  double _biomassFor(String itemId, String pointId) => _batches.where((b) => b.itemId == itemId && b.stockPointId == pointId).fold<double>(0, (sum, b) => sum + b.biomassKg);
  bool _isItemLow(AquaStockItem item) => item.reorderLevel > 0 && _totalQtyForItem(item.id) <= item.reorderLevel;

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

  String _natureLabel(String nature) => nature.isEmpty ? nature : '${nature[0].toUpperCase()}${nature.substring(1)}';

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
    final frac = parts.length > 1 ? parts.last.replaceFirst(RegExp(r'0+$'), '') : '';
    return frac.isEmpty ? whole : '$whole.$frac';
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]),
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
  const _KpiCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
            const Spacer(),
            Icon(Icons.trending_up_rounded, color: color.withOpacity(0.7), size: 16),
          ]),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _SyncPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SyncPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 14), const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color))]),
      );
}

class _QuickMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _QuickMetric({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );
}

class _MatrixCell extends StatelessWidget {
  final double qty, biomassKg;
  final String uom;
  final bool isLow;
  const _MatrixCell({required this.qty, required this.uom, required this.biomassKg, required this.isLow});

  @override
  Widget build(BuildContext context) {
    if (qty <= 0) return const Text('—', style: TextStyle(color: AppTheme.textMuted));
    final color = isLow ? AppTheme.danger : AppTheme.success;
    final formatted = qty >= 100000 ? '${(qty / 100000).toStringAsFixed(2)}L' : qty >= 1000 ? '${(qty / 1000).toStringAsFixed(1)}k' : qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$formatted $uom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
        if (biomassKg > 0) Text('${biomassKg.toStringAsFixed(0)} kg bio', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _CategoryItemTile extends StatelessWidget {
  final AquaStockItem item;
  final double qty;
  final Color color;
  const _CategoryItemTile({required this.item, required this.qty, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          _NatureDot(color: color),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${item.category} · ${item.code}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} ${item.primaryUom}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            _MiniTag(item.stockNature, color),
          ]),
        ]),
      );
}

class _BatchCard extends StatelessWidget {
  final AquaBatchBalance batch;
  final AquaStockItem item;
  final AquaStockPoint point;
  const _BatchCard({required this.batch, required this.item, required this.point});

  @override
  Widget build(BuildContext context) {
    final color = batch.isLow ? AppTheme.danger : AppTheme.success;
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
          _MiniTag(batch.synced ? 'synced' : 'pending', batch.synced ? AppTheme.success : AppTheme.warning, icon: batch.synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined),
        ]),
        const SizedBox(height: 4),
        Text('${batch.batchCode} · ${point.name}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _InlineMetric('Current', '${batch.currentQty.toStringAsFixed(0)} ${item.primaryUom}', color)),
          Expanded(child: _InlineMetric('Biomass', item.trackAvgWeight ? '${batch.biomassKg.toStringAsFixed(1)} kg' : 'N/A', AppTheme.info)),
          Expanded(child: _InlineMetric('Survival', '${batch.survivalPct.toStringAsFixed(1)}%', batch.survivalPct < 95 ? AppTheme.warning : AppTheme.success)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MiniTag('FCR ${batch.fcr == 0 ? 'N/A' : batch.fcr.toStringAsFixed(2)}', AppTheme.primary),
          _MiniTag('Harvest: ${batch.expectedHarvestDate}', AppTheme.info),
          _MiniTag('Mortality ${batch.mortalityCount.toStringAsFixed(0)}', AppTheme.warning),
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color), overflow: TextOverflow.ellipsis),
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
        decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.cardShadow),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(movement.synced ? Icons.check_circle_outline : Icons.schedule_outlined, color: color, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(movement.itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
              _MiniTag(movement.type, color),
            ]),
            const SizedBox(height: 3),
            Text('${movement.fromPoint} → ${movement.toPoint} · ${movement.qtyInBase.toStringAsFixed(movement.qtyInBase.truncateToDouble() == movement.qtyInBase ? 0 : 2)} ${movement.uom} · ${movement.date}', style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
            Text(movement.note, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 18),
        ]),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title, subtitle;
  final List<List<String>> rows;
  const _ReportCard({required this.title, required this.subtitle, required this.rows});

  @override
  Widget build(BuildContext context) => _CardShell(
        padding: const EdgeInsets.all(0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
          ),
          const Divider(height: 1),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(r[0], style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 3, child: Text(r.length > 1 ? r[1] : '', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 3, child: Text(r.length > 2 ? r[2] : '', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
                  Expanded(flex: 2, child: Text(r.length > 3 ? r[3] : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primary), overflow: TextOverflow.ellipsis)),
                ]),
              )),
        ]),
      );
}

class _NatureDot extends StatelessWidget {
  final Color color;
  const _NatureDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DetailLine extends StatelessWidget {
  final String label, value;
  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 112, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
        ]),
      );
}

class _EmptyMini extends StatelessWidget {
  final String message;
  const _EmptyMini({required this.message});

  @override
  Widget build(BuildContext context) => _CardShell(
        child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)))),
      );
}


// ══════════════════════════════════════════════════════════════════════════════
// TAB — OTHER CONSUMABLES
// Records stock consumed for other operational purposes.
// Workflow: Others → choose item → choose available stock point(s) → enter qty
// → reason → submit for reports + HOD review.
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

  const OtherConsumableRecord({
    required this.id,
    required this.itemName,
    required this.itemCode,
    required this.uom,
    required this.reason,
    required this.submittedAt,
    required this.allocations,
    this.status = 'Submitted to HOD',
  });

  double get totalQty => allocations.fold<double>(0, (sum, a) => sum + a.quantity);
}

class OtherConsumableAllocation {
  final String stockPointId;
  final String stockPointName;
  final String location;
  final String batchId;
  final double availableQty;
  final double quantity;

  const OtherConsumableAllocation({
    required this.stockPointId,
    required this.stockPointName,
    required this.location,
    required this.batchId,
    required this.availableQty,
    required this.quantity,
  });
}

class _OtherConsumableItem {
  final String id;
  final String code;
  final String name;
  final String group;
  final String category;
  final String uom;
  final String brand;
  final bool batchRequired;

  const _OtherConsumableItem({
    required this.id,
    required this.code,
    required this.name,
    required this.group,
    required this.category,
    required this.uom,
    required this.brand,
    this.batchRequired = true,
  });
}

class _OtherConsumablesTab extends StatefulWidget {
  final List<StockPoint> stockPoints;
  const _OtherConsumablesTab({required this.stockPoints});

  @override
  State<_OtherConsumablesTab> createState() => _OtherConsumablesTabState();
}

class _OtherConsumablesTabState extends State<_OtherConsumablesTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  _OtherConsumableItem? _selectedItem;
  final Map<String, OtherConsumableAllocation> _selectedAllocations = {};
  final List<OtherConsumableRecord> _submittedRecords = [];
  bool _isSubmitting = false;
  String _purposeFilter = 'All';

  static const List<_OtherConsumableItem> _availableItems = [
    _OtherConsumableItem(id: 'OC-001', code: 'FD-GRW-3MM', name: 'Floating Pellet 3 mm', group: 'Feed', category: 'Grower Feed', uom: 'KG', brand: 'AquaFeed'),
    _OtherConsumableItem(id: 'OC-002', code: 'FD-ST-08', name: 'Starter Feed 0.8 mm', group: 'Feed', category: 'Starter Feed', uom: 'KG', brand: 'AquaFeed'),
    _OtherConsumableItem(id: 'OC-003', code: 'CHEM-ZEO', name: 'Zeolite Powder', group: 'Chemicals & Medicines', category: 'Water Treatment', uom: 'KG', brand: 'BlueAqua'),
    _OtherConsumableItem(id: 'OC-004', code: 'MED-PROB-LIQ', name: 'Liquid Probiotic', group: 'Chemicals & Medicines', category: 'Treatment', uom: 'LITRE', brand: 'PharmaCare Aqua'),
    _OtherConsumableItem(id: 'OC-005', code: 'OIL-ENG-15W40', name: 'Engine Oil 15W-40', group: 'Consumables', category: 'Maintenance', uom: 'LITRE', brand: 'Servo'),
    _OtherConsumableItem(id: 'OC-006', code: 'DSL-HSD', name: 'Diesel', group: 'Consumables', category: 'Fuel', uom: 'LITRE', brand: 'HPCL'),
    _OtherConsumableItem(id: 'OC-007', code: 'NET-HDPE-100M', name: 'HDPE Net 100m', group: 'Equipment', category: 'Nets & Traps', uom: 'NOS', brand: 'Net Solutions'),
    _OtherConsumableItem(id: 'OC-008', code: 'BOLT-MIX', name: 'Bolts & Nuts Set', group: 'Equipment', category: 'Spares', uom: 'NOS', brand: 'Local'),
  ];

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
  void dispose() {
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_OtherConsumableItem> get _filteredItems {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _availableItems.where((item) {
      final text = '${item.name} ${item.code} ${item.group} ${item.category} ${item.brand}'.toLowerCase();
      return q.isEmpty || text.contains(q);
    }).toList();
  }

  double get _totalSelectedQty =>
      _selectedAllocations.values.fold<double>(0, (sum, a) => sum + a.quantity);

  List<StockPoint> get _availableStockPoints {
    if (_selectedItem == null) return widget.stockPoints;
    final item = _selectedItem!;
    return widget.stockPoints.where((point) {
      if (item.group == 'Feed' || item.group == 'Chemicals & Medicines') {
        return point.name.contains('Warehouse') || point.name.contains('Site') || point.name.contains('Field');
      }
      if (item.category == 'Fuel' || item.category == 'Maintenance' || item.category == 'Spares') {
        return point.name.contains('Field') || point.name.contains('Warehouse') || point.name.contains('Site');
      }
      return true;
    }).toList();
  }

  double _availableQtyForPoint(StockPoint point) {
    final item = _selectedItem;
    if (item == null) return point.remaining.toDouble();
    final base = point.remaining.toDouble();
    final factor = switch (item.uom) {
      'KG' => 1.0,
      'LITRE' => point.name.contains('Field') ? 0.75 : 1.35,
      'NOS' => point.name.contains('Warehouse') ? 0.45 : 1.0,
      _ => 1.0,
    };
    return (base * factor).clamp(0, 999999).toDouble();
  }

  void _selectItem(_OtherConsumableItem? item) {
    setState(() {
      _selectedItem = item;
      _selectedAllocations.clear();
    });
  }

  Future<void> _openQuantitySheet(StockPoint point) async {
    final item = _selectedItem;
    if (item == null) {
      _showSnack('Choose an item first.', AppTheme.warning, Icons.info_outline);
      return;
    }

    final available = _availableQtyForPoint(point);
    final existing = _selectedAllocations[point.id];
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
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(point.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('${item.name} · ${point.location} · Batch ${point.batchId}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            _InfoBox(
              icon: Icons.inventory_2_outlined,
              color: AppTheme.info,
              bgColor: AppTheme.infoBg,
              text: 'Available stock: ${_cleanNumber(available)} ${item.uom}. Enter quantity consumed for other purpose.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))],
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
                      setState(() => _selectedAllocations.remove(point.id));
                      Navigator.pop(ctx);
                      _showSnack('Removed ${point.name} from selection.', AppTheme.warning, Icons.remove_circle_outline);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        content: Text('Quantity cannot exceed ${_cleanNumber(available)} ${item.uom}.'),
                        backgroundColor: AppTheme.danger,
                      ));
                      return;
                    }
                    setState(() {
                      _selectedAllocations[point.id] = OtherConsumableAllocation(
                        stockPointId: point.id,
                        stockPointName: point.name,
                        location: point.location,
                        batchId: point.batchId,
                        availableQty: available,
                        quantity: qty,
                      );
                    });
                    Navigator.pop(ctx);
                    _showSnack('Quantity added from ${point.name}.', AppTheme.success, Icons.check_circle_outline);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Add Quantity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _showSnack('Choose item first.', AppTheme.warning, Icons.inventory_2_outlined);
      return;
    }
    if (_selectedAllocations.isEmpty) {
      _showSnack('Select at least one stock point and enter quantity.', AppTheme.warning, Icons.warehouse_outlined);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;

    final item = _selectedItem!;
    final now = DateTime.now();
    final record = OtherConsumableRecord(
      id: 'OTC-${now.year}-${now.millisecondsSinceEpoch % 90000 + 10000}',
      itemName: item.name,
      itemCode: item.code,
      uom: item.uom,
      reason: _reasonCtrl.text.trim(),
      submittedAt: now,
      allocations: _selectedAllocations.values.toList(growable: false),
    );

    setState(() {
      _submittedRecords.insert(0, record);
      _selectedItem = null;
      _selectedAllocations.clear();
      _purposeFilter = 'All';
      _reasonCtrl.clear();
      _searchCtrl.clear();
      _isSubmitting = false;
    });
    _showSnack('${record.id} submitted to Reports and HOD.', AppTheme.success, Icons.send_outlined);
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
            _buildStockPointStep(),
            const SizedBox(height: 16),
            _buildReasonStep(),
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
            gradient: LinearGradient(colors: [AppTheme.danger.withOpacity(0.12), AppTheme.warning.withOpacity(0.07)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.danger.withOpacity(0.18)),
          ),
          child: const Icon(Icons.outbound_outlined, color: AppTheme.danger, size: 28),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Other Consumables', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            SizedBox(height: 4),
            Text('Record stock consumed for other farm purposes and send to HOD reports.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ]),
        ),
      ]);

  Widget _buildSummaryCard() {
    final totalSubmitted = _submittedRecords.length;
    final submittedQty = _submittedRecords.fold<double>(0, (sum, r) => sum + r.totalQty);
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _QuickMetric(label: 'Submitted', value: '$totalSubmitted records', icon: Icons.fact_check_outlined, color: AppTheme.success)),
          const SizedBox(width: 10),
          Expanded(child: _QuickMetric(label: 'Selected Qty', value: _selectedItem == null ? '0' : '${_cleanNumber(_totalSelectedQty)} ${_selectedItem!.uom}', icon: Icons.shopping_bag_outlined, color: AppTheme.primary)),
        ]),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.info_outline,
          color: AppTheme.info,
          bgColor: AppTheme.infoBg,
          text: 'Use this tab when stock is consumed for non-standard purposes like emergency repair, cleaning, testing, or other farm work. The entry is saved as an issue-style voucher for reports and HOD review.',
        ),
        if (submittedQty > 0) ...[
          const SizedBox(height: 10),
          Text('Total submitted quantity this session: ${_cleanNumber(submittedQty)} units across selected UoMs.',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
        ],
      ]),
    );
  }

  Widget _buildItemStep() => _buildStepCard(
        step: '1',
        title: 'Others — Choose Item',
        color: AppTheme.danger,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Search available stock item, code, group, brand',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_OtherConsumableItem>(
            value: _selectedItem,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Choose Item',
              prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
            ),
            items: _filteredItems
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text('${item.name} · ${item.uom}', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _selectItem,
          ),
          if (_selectedItem != null) ...[
            const SizedBox(height: 12),
            _SelectedItemCard(item: _selectedItem!),
          ],
        ]),
      );

  Widget _buildStockPointStep() => _buildStepCard(
        step: '2',
        title: 'Available Stock Points',
        color: AppTheme.primary,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tap a stock point to enter consumed quantity.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ..._availableStockPoints.map((point) {
            final selected = _selectedAllocations[point.id];
            final available = _availableQtyForPoint(point);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _openQuantitySheet(point),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected == null ? AppTheme.surfaceCard : AppTheme.successBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected == null ? AppTheme.border : AppTheme.success.withOpacity(0.35)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (selected == null ? AppTheme.primary : AppTheme.success).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(selected == null ? Icons.warehouse_outlined : Icons.check_circle_outline,
                          color: selected == null ? AppTheme.primary : AppTheme.success, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(point.name,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text('${point.location} · Batch ${point.batchId} · Available ${_cleanNumber(available)} ${_selectedItem!.uom}',
                          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ])),
                    if (selected != null)
                      _MiniTag('${_cleanNumber(selected.quantity)} ${_selectedItem!.uom}', AppTheme.success)
                    else
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
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
              text: 'Total selected: ${_cleanNumber(_totalSelectedQty)} ${_selectedItem!.uom} from ${_selectedAllocations.length} stock point${_selectedAllocations.length > 1 ? 's' : ''}.',
            ),
          ],
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
            items: _purposeFilters.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
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
            validator: (v) => (v == null || v.trim().length < 4) ? 'Enter clear reason for other consumption' : null,
          ),
        ]),
      );

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitOtherConsumption,
          icon: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_outlined),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Other Consumption'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
        ),
      );

  Widget _buildSubmittedSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Submitted Other Consumables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const Spacer(),
          _MiniTag('Reports + HOD', AppTheme.success, icon: Icons.verified_outlined),
        ]),
        const SizedBox(height: 10),
        ..._submittedRecords.map((record) => _OtherConsumableRecordTile(record: record)),
      ]);

  String _cleanNumber(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  void _showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Row(children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg))]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }
}

class _SelectedItemCard extends StatelessWidget {
  final _OtherConsumableItem item;
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
          const Icon(Icons.inventory_2_outlined, color: AppTheme.info, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text('${item.code} · ${item.group} / ${item.category} · ${item.brand}',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
          ])),
          _MiniTag(item.uom, AppTheme.info),
        ]),
      );
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
            decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.outbound_outlined, color: AppTheme.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.itemName,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis),
            Text('${record.id} · Today $h:$m',
                style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis),
          ])),
          _MiniTag(record.status, AppTheme.success),
        ]),
        const SizedBox(height: 10),
        Text('Reason: ${record.reason}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MiniTag('Total ${record.totalQty.toStringAsFixed(record.totalQty.truncateToDouble() == record.totalQty ? 0 : 2)} ${record.uom}', AppTheme.danger),
          _MiniTag('${record.allocations.length} stock point${record.allocations.length > 1 ? 's' : ''}', AppTheme.info),
          _MiniTag(record.itemCode, AppTheme.textSecondary),
        ]),
        const SizedBox(height: 8),
        ...record.allocations.map((a) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${a.stockPointName} · Batch ${a.batchId}',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${a.quantity.toStringAsFixed(a.quantity.truncateToDouble() == a.quantity ? 0 : 2)} ${record.uom}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              ]),
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — USER ENTRY / VIEW STOCK
// ══════════════════════════════════════════════════════════════════════════════
class _ViewStockTab extends StatelessWidget {
  final List<StockPoint> points;
  final List<StockMovement> movements;
  final StockPoint? selectedPoint;
  final ValueChanged<StockPoint?> onSelect;

  const _ViewStockTab({
    required this.points,
    required this.movements,
    required this.selectedPoint,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSelectorCard(context),
          if (selectedPoint != null) ...[
            const SizedBox(height: 16),
            if (selectedPoint!.isLow) ...[
              _buildLowStockAlert(),
              const SizedBox(height: 16),
            ],
            _buildDashboardHeader(),
            const SizedBox(height: 12),
            _buildStatsGrid(),
            const SizedBox(height: 8),
            _buildStockBar(),
            const SizedBox(height: 20),
            _buildMovementHeader(context),
            const SizedBox(height: 12),
            ...movements.map((m) => _MovementTile(movement: m)),
          ] else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildHeader() => Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.warning.withOpacity(0.15),
                AppTheme.warning.withOpacity(0.05),
              ]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: const Text('📦', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Entry',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                SizedBox(height: 4),
                Text('View and manage stock inventory items',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      );

  Widget _buildSelectorCard(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.edit_note, color: AppTheme.warning, size: 20),
            SizedBox(width: 10),
            Text('User Entry — Stock Items',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 8),
          const HodApprovalBadge(text: 'Items can be added by users, approved by HOD'),
          const SizedBox(height: 14),
          DropdownButtonFormField<StockPoint>(
            value: selectedPoint,
            hint: const Text('Choose a stock point to view dashboard',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
            ),
            items: points
                .map((point) => DropdownMenuItem(
                      value: point,
                      child: Row(children: [
                        Expanded(
                            child: Text(point.name,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis)),
                        if (point.isLow)
                          _MiniTag('Low Stock', AppTheme.danger),
                      ]),
                    ))
                .toList(),
            onChanged: onSelect,
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Low Stock Alert',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.danger)),
            Text(
              '⚠️ Stock at ${selectedPoint!.name} is at or below the reorder level '
              '(${selectedPoint!.reorderLevel} units). Raise an order immediately.',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.danger, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDashboardHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Stock Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(selectedPoint!.batchId,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ),
        ],
      );

  Widget _buildStatsGrid() {
    final sp = selectedPoint!;
    final stats = [
      _StatData('Batch ID',      sp.batchId,                      Icons.tag,                       AppTheme.info),
      _StatData('Total In / Out','${sp.totalIn} / ${sp.totalOut}', Icons.swap_vert,                AppTheme.success),
      _StatData('On Hand',        '${sp.onHand} units',            Icons.inventory_2_outlined,     AppTheme.warning),
      _StatData("Today's Usage",  '${sp.todayUsage} units',        Icons.today_outlined,           AppTheme.primary),
      _StatData('Remaining',      '${sp.remaining} units',         Icons.donut_large_outlined,
          sp.isLow ? AppTheme.danger : AppTheme.success),
      _StatData('Reorder Level',  '${sp.reorderLevel} units',      Icons.low_priority_outlined,
          sp.isLow ? AppTheme.danger : AppTheme.textSecondary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: stats.map((s) => _StatCell(data: s)).toList(),
    );
  }

  Widget _buildStockBar() {
    final sp = selectedPoint!;
    final pct = (sp.remaining / (sp.onHand == 0 ? 1 : sp.onHand)).clamp(0.0, 1.0);
    final color = sp.isLow ? AppTheme.danger : pct > 0.5 ? AppTheme.success : AppTheme.warning;
    return _CardShell(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Stock Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${sp.remaining} remaining', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text('Reorder at ${sp.reorderLevel}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _buildMovementHeader(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Movement Log',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          TextButton.icon(
            onPressed: () => _showAllMovements(context),
            icon: const Icon(Icons.history, size: 16),
            label: const Text('View All'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.info),
          ),
        ],
      );

  void _showAllMovements(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(children: [
          const _BottomSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              const Text('Full Movement Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${movements.length} entries',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _MovementTile(movement: movements[i]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.edit_note, size: 48, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            const Text('No Stock Point Selected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Select a stock point above to view its live dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — RAISE ORDER
// ══════════════════════════════════════════════════════════════════════════════
class _RaiseOrderTab extends StatefulWidget {
  final List<StockPoint> stockPoints;
  const _RaiseOrderTab({required this.stockPoints});

  @override
  State<_RaiseOrderTab> createState() => _RaiseOrderTabState();
}

class _RaiseOrderTabState extends State<_RaiseOrderTab> {
  final _formKey = GlobalKey<FormState>();

  StockPoint? _selectedStockPoint;
  String? _selectedItem;
  final _quantityCtrl = TextEditingController();
  final _purposeCtrl  = TextEditingController();
  bool _isSubmitting  = false;
  bool _isRecording   = false;

  final List<SubmissionRecord> _recentOrders = [];
  late final String _orderId = _generateId('ORD');

  static String _generateId(String prefix) {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return '$prefix-2024-$n';
  }

  static const List<String> _items = [
    'Diesel', 'Engine Oil', 'Hydraulic Fluid', 'Bolts & Nuts',
    'Grease', 'Coolant', 'Air Filter',
  ];

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final record = SubmissionRecord(
      id: _orderId,
      type: SubmissionType.order,
      stockPoint: _selectedStockPoint!.name,
      item: _selectedItem!,
      quantity: int.parse(_quantityCtrl.text.trim()),
      purpose: _purposeCtrl.text.trim().isEmpty ? null : _purposeCtrl.text.trim(),
      submittedAt: DateTime.now(),
      status: 'Pending',
    );

    setState(() {
      _isSubmitting = false;
      _recentOrders.insert(0, record);
    });
    _showSuccess('Order $_orderId submitted for HOD approval!');
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _selectedStockPoint = null;
      _selectedItem = null;
    });
    _quantityCtrl.clear();
    _purposeCtrl.clear();
  }

  void _showSuccess(String msg) =>
      _showSnackbar(msg, AppTheme.success, Icons.check_circle_outline);

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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAutoIdBanner(_orderId, AppTheme.warning, AppTheme.warningBg, Icons.receipt_long_outlined),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1', title: 'Destination Stock Point', color: AppTheme.warning,
            child: _buildStockPointSelector(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2', title: 'Item, Quantity & Purpose', color: AppTheme.warning,
            child: _buildOrderDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3', title: 'Submit for HOD Approval', color: AppTheme.warning,
            child: _buildSubmissionInfo(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          if (_recentOrders.isNotEmpty) ...[
            const SizedBox(height: 28),
            _buildActivityLog(),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: const Icon(Icons.add_shopping_cart, color: AppTheme.warning, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Raise New Order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text('Request stock from HOD',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ])),
      ]);

  Widget _buildStockPointSelector() => Column(children: [
        DropdownButtonFormField<StockPoint>(
          value: _selectedStockPoint,
          hint: const Text('Select stock point', style: TextStyle(fontSize: 13)),
          isExpanded: true,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.warehouse_outlined, size: 18)),
          items: widget.stockPoints
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedStockPoint = v),
          validator: (v) => v == null ? 'Please select a stock point' : null,
        ),
        const SizedBox(height: 10),
        const HodApprovalBadge(),
      ]);

  Widget _buildOrderDetails() => Column(children: [
        DropdownButtonFormField<String>(
          value: _selectedItem,
          hint: const Text('Select item to order', style: TextStyle(fontSize: 13)),
          isExpanded: true,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined, size: 18)),
          items: _items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedItem = v),
          validator: (v) => v == null ? 'Please select an item' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _quantityCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Quantity Required',
            prefixIcon: Icon(Icons.numbers, size: 18),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter quantity';
            final n = int.tryParse(v.trim());
            if (n == null || n <= 0) return 'Enter a positive number';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purposeCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Purpose / Reason (optional)',
            hintText: 'Describe why this order is needed…',
            prefixIcon: Icon(Icons.notes_outlined, size: 18),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        _buildVoiceNoteButton(),
      ]);

  Widget _buildVoiceNoteButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _isRecording = !_isRecording);
        if (_isRecording) {
          _showSnackbar('Voice recording started…', AppTheme.info, Icons.mic);
        } else {
          _showSnackbar('Voice recording stopped.', AppTheme.textSecondary, Icons.stop_circle_outlined);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isRecording ? AppTheme.danger.withOpacity(0.07) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _isRecording ? AppTheme.danger.withOpacity(0.4) : AppTheme.border),
        ),
        child: Row(children: [
          Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_outlined,
              color: _isRecording ? AppTheme.danger : AppTheme.info, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isRecording ? 'Recording… tap to stop' : 'Voice Note (optional)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _isRecording ? AppTheme.danger : AppTheme.textPrimary)),
            Text(_isRecording ? 'Tap to stop recording' : 'Tap to record a voice message',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
          if (_isRecording)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  Widget _buildSubmissionInfo() => Column(children: [
        const HodApprovalBadge(),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.pending_actions_outlined,
          color: AppTheme.warning,
          bgColor: AppTheme.warningBg,
          text: 'Order will appear in pending list after submission. HOD reviews before stock levels are updated.',
        ),
      ]);

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitOrder,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
          child: _isSubmitting
              ? const _LoadingIndicator()
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.send_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('Submit Order for Approval',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
        ),
      );

  Widget _buildActivityLog() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Submitted This Session',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
      const SizedBox(height: 10),
      ..._recentOrders.map((r) => _SubmissionTile(record: r)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — RETURN
// ══════════════════════════════════════════════════════════════════════════════
class _ReturnTab extends StatefulWidget {
  final List<StockPoint> stockPoints;
  const _ReturnTab({required this.stockPoints});

  @override
  State<_ReturnTab> createState() => _ReturnTabState();
}

class _ReturnTabState extends State<_ReturnTab> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedItem;
  StockPoint? _selectedStockPoint;
  final _batchCtrl    = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _reasonCtrl   = TextEditingController();
  bool _isSubmitting  = false;

  final List<SubmissionRecord> _recentReturns = [];
  late final String _returnId = _generateId('RET');

  static String _generateId(String prefix) {
    final n = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
    return '$prefix-2024-$n';
  }

  static const List<String> _items = [
    'Engine Oil', 'Bolts & Nuts', 'Hydraulic Fluid', 'Grease', 'Coolant',
  ];

  @override
  void dispose() {
    _batchCtrl.dispose();
    _quantityCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final record = SubmissionRecord(
      id: _returnId,
      type: SubmissionType.returnStock,
      stockPoint: _selectedStockPoint?.name ?? 'N/A',
      item: _selectedItem!,
      quantity: int.parse(_quantityCtrl.text.trim()),
      purpose: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      submittedAt: DateTime.now(),
      status: 'Pending',
    );

    setState(() {
      _isSubmitting = false;
      _recentReturns.insert(0, record);
    });
    _showSnackbar('Return $_returnId submitted for HOD approval!', AppTheme.success, Icons.check_circle_outline);
    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _selectedItem = null;
      _selectedStockPoint = null;
    });
    _batchCtrl.clear();
    _quantityCtrl.clear();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAutoIdBanner(_returnId, AppTheme.success, AppTheme.successBg, Icons.loop_outlined),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '1', title: 'Source Stock Point & Batch', color: AppTheme.success,
            child: _buildSourceFields(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '2', title: 'Return Details', color: AppTheme.success,
            child: _buildReturnDetails(),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            step: '3', title: 'Submit for HOD Approval', color: AppTheme.success,
            child: _buildSubmissionInfo(),
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
          if (_recentReturns.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Submitted This Session',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
          width: 50, height: 50,
          decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: const Icon(Icons.assignment_return, color: AppTheme.success, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Return Stock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          Text('Request stock return approval',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        ])),
      ]);

  Widget _buildSourceFields() => Column(children: [
        DropdownButtonFormField<StockPoint>(
          value: _selectedStockPoint,
          hint: const Text('Select originating stock point', style: TextStyle(fontSize: 13)),
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined, size: 18)),
          items: widget.stockPoints
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
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
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter batch ID' : null,
        ),
        const SizedBox(height: 10),
        const HodApprovalBadge(),
      ]);

  Widget _buildReturnDetails() => Column(children: [
        DropdownButtonFormField<String>(
          value: _selectedItem,
          hint: const Text('Select item to return', style: TextStyle(fontSize: 13)),
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined, size: 18)),
          items: _items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedItem = v),
          validator: (v) => v == null ? 'Please select an item' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _quantityCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Quantity to Return',
            prefixIcon: Icon(Icons.numbers, size: 18),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter quantity';
            final n = int.tryParse(v.trim());
            if (n == null || n <= 0) return 'Enter a positive number';
            return null;
          },
        ),
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
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please provide a reason' : null,
        ),
      ]);

  Widget _buildSubmissionInfo() => Column(children: [
        const HodApprovalBadge(),
        const SizedBox(height: 12),
        _InfoBox(
          icon: Icons.info_outline,
          color: AppTheme.info,
          bgColor: AppTheme.infoBg,
          text: 'Once approved, returned quantity will be added back to the original batch stock count.',
        ),
      ]);

  Widget _buildSubmitButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReturn,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          child: _isSubmitting
              ? const _LoadingIndicator()
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.keyboard_return, size: 20),
                  SizedBox(width: 10),
                  Text('Submit Return for Approval',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
          Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success.withOpacity(0.6)),
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
          _MiniTag('$totalBills Pending Bill${totalBills > 1 ? "s" : ""}', AppTheme.warning, icon: Icons.pending_actions),
          const Spacer(),
          Text('${ginStockPoints.length} Stock Point${ginStockPoints.length > 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ginStockPoints.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final sp = ginStockPoints[i];
            final totalItems = sp.pendingBills.fold(0, (s, b) => s + b.items.length);
            final hasShortage = sp.pendingBills
                .any((b) => b.items.any((it) => it.status == ReconciliationStatus.shortage));
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
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Icon(Icons.warehouse, color: AppTheme.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stockPoint.stockPointName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
                color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
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
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Icon(Icons.receipt, color: AppTheme.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bill #${bill.billNumber}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(bill.supplierName,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _MiniTag('${bill.items.length} items', AppTheme.info),
              if (matched > 0) _MiniTag('$matched matched', AppTheme.success),
              if (shortages > 0) _MiniTag('$shortages shortage', AppTheme.warning),
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

  // ── SIMPLIFIED: just a list of uploaded file names + timestamps ──────────
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
            // When quantity changes, reset acknowledgement for that row
            widget.bill.items[i].acknowledged = false;
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

  // ── Computed ──────────────────────────────────────────────────────────────
  int get _matchedCount =>
      widget.bill.items.where((i) => i.status == ReconciliationStatus.matched).length;
  int get _shortageCount =>
      widget.bill.items.where((i) => i.status == ReconciliationStatus.shortage).length;
  int get _excessCount =>
      widget.bill.items.where((i) => i.status == ReconciliationStatus.excess).length;

  bool get _allMatched => _shortageCount == 0 && _excessCount == 0;

  /// All discrepant rows must be acknowledged before submit is allowed.
  bool get _allDiscrepanciesAcknowledged {
    for (final item in widget.bill.items) {
      if (item.hasDiscrepancy && !item.acknowledged) return false;
    }
    return true;
  }

  /// Submit is enabled when:
  ///   - At least one document is uploaded, AND
  ///   - Either all items are matched, OR all discrepancies have been acknowledged.
  bool get _canSubmit =>
      _docs.isNotEmpty && (_allMatched || _allDiscrepanciesAcknowledged);

  // ── Document upload helpers (SIMPLIFIED) ─────────────────────────────────
  void _uploadPhoto() => _addDoc('Photo_Goods');
  void _uploadInvoice() => _addDoc('Invoice');

  void _addDoc(String label) {
    final now = DateTime.now();
    setState(() => _docs.add(UploadedDocument(
          name: '${label}_${now.millisecondsSinceEpoch}.jpg',
          uploadedAt: now,
        )));
    _showSnackbar('$label uploaded successfully', AppTheme.success, Icons.check_circle_outline);
  }

  void _removeDoc(int index) => setState(() => _docs.removeAt(index));

  // ── Acknowledge a discrepant row ──────────────────────────────────────────
  void _acknowledge(int index) {
    setState(() => widget.bill.items[index].acknowledged = true);
  }

  // ── Submit flow ───────────────────────────────────────────────────────────
  void _onSubmit() {
    for (var i = 0; i < widget.bill.items.length; i++) {
      if (_rcvdCtrl[i].text.trim().isEmpty) {
        _showSnackbar(
            'Enter received qty for "${widget.bill.items[i].itemName}"',
            AppTheme.danger, Icons.error_outline);
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
    _showSnackbar('Goods Inward Note submitted successfully!',
        AppTheme.success, Icons.check_circle);
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  // ── Supplier banner ───────────────────────────────────────────────────────
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
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: const Icon(Icons.business_outlined, color: AppTheme.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.bill.supplierName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              _infoPill(Icons.tag, 'Bill #${widget.bill.billNumber}', AppTheme.info),
              _infoPill(Icons.inventory_2_outlined, '${widget.bill.items.length} items', AppTheme.success),
            ]),
          ])),
        ]),
      );

  Widget _infoPill(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Reconciliation ────────────────────────────────────────────────────────
  Widget _buildReconciliationSection() {
    // Show review-required banner when there are unacknowledged discrepancies
    final pendingAck = widget.bill.items
        .where((i) => i.hasDiscrepancy && !i.acknowledged)
        .length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Item Reconciliation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
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
      const Text('Tap the "RCVD" cells to update quantities  ·  Scroll ⟶ to see all columns',
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),

      // ── Review-required notice ─────────────────────────────────────────
      if (!_allMatched) ...[
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pendingAck > 0 ? AppTheme.warningBg : AppTheme.successBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (pendingAck > 0 ? AppTheme.warning : AppTheme.success)
                    .withOpacity(0.35)),
          ),
          child: Row(children: [
            Icon(
              pendingAck > 0 ? Icons.info_outline : Icons.check_circle_outline,
              color: pendingAck > 0 ? AppTheme.warning : AppTheme.success,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pendingAck > 0
                    ? '$pendingAck discrepanc${pendingAck > 1 ? "ies" : "y"} found. '
                      'Review each item and tap "Acknowledge" to enable Submit.'
                    : 'All discrepancies acknowledged. You can now submit.',
                style: TextStyle(
                  fontSize: 12,
                  color: pendingAck > 0 ? AppTheme.warning : AppTheme.success,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildTableHeader(),
              ...List.generate(
                  widget.bill.items.length,
                  (i) => _buildTableRow(widget.bill.items[i], _rcvdCtrl[i], i)),
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
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );

  // ── Table ─────────────────────────────────────────────────────────────────
  static const _colW = <double>[24, 120, 52, 52, 64, 58, 58, 64, 96];
  static const _gap = 8.0;

  Widget _buildTableHeader() {
    const s  = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textSecondary);
    const sE = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary);
    final headers = [
      ('No.',           s,  TextAlign.left),
      ('ITEM',          s,  TextAlign.left),
      ('ORD',           s,  TextAlign.center),
      ('BILLED',        s,  TextAlign.center),
      ('RCVD ✎',       sE, TextAlign.center),
      ('DIFF\nBld−Rcvd',s,  TextAlign.center),
      ('DIFF\nOrd−Rcvd',s,  TextAlign.center),
      ('STATUS',        s,  TextAlign.center),
      ('ACTION',        s,  TextAlign.center),
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
        color: item.hasDiscrepancy && item.acknowledged
            ? AppTheme.successBg.withOpacity(0.5)
            : rowBg,
        border: Border(
            bottom: BorderSide(color: AppTheme.border.withOpacity(0.5))),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // #
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[0],
            child: Text('${item.sno}',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          ),
        ),
        // Item name
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[1],
            child: Text(item.itemName,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ),
        // Ordered
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[2],
            child: Text(item.orderedQty.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
        // Billed
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[3],
            child: Text(item.billedQty.toStringAsFixed(0),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
        // Received (editable)
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
        // Diff Billed−Received
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[5],
            child: _DiffBadge(diff: item.diffBilledReceived),
          ),
        ),
        // Diff Ordered−Received
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
        // Status
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[7],
            child: _StatusBadge(status: status, color: statusColor),
          ),
        ),
        // ── ACTION column: Acknowledge button for discrepant rows ──────────
        SizedBox(
          width: _colW[8],
          child: item.hasDiscrepancy
              ? (item.acknowledged
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text('Done',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success)),
                    ])
                  : GestureDetector(
                      onTap: () => _acknowledge(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Acknowledge',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.warning)),
                      ),
                    ))
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _buildTableFooter() {
    final totalOrdered  = widget.bill.items.fold(0.0, (s, i) => s + i.orderedQty);
    final totalBilled   = widget.bill.items.fold(0.0, (s, i) => s + i.billedQty);
    final totalReceived = widget.bill.items.fold(0.0, (s, i) => s + i.receivedQty);

    const ts = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.04),
        border: Border(
            top: BorderSide(color: AppTheme.primary.withOpacity(0.2), width: 1.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: _colW[0] + _gap),
        Padding(
          padding: const EdgeInsets.only(right: _gap),
          child: SizedBox(
            width: _colW[1],
            child: const Text('TOTAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary)),
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
        _legendItem('Matched', AppTheme.success),
        _legendItem('Shortage', AppTheme.warning),
        _legendItem('Excess', AppTheme.info),
        const Text('RCVD ✎ = editable  ·  scroll table sideways for all columns',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ]);

  Widget _legendItem(String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ]);

  // ══════════════════════════════════════════════════════════════════════════
  // SIMPLIFIED DOCUMENT SECTION
  // ══════════════════════════════════════════════════════════════════════════
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

      // ── Two upload buttons ─────────────────────────────────────────────
      Row(children: [
        Expanded(child: _UploadButton(
          icon: Icons.camera_alt_outlined,
          label: 'Photo of Goods',
          color: AppTheme.warning,
          onTap: _uploadPhoto,
        )),
        const SizedBox(width: 12),
        Expanded(child: _UploadButton(
          icon: Icons.receipt_long_outlined,
          label: 'Invoice',
          color: AppTheme.info,
          onTap: _uploadInvoice,
        )),
      ]),

      // ── Uploaded file list ─────────────────────────────────────────────
      if (_docs.isNotEmpty) ...[
        const SizedBox(height: 14),
        ...List.generate(_docs.length, (i) => _buildDocTile(_docs[i], i)),
      ],

      // ── Required notice if no docs ─────────────────────────────────────
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  // ── Bottom submit bar ─────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final pendingAck = widget.bill.items
        .where((i) => i.hasDiscrepancy && !i.acknowledged)
        .length;

    // Determine the hint text when disabled
    String? disabledHint;
    if (_docs.isEmpty && !_allMatched && !_allDiscrepanciesAcknowledged) {
      disabledHint = 'Upload a doc & acknowledge discrepancies';
    } else if (_docs.isEmpty) {
      disabledHint = 'Upload at least one document';
    } else if (!_allMatched && !_allDiscrepanciesAcknowledged) {
      disabledHint = 'Acknowledge $pendingAck discrepanc${pendingAck > 1 ? "ies" : "y"} above';
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
          _bottomStat('Matched', '$_matchedCount', AppTheme.success),
          if (_shortageCount > 0)
            _bottomStat('Shortage', '$_shortageCount', AppTheme.warning),
          if (_excessCount > 0)
            _bottomStat('Excess', '$_excessCount', AppTheme.info),
          _bottomStat('Docs', '${_docs.length}',
              _docs.isEmpty ? AppTheme.danger : AppTheme.success),
        ]),
        if (disabledHint != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(disabledHint,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canSubmit && !_isSubmitting ? _onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit ? AppTheme.success : AppTheme.textMuted,
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
// SIMPLE UPLOAD BUTTON (replaces the old multi-type browse card)
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
            width: 44, height: 44,
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
  final bool allMatched;
  final VoidCallback onReview, onConfirm;

  const _GINConfirmDialog({
    required this.matchedCount,
    required this.shortageCount,
    required this.excessCount,
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
                  width: 40, height: 40,
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
                      _summaryRow(Icons.check_circle,
                          '$matchedCount items matched', AppTheme.success),
                      if (shortageCount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow(Icons.warning_amber,
                            '$shortageCount items with shortage (acknowledged)',
                            AppTheme.warning),
                      ],
                      if (excessCount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow(Icons.arrow_upward,
                            '$excessCount items with excess (acknowledged)',
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
                  text: 'Discrepancies acknowledged. HOD will be notified for review.',
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

  Widget _summaryRow(IconData icon, String text, Color color) =>
      Row(children: [
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
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(step,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
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
        width: 22, height: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
}

class _BottomSheetHandle extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40, height: 4,
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
    final sign  = isPositive ? '−' : '+';
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
      ReconciliationStatus.matched  => '✓ OK',
      ReconciliationStatus.shortage => '⚠ Short',
      ReconciliationStatus.excess   => '↑ Excess',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
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

class _MovementTile extends StatelessWidget {
  final StockMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (movement.type) {
      'in'       => (AppTheme.success, Icons.arrow_downward,  'Received'),
      'out'      => (AppTheme.danger,  Icons.arrow_upward,    'Consumed'),
      'transfer' => (AppTheme.info,    Icons.compare_arrows,  'Transfer'),
      _          => (AppTheme.warning, Icons.loop,            'Return'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(movement.item,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _MiniTag(label, color),
          ]),
          const SizedBox(height: 4),
          Text(
              '${movement.batch}  ·  ${movement.quantity} units  ·  ${movement.by}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12)),
          child: Text(movement.date,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ),
      ]),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final SubmissionRecord record;
  const _SubmissionTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isOrder = record.type == SubmissionType.order;
    final color   = isOrder ? AppTheme.warning : AppTheme.success;
    final icon    = isOrder ? Icons.add_shopping_cart : Icons.keyboard_return;

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
          width: 36, height: 36,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            _MiniTag(record.status, AppTheme.warning),
          ]),
          const SizedBox(height: 2),
          Text(
              '${record.item}  ·  ${record.quantity} units  ·  ${record.stockPoint}',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ])),
      ]),
    );
  }
}
