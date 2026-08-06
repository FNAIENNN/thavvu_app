import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/attendance_context_service.dart';
import '../services/csv_export_service.dart';
import '../services/reports_repository.dart';

enum ReportPeriod { daily, weekly, monthly, yearly }

class ReportDataset {
  final String id;
  final String module;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const ReportDataset({
    required this.id,
    required this.module,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class ReportRecord {
  final String id;
  final String module;
  final String dataset;
  final String title;
  final String subtitle;
  final DateTime date;
  final String status;
  final String supplier;
  final String type;
  final String brand;
  final String shop;
  final String invoice;
  final double amount;
  final double paid;
  final double balance;
  final Map<String, String> details;

  const ReportRecord({
    required this.id,
    required this.module,
    required this.dataset,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
    this.supplier = '-',
    this.type = '-',
    this.brand = '-',
    this.shop = '-',
    this.invoice = '-',
    this.amount = 0,
    this.paid = 0,
    this.balance = 0,
    this.details = const {},
  });
}

class ReportsScreen extends StatefulWidget {
  final bool isHOD;

  const ReportsScreen({super.key, this.isHOD = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final TextEditingController _searchController = TextEditingController();

  // ── Live backend summary ─────────────────────────────────────
  final ReportsRepository _reportsRepo = ReportsRepository();
  final AttendanceContextService _contextService = AttendanceContextService();
  String _reportSiteId = 'SITE-VJA-001';
  Map<String, double> _liveSummary = const {};
  bool _liveLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLiveSummary());
  }

  Future<void> _loadLiveSummary() async {
    final siteId = await _contextService.resolveSiteId();
    if (!mounted) return;
    _reportSiteId = (siteId == null || siteId.isEmpty) ? 'SITE-VJA-001' : siteId;
    try {
      final attendance = await _reportsRepo.attendanceSummary(_reportSiteId);
      final food = await _reportsRepo.foodRequests(_reportSiteId);
      final stock = await _reportsRepo.stockSummary(_reportSiteId);
      final diesel = await _reportsRepo.dieselIssued(_reportSiteId);
      final machines = await _reportsRepo.machineLogs(_reportSiteId);
      final rental = await _reportsRepo.rentalSummary(_reportSiteId);
      final cash = await _reportsRepo.cashSpent(_reportSiteId);
      if (!mounted) return;
      setState(() {
        _liveSummary = {
          'present': (attendance['present'] ?? 0).toDouble(),
          'food': food.toDouble(),
          'stockItems': stock['items'] ?? 0,
          'lowStock': stock['low'] ?? 0,
          'diesel': diesel,
          'machines': machines.toDouble(),
          'rentalTotal': rental['total'] ?? 0,
          'cashSpent': cash,
        };
        _liveLoaded = true;
      });
    } catch (_) {
      // Live summary is best-effort; seeded reports still work.
    }
  }

  String _selectedModule = 'All Modules';
  String _selectedDataset = 'All Data Sets';
  String _selectedStatus = 'All Status';
  String _selectedSupplier = 'All Suppliers';
  String _selectedType = 'All Types';
  String _selectedBrand = 'All Brands';
  String _selectedShop = 'All Shops';
  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  DateTime _selectedDate = DateTime.now();
  ReportRecord? _selectedRecord;

  late final List<ReportDataset> _datasets = _buildDatasets();
  late final List<ReportRecord> _records = _buildRecords();

  final List<String> _moduleOrder = const [
    'All Modules',
    'Workers',
    'Machines',
    'Suppliers',
    'Rentals',
    'Stock',
    'Payments',
    'Cash',
    'Food',
    'Transfers',
    'Tasks',
    'Other Expenses',
    'Session',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportDataset> _buildDatasets() {
    return const [
      ReportDataset(
        id: 'workers_regular',
        module: 'Workers',
        title: 'Regular Workers',
        description: 'Active and inactive permanent workers, attendance & bio setup',
        icon: Icons.badge_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'workers_outside_supplier',
        module: 'Workers',
        title: 'Outside Workers - Supplier Wise',
        description: 'Outside labour grouped by supplier and bill status',
        icon: Icons.groups_2_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'workers_outside_batch',
        module: 'Workers',
        title: 'Outside Workers - Batch Wise',
        description: 'Outside labour grouped by batch, shift wage and date',
        icon: Icons.view_list_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'machines_all',
        module: 'Machines',
        title: 'Machine Complete Register',
        description: 'Machine type, operator, diesel, payments and balance',
        icon: Icons.precision_manufacturing_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'machines_diesel',
        module: 'Machines',
        title: 'Machine Diesel',
        description: 'Fuel entry, stock point, litres, L/hr efficiency and readings',
        icon: Icons.local_gas_station_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'machines_daily_blocks',
        module: 'Machines',
        title: 'Daily Machine Time Blocks',
        description: 'Start time, end time, destination, beta and HOD notes',
        icon: Icons.schedule_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'machines_hod_verification',
        module: 'Machines',
        title: 'HOD Verification',
        description: 'Machine verification, payment amount and readings checks',
        icon: Icons.verified_user_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'suppliers_machine',
        module: 'Suppliers',
        title: 'Machine Suppliers',
        description: 'Machine supplier rates, invoices and pending payments',
        icon: Icons.engineering_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'suppliers_rental',
        module: 'Suppliers',
        title: 'Rental Suppliers',
        description: 'Rental vendors, active rentals and settlement status',
        icon: Icons.key_outlined,
        color: AppTheme.danger,
      ),
      ReportDataset(
        id: 'suppliers_workers',
        module: 'Suppliers',
        title: 'Worker Suppliers',
        description: 'Labour contractors and supplier bill payment status',
        icon: Icons.supervisor_account_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'rentals_all',
        module: 'Rentals',
        title: 'Rental Full Data',
        description: 'Item wise rental details, fuel and payment status',
        icon: Icons.home_repair_service_outlined,
        color: AppTheme.danger,
      ),
      ReportDataset(
        id: 'rentals_item_wise',
        module: 'Rentals',
        title: 'Rental Item Wise',
        description: 'Rental items, quantity, rate, usage and balance',
        icon: Icons.inventory_2_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'rentals_fuel_logs',
        module: 'Rentals',
        title: 'Rental Fuel Logs',
        description: 'Fuel litres, amount, type, meter reading and date',
        icon: Icons.local_gas_station_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'rentals_aqua_tools',
        module: 'Rentals',
        title: 'Aqua Tool Catalog',
        description: 'Tool name, category, purpose, district and rate',
        icon: Icons.handyman_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'rentals_vehicle_usage',
        module: 'Rentals',
        title: 'Vehicle Usage',
        description: 'Trips, locations, fuel, loading, bata and status',
        icon: Icons.local_shipping_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'rentals_asset_transfer',
        module: 'Rentals',
        title: 'Rental Asset Transfers',
        description: 'Asset return, site, tank, district and quantity status',
        icon: Icons.swap_horizontal_circle_outlined,
        color: AppTheme.danger,
      ),
      ReportDataset(
        id: 'rentals_bank_accounts',
        module: 'Rentals',
        title: 'Settlement Bank Accounts',
        description: 'Bank, UPI, account, IFSC and holder details',
        icon: Icons.account_balance_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'stock_summary',
        module: 'Stock',
        title: 'Stock Master Summary',
        description: 'Opening, inward, outward, return and closing stock',
        icon: Icons.warehouse_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'stock_suppliers',
        module: 'Stock',
        title: 'Stock Inward Purchases',
        description: 'Supplier wise stock orders, invoice & quality checks',
        icon: Icons.local_shipping_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'stock_transfers',
        module: 'Stock',
        title: 'Stock Transfers & Verification',
        description: 'Transfer request, delivery invoice and receiving data',
        icon: Icons.move_down_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'payments_all',
        module: 'Payments',
        title: 'All Payments',
        description: 'Cash, advance request, supplier bill and proof data',
        icon: Icons.payments_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'cash_all',
        module: 'Cash',
        title: 'Petty Cash Ledger',
        description: 'Cash pay, request pay, contra and transport split bills',
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'cash_contra',
        module: 'Cash',
        title: 'Contra Entries',
        description: 'Supervisor-to-supervisor cash transfer requests',
        icon: Icons.compare_arrows_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'cash_request_pay',
        module: 'Cash',
        title: 'Request Pay Advances',
        description: 'UPI, bank, photo, voice and invoice request data',
        icon: Icons.request_quote_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'food_all',
        module: 'Food',
        title: 'Food Consumption Matrix',
        description: 'Regular, outside & machine worker meals by date',
        icon: Icons.restaurant_menu_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'transfers_all',
        module: 'Transfers',
        title: 'Internal Transfers',
        description: 'Transfer request, delivery invoice and receiving check',
        icon: Icons.swap_horiz_outlined,
        color: AppTheme.info,
      ),
      ReportDataset(
        id: 'tasks_progress',
        module: 'Tasks',
        title: 'Task Progress & Audit',
        description: 'Task checklist, assignee, status and comments',
        icon: Icons.task_alt_outlined,
        color: AppTheme.success,
      ),
      ReportDataset(
        id: 'other_petrol',
        module: 'Other Expenses',
        title: 'Supervisor Bike Petrol',
        description: 'Bike, litres, amount, odometer reading and Km/L mileage',
        icon: Icons.two_wheeler_outlined,
        color: AppTheme.warning,
      ),
      ReportDataset(
        id: 'other_snacks',
        module: 'Other Expenses',
        title: 'Guest Snacks & Refreshments',
        description: 'Brought by, for whom, items, cost and payment mode',
        icon: Icons.fastfood_outlined,
        color: AppTheme.danger,
      ),
      ReportDataset(
        id: 'session_login',
        module: 'Session',
        title: 'Supervisor Session Logs',
        description: 'User, role, email, remember me and session state',
        icon: Icons.login_outlined,
        color: AppTheme.primary,
      ),
    ];
  }

  List<ReportRecord> _buildRecords() {
    final now = DateTime.now();
    DateTime d(int daysAgo) => DateTime(now.year, now.month, now.day - daysAgo);

    return [
      // 1. WORKERS & ATTENDANCE
      ReportRecord(
        id: 'WRK-001',
        module: 'Workers',
        dataset: 'workers_regular',
        title: 'Ravi Kumar (Regular Worker)',
        subtitle: 'Attendance Rate: 92% | Days Present: 24/26 | Active',
        date: d(0),
        status: 'Active / Validated',
        type: 'Regular',
        amount: 18000,
        paid: 12000,
        balance: 6000,
        details: const {
          'Worker ID': 'TP-VJA-001',
          'Full Name': 'Ravi Kumar',
          'Aadhar No': '4589-1234-9981',
          'Joining Date': '2025-01-15',
          'Referral Name': 'Srinivas Rao',
          'Biometric Setup': 'Face Reg: Yes | Bio: Registered',
          'Bank Book Photo': 'Attached (bank_book_001.jpg)',
          'Aadhar Photo': 'Attached (aadhar_001.jpg)',
          'Attendance Status': 'Present (Morning + Evening)',
          'Total Working Days': '26',
          'Days Present': '24',
          'Days Absent': '2',
          'Half Days': '0',
          'Leave Days': '0',
          'Attendance Rate': '92.3%',
          'Daily Shift Wage': '₹700',
          'Total Advances Paid': '₹12,000',
          'Net Balance Payable': '₹6,000',
          'Bank Account': 'State Bank of India (A/C: 3098112234)',
          'IFSC Code': 'SBIN0004120',
          'Validation Status': 'Valid (High Attendance & Verified Docs)',
        },
      ),
      ReportRecord(
        id: 'WRK-002',
        module: 'Workers',
        dataset: 'workers_regular',
        title: 'Mahesh Naidu (Regular Worker)',
        subtitle: 'Attendance Rate: 58% | High Absence Warning',
        date: d(2),
        status: 'Warning / Low Attendance',
        type: 'Regular',
        amount: 14000,
        paid: 11000,
        balance: 3000,
        details: const {
          'Worker ID': 'TP-VJA-002',
          'Full Name': 'Mahesh Naidu',
          'Aadhar No': '8834-5512-1092',
          'Joining Date': '2025-03-01',
          'Attendance Status': 'Absent',
          'Days Present': '15',
          'Days Absent': '11',
          'Attendance Rate': '57.6%',
          'Daily Wage': '₹650',
          'Total Advances Paid': '₹11,000',
          'Net Balance Payable': '₹3,000',
          'Validation Status': 'Warning (Low Attendance Rate < 60%)',
        },
      ),
      ReportRecord(
        id: 'OW-SUP-001',
        module: 'Workers',
        dataset: 'workers_outside_supplier',
        title: 'Lakshmi Labour Supplier',
        subtitle: '18 Workers | Batch A | Desilting Work',
        date: d(1),
        status: 'Pending Bill Verification',
        supplier: 'Lakshmi Labour Supplier',
        type: 'Outside Supplier Wise',
        amount: 28800,
        paid: 15000,
        balance: 13800,
        details: const {
          'Supplier Name': 'Lakshmi Labour Supplier',
          'Batch Type': 'Morning & Afternoon Shift',
          'Worker Count': '18 Workers',
          'Shift Wages': 'Morning: ₹400 | Afternoon: ₹400 | Full Day: ₹800',
          'Custom Bill No': 'BILL-LAK-2026-99',
          'Bill Photo': 'Attached (outside_bill_099.png)',
          'Total Labor Hours': '144 Hours',
          'Total Labor Cost': '₹28,800',
          'Validation Status': 'Valid (Bill Photo Attached & Wage Rate Matches)',
        },
      ),

      // 2. MACHINES & DIESEL
      ReportRecord(
        id: 'MCH-001',
        module: 'Machines',
        dataset: 'machines_all',
        title: 'Poclain EX-200 (Excavator)',
        subtitle: 'Operator: Ravi | Hours: 8.5 Hrs | Rate: ₹6,500/day',
        date: d(0),
        status: 'Running / Verified',
        supplier: 'ABC Machine Suppliers',
        type: 'Poclain',
        amount: 52000,
        paid: 30000,
        balance: 22000,
        details: const {
          'Machine Name': 'Poclain EX-200',
          'Vehicle Reg No': 'AP39TB1234',
          'Operator Name': 'Ravi Kumar',
          'Vehicle Type': 'Poclain Excavator',
          'Billing Mode': 'Hourly (₹800/hr)',
          'Diesel Included': 'No (Supervisor Stock Issue)',
          'Time Block 1': '08:00 AM - 12:30 PM (Pond 4 Bund)',
          'Time Block 2': '01:30 PM - 05:30 PM (Yard Excavation)',
          'Total Working Hours': '8.5 Hours',
          'Gross Billable': '₹6,800',
          'Regular Beta': '₹500',
          'Extra Beta': '₹200 (Extra soil movement approved by HOD)',
          'HOD Verification': 'Verified (Meter Reading Match Checked)',
          'Validation Status': 'Valid (No Time Block Overlaps & Verified Meter)',
        },
      ),
      ReportRecord(
        id: 'DSL-001',
        module: 'Machines',
        dataset: 'machines_diesel',
        title: 'Diesel Issue - Poclain EX-200',
        subtitle: '100 Litres Issued | Efficiency: 11.7 L/hr | Stock Point: Main',
        date: d(0),
        status: 'Matched',
        type: 'Diesel',
        shop: 'Main Diesel Stock',
        amount: 8700,
        paid: 8700,
        balance: 0,
        details: const {
          'Machine ID': 'MCH-001',
          'Fuel Type': 'Diesel',
          'Stock Point': 'Main Diesel Stock Yard',
          'Litres Issued': '100.0 Litres',
          'Fuel Rate': '₹87 / Litre',
          'Total Fuel Cost': '₹8,700',
          'Retrieved Fuel': '0.0 Litres',
          'Hours Worked': '8.5 Hours',
          'Consumption Rate': '11.76 Litres / Hour',
          'Odometer Reading': '2450.0 Hrs',
          'Supervisor Remarks': 'Full tank refilled before morning shift',
          'Validation Status': 'Valid (Consumption within baseline 10-14 L/hr)',
        },
      ),
      ReportRecord(
        id: 'DSL-002',
        module: 'Machines',
        dataset: 'machines_diesel',
        title: 'Diesel Issue - Tipper Truck #2',
        subtitle: '65 Litres Issued | High Consumption Warning (16.2 L/hr)',
        date: d(1),
        status: 'Warning / High Consumption',
        type: 'Diesel',
        shop: 'Main Diesel Stock',
        amount: 5655,
        paid: 5655,
        balance: 0,
        details: const {
          'Machine ID': 'MCH-004',
          'Vehicle Reg No': 'AP39X7712',
          'Fuel Type': 'Diesel',
          'Litres Issued': '65.0 Litres',
          'Hours Worked': '4.0 Hours',
          'Consumption Rate': '16.25 Litres / Hour',
          'Validation Status': 'Warning (Fuel rate > 25% above baseline)',
        },
      ),

      // 3. RENTALS, TOOLS & TRANSPORT
      ReportRecord(
        id: 'RNT-001',
        module: 'Rentals',
        dataset: 'rentals_all',
        title: '5 HP Submersible Aqua Pump',
        subtitle: 'Active Rented Days: 14 Days | Rate: ₹450/day',
        date: d(3),
        status: 'Active Rented',
        supplier: 'Bhimavaram Aqua Rentals',
        type: 'Aqua Pump',
        amount: 6300,
        paid: 3000,
        balance: 3300,
        details: const {
          'Item Name': '5 HP Submersible Aqua Pump',
          'Quantity Rented': '2 Units',
          'Returned Qty': '0 Units',
          'Billing Mode': 'Per day (₹450/day/unit)',
          'Rental Fuel Enabled': 'No',
          'Category': 'Pumping & Aeration',
          'District': 'Bhimavaram',
          'Site Placement': 'Tank #3 De-watering',
          'Activation Date': '2026-07-13',
          'Accrued Rental Liability': '₹6,300',
          'Validation Status': 'Valid (Active Rental within timeline)',
        },
      ),
      ReportRecord(
        id: 'RNT-VH-002',
        module: 'Rentals',
        dataset: 'rentals_vehicle_usage',
        title: 'Tractor Transport Trip - Yard to Pond',
        subtitle: 'From: Aqua Yard -> To: Pond #7 | Status: Running',
        date: d(0),
        status: 'Completed',
        supplier: 'Sri Rama Transport',
        type: 'Tractor Transport',
        amount: 3200,
        paid: 3200,
        balance: 0,
        details: const {
          'Vehicle Name': 'Mahindra Tractor (THV-VH-02)',
          'From Location': 'Aqua Central Yard',
          'To Location': 'Pond #7 Work Site',
          'Operator Name': 'K. Nagendra',
          'Usage Units': '4 Trips',
          'Rate per Unit': '₹500 / Trip',
          'Fuel Used': '10 Litres (₹870)',
          'Bata Paid': '₹200',
          'Loading Cost': '₹130',
          'Total Trip Expense': '₹3,200',
          'Vehicle Status': 'Running / Operational',
          'Validation Status': 'Valid (Trip units & expenditure verified)',
        },
      ),

      // 4. STOCK & INVENTORY
      ReportRecord(
        id: 'STK-001',
        module: 'Stock',
        dataset: 'stock_summary',
        title: 'Aqua Feed 3mm Bags (Master Stock)',
        subtitle: 'Closing Stock: 240 Bags | Safety Reorder Level: 100 Bags',
        date: d(0),
        status: 'Healthy Stock',
        supplier: 'CP Feed Suppliers',
        brand: 'CP Aqua',
        type: 'Feed',
        amount: 288000,
        paid: 200000,
        balance: 88000,
        details: const {
          'Item Code': 'STK-FD-3MM',
          'Item Name': 'Aqua Feed 3mm Starter Bags',
          'Unit of Measurement': 'Bags (50kg)',
          'Opening Stock': '180 Bags',
          'Inward Purchases': '200 Bags',
          'Outward Consumption': '120 Bags',
          'Transfer Net': '+20 Bags',
          'Current Closing Stock': '240 Bags',
          'Minimum Reorder Threshold': '100 Bags',
          'Unit Cost': '₹1,200 / Bag',
          'Validation Status': 'Valid (Closing Stock Above Reorder Threshold)',
        },
      ),
      ReportRecord(
        id: 'STK-TRN-003',
        module: 'Stock',
        dataset: 'stock_transfers',
        title: 'Stock Transfer: Main Yard -> Site 4',
        subtitle: 'Transfer ID: TRN-2026-88 | Qty: 40 Bags Feed',
        date: d(1),
        status: 'Verified Received',
        supplier: 'Internal Site Transfer',
        type: 'Stock Transfer',
        amount: 48000,
        paid: 48000,
        balance: 0,
        details: const {
          'Transfer ID': 'TRN-2026-88',
          'Internal Request No': 'INT-8831',
          'Source Stock Point': 'Central Warehouse Yard',
          'Destination Stock Point': 'Site #4 Feed Shed',
          'Item Name': 'Aqua Feed 3mm',
          'Sent Quantity': '40 Bags',
          'Received Quantity': '40 Bags',
          'Discrepancy Variance': '0 Bags',
          'Delivered By': 'Suresh (Transport Driver)',
          'Received By': 'K. Venkat (Supervisor)',
          'Quality Condition': 'Good / Intact Packaging',
          'Validation Status': 'Valid (Zero Quantity Variance)',
        },
      ),

      // 5. CASH & PAYMENTS
      ReportRecord(
        id: 'CSH-PAY-001',
        module: 'Cash',
        dataset: 'cash_all',
        title: 'Supervisor Petty Cash Expense - Hardware Tools',
        subtitle: 'Spent: ₹4,500 | Category: Assets | Site: THV-SITE-02',
        date: d(0),
        status: 'Approved',
        type: 'Cash Out',
        amount: 4500,
        paid: 4500,
        balance: 0,
        details: const {
          'Transaction ID': 'CSH-2026-551',
          'Expense Category': 'Assets / Hardware Tools',
          'Thavvu Site ID': 'TP-VJA-002',
          'Asset Details': 'Pipes & Connectors (15 Nos @ ₹300)',
          'Invoice Attachment': 'Attached (hardware_receipt_551.pdf)',
          'Opening Supervisor Cash': '₹15,000',
          'Closing Supervisor Cash': '₹10,500',
          'Validation Status': 'Valid (Receipt Attached & Approved)',
        },
      ),
      ReportRecord(
        id: 'CSH-SPL-002',
        module: 'Cash',
        dataset: 'cash_all',
        title: 'Transport Split Bill - Joint Site Movement',
        subtitle: 'Total Amount: ₹6,000 | Mode: Equal Split (3 Supervisors)',
        date: d(1),
        status: 'Validated Split',
        type: 'Split Bill',
        amount: 6000,
        paid: 6000,
        balance: 0,
        details: const {
          'Split Bill ID': 'SPL-2026-12',
          'Total Transport Bill': '₹6,000',
          'Split Mode': 'Equal Split',
          'Recipients': 'Supervisor A (₹2,000), Supervisor B (₹2,000), Supervisor C (₹2,000)',
          'Sum of Individual Splits': '₹6,000',
          'Vehicle Photo': 'Attached (vehicle_photo_12.jpg)',
          'Bill Photo': 'Attached (bill_photo_12.jpg)',
          'Validation Status': 'Valid (Sum of Splits equals Total Bill Amount)',
        },
      ),
      ReportRecord(
        id: 'CSH-REQ-003',
        module: 'Cash',
        dataset: 'cash_request_pay',
        title: 'Request Pay Advance - Labour Emergency',
        subtitle: 'Requested: ₹10,000 | UPI Payment | Audio Note Attached',
        date: d(0),
        status: 'Pending Office Approval',
        type: 'Request Pay',
        amount: 10000,
        paid: 0,
        balance: 10000,
        details: const {
          'Request ID': 'REQ-PAY-9041',
          'Amount Requested': '₹10,000',
          'Reason / Purpose': 'Emergency medical advance for site labour',
          'Payment Mode': 'UPI Transfer',
          'UPI ID': 'supervisor.ram@okaxis',
          'Voice Note Attachment': 'Attached (audio_req_9041.m4a)',
          'Bill Upload': 'Attached (medical_estimate.jpg)',
          'Approval Status': 'Pending HOD / Office Cashier',
          'Validation Status': 'Valid (Voice & Document Proof Attached)',
        },
      ),

      // 6. FOOD MODULE
      ReportRecord(
        id: 'FD-2026-01',
        module: 'Food',
        dataset: 'food_all',
        title: 'Daily Meal Distribution - Morning & Afternoon',
        subtitle: 'Total Meals: 42 Plates (Regular: 20, Outside: 18, Guests: 4)',
        date: d(0),
        status: 'Logged & Matched',
        type: 'Food Entry',
        amount: 3360,
        paid: 3360,
        balance: 0,
        details: const {
          'Selected Shifts': 'Morning Breakfast, Afternoon Lunch',
          'Regular Worker Meals': '20 Plates (₹80/plate)',
          'Outside Worker Meals': '18 Plates (₹80/plate)',
          'Machine Operator Meals': '0 Plates',
          'Guest Meals': 'Guest: HOD Inspection Team (4 Plates)',
          'Total Plate Count': '42 Plates',
          'Total Food Expense': '₹3,360',
          'Attendance Comparison': 'Active Workers: 38 | Plates: 38 + 4 Guests = 42',
          'Validation Status': 'Valid (Plate count matches active attendance + guests)',
        },
      ),

      // 7. DAILY TASKS
      ReportRecord(
        id: 'TSK-001',
        module: 'Tasks',
        dataset: 'tasks_progress',
        title: 'Pond #4 Bund Strengthening Task',
        subtitle: 'Assignee: Supervisor Ram | Status: Completed (On Time)',
        date: d(1),
        status: 'Completed',
        type: 'Field Task',
        amount: 0,
        paid: 0,
        balance: 0,
        details: const {
          'Task ID': 'TSK-2026-44',
          'Task Title': 'Pond #4 Bund Strengthening & Net Fixing',
          'Assigned Site': 'Site #4 (Bhimavaram)',
          'Assignee': 'Supervisor Ram',
          'Due Date': '2026-07-26',
          'Completion Date': '2026-07-26',
          'Checklist Progress': '5/5 Items Completed (100%)',
          'Progress Notes': 'Clay packing completed. Netting secured along outer bund.',
          'Lead Time': '1.5 Days',
          'Validation Status': 'Valid (Completed On Time)',
        },
      ),

      // 8. OTHER EXPENSES (PETROL & SNACKS)
      ReportRecord(
        id: 'EXP-PET-001',
        module: 'Other Expenses',
        dataset: 'other_petrol',
        title: 'Supervisor Bike Petrol - Hero Splendor',
        subtitle: '3.5 Litres | Odometer: 14,250 Km | Mileage: 48 Km/L',
        date: d(0),
        status: 'Approved Expense',
        type: 'Petrol',
        amount: 370,
        paid: 370,
        balance: 0,
        details: const {
          'Expense ID': 'PET-2026-102',
          'Bike Selected': 'Hero Splendor (AP39-B-5512)',
          'Quantity in Litres': '3.50 Litres',
          'Total Amount Paid': '₹370 (Cash)',
          'Odometer Reading': '14,250 Km (Prev: 14,082 Km)',
          'Distance Covered': '168 Km',
          'Calculated Mileage': '48.0 Km / Litre',
          'Supervisor Remarks': 'Routine site inspection trips across Akividu & Bhimavaram',
          'Validation Status': 'Valid (Mileage within normal range 45-55 Km/L)',
        },
      ),
      ReportRecord(
        id: 'EXP-SNK-001',
        module: 'Other Expenses',
        dataset: 'other_snacks',
        title: 'Guest Refreshments - Electrical Inspection Team',
        subtitle: 'Items: Tea, Biscuits & Cool Drinks | Brought By: Ram',
        date: d(2),
        status: 'Approved',
        type: 'Snacks',
        amount: 450,
        paid: 450,
        balance: 0,
        details: const {
          'Expense ID': 'SNK-2026-88',
          'Brought By': 'Supervisor Ram',
          'For Whom': 'APTRANSCO Electrical Inspection Officers',
          'Items Purchased': 'Tea, Bakery Biscuits, Cool Drinks',
          'Total Cost': '₹450',
          'Payment Mode': 'Supervisor Cash',
          'Validation Status': 'Valid (Reasonable Guest Expense)',
        },
      ),

      // 9. SESSION & SECURITY AUDIT
      ReportRecord(
        id: 'SES-001',
        module: 'Session',
        dataset: 'session_login',
        title: 'Supervisor Active Session Log',
        subtitle: 'User: ram@thavvu.com | Role: Supervisor | Status: Active',
        date: d(0),
        status: 'Active Session',
        type: 'Session',
        amount: 0,
        paid: 0,
        balance: 0,
        details: const {
          'Session ID': 'SES-2026-9912',
          'User Name': 'Ram Supervisor',
          'User Email': 'ram@thavvu.com',
          'Assigned Role': 'Field Supervisor',
          'Login Timestamp': '2026-07-27 07:30:00',
          'Session Duration': '5 Hours 17 Mins',
          'Active Screen Inputs': '48 Form Submissions',
          'Security Status': 'Verified Token / Remember Me Enabled',
          'Validation Status': 'Valid (Secure Authenticated Session)',
        },
      ),
    ];
  }

  List<ReportDataset> get _visibleDatasets {
    final datasets = _selectedModule == 'All Modules'
        ? _datasets
        : _datasets.where((item) => item.module == _selectedModule).toList();
    return [
      ReportDataset(
        id: 'All Data Sets',
        module: _selectedModule,
        title: 'All Data Sets',
        description: 'Show every data set in selected module',
        icon: Icons.all_inbox_outlined,
        color: AppTheme.primary,
      ),
      ...datasets,
    ];
  }

  List<ReportRecord> get _filteredRecords {
    final query = _searchController.text.trim().toLowerCase();
    final range = _periodRange;

    return _records.where((record) {
      final inModule =
          _selectedModule == 'All Modules' || record.module == _selectedModule;
      final inDataset = _selectedDataset == 'All Data Sets' ||
          record.dataset == _selectedDataset;
      final inStatus =
          _selectedStatus == 'All Status' || record.status == _selectedStatus;
      final inSupplier = _selectedSupplier == 'All Suppliers' ||
          record.supplier == _selectedSupplier;
      final inType =
          _selectedType == 'All Types' || record.type == _selectedType;
      final inBrand =
          _selectedBrand == 'All Brands' || record.brand == _selectedBrand;
      final inShop =
          _selectedShop == 'All Shops' || record.shop == _selectedShop;
      final inDate = !record.date.isBefore(range.$1) &&
          record.date.isBefore(range.$2.add(const Duration(days: 1)));
      final inSearch = query.isEmpty ||
          [
            record.id,
            record.title,
            record.subtitle,
            record.supplier,
            record.type,
            record.brand,
            record.shop,
            record.invoice,
            record.status,
            ...record.details.entries
                .map((entry) => '${entry.key} ${entry.value}'),
          ].join(' ').toLowerCase().contains(query);
      return inModule &&
          inDataset &&
          inStatus &&
          inSupplier &&
          inType &&
          inBrand &&
          inShop &&
          inDate &&
          inSearch;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<ReportRecord> _recordsForPeriod(ReportPeriod period) {
    final currentRange = _rangeForPeriod(period);
    return _records.where((record) {
      final inModule =
          _selectedModule == 'All Modules' || record.module == _selectedModule;
      final inDataset = _selectedDataset == 'All Data Sets' ||
          record.dataset == _selectedDataset;
      final inDate = !record.date.isBefore(currentRange.$1) &&
          record.date.isBefore(currentRange.$2.add(const Duration(days: 1)));
      return inModule && inDataset && inDate;
    }).toList();
  }

  (DateTime, DateTime) get _periodRange {
    return _rangeForPeriod(_selectedPeriod);
  }

  (DateTime, DateTime) _rangeForPeriod(ReportPeriod period) {
    final day =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    switch (period) {
      case ReportPeriod.daily:
        return (day, day);
      case ReportPeriod.weekly:
        final start = day.subtract(Duration(days: day.weekday - 1));
        return (start, start.add(const Duration(days: 6)));
      case ReportPeriod.monthly:
        final start = DateTime(day.year, day.month);
        final end = DateTime(day.year, day.month + 1, 0);
        return (start, end);
      case ReportPeriod.yearly:
        final start = DateTime(day.year, 1, 1);
        final end = DateTime(day.year, 12, 31);
        return (start, end);
    }
  }

  double get _totalAmount =>
      _filteredRecords.fold(0, (sum, item) => sum + item.amount);
  double get _paidAmount =>
      _filteredRecords.fold(0, (sum, item) => sum + item.paid);
  double get _balanceAmount =>
      _filteredRecords.fold(0, (sum, item) => sum + item.balance);

  Widget _buildLiveSummary() {
    if (!_liveLoaded) {
      return const SizedBox.shrink();
    }
    final fmt = (double v) => v >= 1000
        ? '₹${(v / 1000).toStringAsFixed(1)}k'
        : '₹${v.toStringAsFixed(0)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_outlined, size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text('Live Module Summary',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _liveMetric('Present', '${(_liveSummary['present'] ?? 0).round()}',
                  Icons.people_outline),
              _liveMetric('Food', '${(_liveSummary['food'] ?? 0).round()}',
                  Icons.restaurant_outlined),
              _liveMetric('Stock Items',
                  '${(_liveSummary['stockItems'] ?? 0).round()}',
                  Icons.inventory_2_outlined),
              _liveMetric('Low Stock',
                  '${(_liveSummary['lowStock'] ?? 0).round()}',
                  Icons.warning_amber_outlined),
              _liveMetric('Diesel (M)', '${(_liveSummary['diesel'] ?? 0).round()} L',
                  Icons.local_gas_station_outlined),
              _liveMetric('Machines', '${(_liveSummary['machines'] ?? 0).round()}',
                  Icons.precision_manufacturing_outlined),
              _liveMetric('Rentals', fmt(_liveSummary['rentalTotal'] ?? 0),
                  Icons.handyman_outlined),
              _liveMetric('Cash Spent', fmt(_liveSummary['cashSpent'] ?? 0),
                  Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveMetric(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11, color: Colors.white70)),
        Text(value,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredRecords;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Module Reports & Validation Center',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh report data',
            onPressed: () {
              setState(() {});
              _showSnack('Reports & metrics recalculated from module entries.');
            },
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildLiveSummary(),
            const SizedBox(height: 14),
            _buildPeriodSummary(),
            const SizedBox(height: 14),
            _buildModuleFilters(),
            const SizedBox(height: 14),
            _buildDatasetFilters(),
            const SizedBox(height: 14),
            _buildSearchAndDateFilters(),
            const SizedBox(height: 14),
            _buildSummaryGrid(),
            const SizedBox(height: 14),
            _buildDownloadActions(records),
            const SizedBox(height: 14),
            _buildDatasetOrderPanel(),
            const SizedBox(height: 14),
            _buildRecordsSection(records),
            const SizedBox(height: 14),
            _buildSelectedDetails(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.infoBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_outlined,
                    color: AppTheme.info),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Production Module Reports & Data Engine',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Module-wise history, dedicated table formats, and automated data validation rules across all supervisor inputs.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _notice(
            'Live Report Audit Mode: Collects 100% of fields entered by supervisors (biometrics, photos, voice notes, time blocks, split bills, and fuel efficiency metrics).',
            AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSummary() {
    return Row(
      children: [
        Expanded(
          child: _metricTile(
            'Daily',
            _countForPeriod(ReportPeriod.daily).toString(),
            Icons.today_outlined,
            AppTheme.success,
            selected: _selectedPeriod == ReportPeriod.daily,
            onTap: () => setState(() => _selectedPeriod = ReportPeriod.daily),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _metricTile(
            'Weekly',
            _countForPeriod(ReportPeriod.weekly).toString(),
            Icons.date_range_outlined,
            AppTheme.warning,
            selected: _selectedPeriod == ReportPeriod.weekly,
            onTap: () => setState(() => _selectedPeriod = ReportPeriod.weekly),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _metricTile(
            'Monthly',
            _countForPeriod(ReportPeriod.monthly).toString(),
            Icons.calendar_month_outlined,
            AppTheme.info,
            selected: _selectedPeriod == ReportPeriod.monthly,
            onTap: () => setState(() => _selectedPeriod = ReportPeriod.monthly),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _metricTile(
            'Yearly',
            _countForPeriod(ReportPeriod.yearly).toString(),
            Icons.calendar_today_outlined,
            AppTheme.primary,
            selected: _selectedPeriod == ReportPeriod.yearly,
            onTap: () => setState(() => _selectedPeriod = ReportPeriod.yearly),
          ),
        ),
      ],
    );
  }

  int _countForPeriod(ReportPeriod period) {
    return _recordsForPeriod(period).length;
  }

  Widget _buildModuleFilters() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Module Selector', 'Switch module view to see dedicated report tables'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _moduleOrder.map((module) {
              final selected = _selectedModule == module;
              return _filterChip(
                label: module,
                selected: selected,
                color: _moduleColor(module),
                onTap: () => setState(() {
                  _selectedModule = module;
                  _selectedDataset = 'All Data Sets';
                  _resetAdvancedFilters();
                  _selectedRecord = null;
                }),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetFilters() {
    final datasets = _visibleDatasets;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Data Set Sub-Filters',
            'Select dedicated process view within ${_selectedModule}',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: datasets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final dataset = datasets[index];
                final selected = _selectedDataset == dataset.id;
                return _datasetCard(dataset, selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndDateFilters() {
    final range = _periodRange;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Search & Period Controls',
            'Filter by keyword, status, supplier, or date range',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search ID, name, operator, fuel, invoice...',
                    prefixIcon: const Icon(Icons.search_outlined),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dropdownFilter(
                label: 'Status',
                value: _selectedStatus,
                values: _filterValues('status', 'All Status'),
                onChanged: (value) => setState(() {
                  _selectedStatus = value;
                  _selectedRecord = null;
                }),
              ),
              _dropdownFilter(
                label: 'Supplier',
                value: _selectedSupplier,
                values: _filterValues('supplier', 'All Suppliers'),
                onChanged: (value) => setState(() {
                  _selectedSupplier = value;
                  _selectedRecord = null;
                }),
              ),
              _dropdownFilter(
                label: 'Type',
                value: _selectedType,
                values: _filterValues('type', 'All Types'),
                onChanged: (value) => setState(() {
                  _selectedType = value;
                  _selectedRecord = null;
                }),
              ),
              _dropdownFilter(
                label: 'Brand',
                value: _selectedBrand,
                values: _filterValues('brand', 'All Brands'),
                onChanged: (value) => setState(() {
                  _selectedBrand = value;
                  _selectedRecord = null;
                }),
              ),
              _dropdownFilter(
                label: 'Shop',
                value: _selectedShop,
                values: _filterValues('shop', 'All Shops'),
                onChanged: (value) => setState(() {
                  _selectedShop = value;
                  _selectedRecord = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _notice(
            '${_periodLabel(_selectedPeriod)} Period: ${_formatDate(range.$1)} to ${_formatDate(range.$2)}',
            AppTheme.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.65,
      children: [
        _summaryTile('Total Records', _filteredRecords.length.toString(),
            Icons.dataset_outlined, AppTheme.info),
        _summaryTile('Total Amount', _money(_totalAmount),
            Icons.currency_rupee_outlined, AppTheme.warning),
        _summaryTile('Total Paid', _money(_paidAmount), Icons.verified_outlined,
            AppTheme.success),
        _summaryTile('Outstanding Balance', _money(_balanceAmount),
            Icons.pending_actions_outlined, AppTheme.danger),
      ],
    );
  }

  Widget _buildDatasetOrderPanel() {
    final modules = _selectedModule == 'All Modules'
        ? _moduleOrder.where((m) => m != 'All Modules').toList()
        : [_selectedModule];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Module Data Index',
            'All operational datasets mapped for ${_selectedModule}',
          ),
          const SizedBox(height: 8),
          ...modules.map((module) {
            final moduleDatasets =
                _datasets.where((dataset) => dataset.module == module).toList();
            if (moduleDatasets.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _moduleColor(module),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: moduleDatasets
                        .map(
                          (dataset) => _miniPill(
                            dataset.title,
                            dataset.color,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecordsSection(List<ReportRecord> records) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _sectionTitle(
                  'Module Report Table (${_selectedModule})',
                  '${records.length} records in selected period. Click row to inspect full supervisor entries.',
                ),
              ),
              _miniPill('${_periodLabel(_selectedPeriod)} View', AppTheme.primary),
            ],
          ),
          const SizedBox(height: 10),
          if (records.isEmpty) ...[
            _emptyState(),
          ] else ...[
            _buildExcelTable(records),
            const SizedBox(height: 12),
            ...records.map(_recordTile),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadActions(List<ReportRecord> records) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Export Production Reports',
            'Download CSV formatted report for ${_selectedModule} (${_periodLabel(_selectedPeriod)})',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: records.isEmpty
                      ? null
                      : () => _showExportSheet(
                            title: 'Module Summary Report',
                            fileName: _exportFileName('summary'),
                            csv: _buildSummaryCsv(records),
                          ),
                  icon: const Icon(Icons.summarize_outlined, size: 18),
                  label: const Text('Export Summary CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: records.isEmpty
                      ? null
                      : () => _showExportSheet(
                            title: 'Full Audit Detailed Report',
                            fileName: _exportFileName('detailed'),
                            csv: _buildDetailedCsv(records),
                          ),
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Export Full Audit CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExcelTable(List<ReportRecord> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(AppTheme.surfaceCard),
            headingRowHeight: 46,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 58,
            columnSpacing: 18,
            columns: _buildTableColumns(),
            rows: rows.map((record) {
              final selected = _selectedRecord?.id == record.id;
              return DataRow(
                selected: selected,
                onSelectChanged: (_) =>
                    setState(() => _selectedRecord = record),
                cells: _buildTableCells(record),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildTableColumns() {
    switch (_selectedModule) {
      case 'Workers':
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Record ID')),
          DataColumn(label: Text('Worker / Supplier')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Attendance / Shift')),
          DataColumn(label: Text('Days / Count')),
          DataColumn(label: Text('Rate / Wage')),
          DataColumn(label: Text('Total Amount')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Balance')),
          DataColumn(label: Text('Validation Status')),
        ];
      case 'Machines':
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Machine ID')),
          DataColumn(label: Text('Machine Name')),
          DataColumn(label: Text('Operator')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Hours / Litres')),
          DataColumn(label: Text('Efficiency / Reading')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Balance')),
          DataColumn(label: Text('Validation Status')),
        ];
      case 'Rentals':
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Rental ID')),
          DataColumn(label: Text('Item / Asset Name')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Billing Mode')),
          DataColumn(label: Text('Qty / Units')),
          DataColumn(label: Text('Accrued Cost')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Balance')),
          DataColumn(label: Text('Validation Status')),
        ];
      case 'Stock':
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Stock ID')),
          DataColumn(label: Text('Item Name')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Brand / Shop')),
          DataColumn(label: Text('In / Out Qty')),
          DataColumn(label: Text('Closing Balance')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Validation Status')),
        ];
      case 'Cash':
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Trans ID')),
          DataColumn(label: Text('Category / Reason')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Spent / Requested')),
          DataColumn(label: Text('Opening Bal')),
          DataColumn(label: Text('Closing Bal')),
          DataColumn(label: Text('Attachment Proof')),
          DataColumn(label: Text('Validation Status')),
        ];
      default:
        return const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Module')),
          DataColumn(label: Text('Data Set')),
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Name / Title')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Supplier')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Paid')),
          DataColumn(label: Text('Balance')),
          DataColumn(label: Text('Validation Status')),
        ];
    }
  }

  List<DataCell> _buildTableCells(ReportRecord record) {
    final statusColor = _statusColor(record.status);
    final validText = record.details['Validation Status'] ?? 'Valid';

    switch (_selectedModule) {
      case 'Workers':
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 150, child: Text(record.title))),
          DataCell(Text(record.type)),
          DataCell(Text(record.details['Attendance Status'] ?? record.details['Shift'] ?? '-')),
          DataCell(Text(record.details['Days Present'] ?? record.details['Worker Count'] ?? '-')),
          DataCell(Text(record.details['Daily Shift Wage'] ?? record.details['Shift Wages'] ?? '-')),
          DataCell(Text(_money(record.amount))),
          DataCell(Text(_money(record.paid))),
          DataCell(Text(_money(record.balance))),
          DataCell(_statusChip(record.status, statusColor)),
        ];
      case 'Machines':
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 150, child: Text(record.title))),
          DataCell(Text(record.details['Operator Name'] ?? record.details['Operator'] ?? '-')),
          DataCell(Text(record.type)),
          DataCell(Text(record.details['Total Working Hours'] ?? record.details['Litres Issued'] ?? '-')),
          DataCell(Text(record.details['Consumption Rate'] ?? record.details['Odometer Reading'] ?? '-')),
          DataCell(Text(_money(record.amount))),
          DataCell(Text(_money(record.paid))),
          DataCell(Text(_money(record.balance))),
          DataCell(_statusChip(record.status, statusColor)),
        ];
      case 'Rentals':
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 150, child: Text(record.title))),
          DataCell(Text(record.details['Category'] ?? record.type)),
          DataCell(Text(record.details['Billing Mode'] ?? '-')),
          DataCell(Text(record.details['Quantity Rented'] ?? record.details['Usage Units'] ?? '1')),
          DataCell(Text(_money(record.amount))),
          DataCell(Text(_money(record.paid))),
          DataCell(Text(_money(record.balance))),
          DataCell(_statusChip(record.status, statusColor)),
        ];
      case 'Stock':
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 150, child: Text(record.title))),
          DataCell(Text(record.details['Item Code'] ?? record.type)),
          DataCell(Text('${record.brand} / ${record.shop}')),
          DataCell(Text(record.details['Inward Purchases'] ?? record.details['Sent Quantity'] ?? '-')),
          DataCell(Text(record.details['Current Closing Stock'] ?? '-')),
          DataCell(Text(_money(record.amount))),
          DataCell(_statusChip(record.status, statusColor)),
        ];
      case 'Cash':
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 150, child: Text(record.title))),
          DataCell(Text(record.type)),
          DataCell(Text(_money(record.amount))),
          DataCell(Text(record.details['Opening Supervisor Cash'] ?? '-')),
          DataCell(Text(record.details['Closing Supervisor Cash'] ?? '-')),
          DataCell(Text(record.details['Invoice Attachment'] ?? record.details['Bill Photo'] ?? 'Attached')),
          DataCell(_statusChip(record.status, statusColor)),
        ];
      default:
        return [
          DataCell(Text(_formatDate(record.date))),
          DataCell(Text(record.module)),
          DataCell(Text(_datasetTitle(record.dataset))),
          DataCell(Text(record.id)),
          DataCell(SizedBox(width: 160, child: Text(record.title))),
          DataCell(_statusChip(record.status, statusColor)),
          DataCell(Text(record.supplier)),
          DataCell(Text(record.type)),
          DataCell(Text(_money(record.amount))),
          DataCell(Text(_money(record.paid))),
          DataCell(Text(_money(record.balance))),
          DataCell(_statusChip(validText.contains('Valid') ? 'Valid' : 'Audit Check', statusColor)),
        ];
    }
  }

  Widget _buildSelectedDetails() {
    final record = _selectedRecord;
    if (record == null) {
      return _card(
        child: _notice(
          'Select any table row above to open complete supervisor data fields, biometric states, attached images, voice notes, and payment breakdowns.',
          AppTheme.info,
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  record.title,
                  '${record.module} / ${_datasetTitle(record.dataset)} / Date: ${_formatDate(record.date)}',
                ),
              ),
              _statusChip(record.status, _statusColor(record.status)),
            ],
          ),
          const SizedBox(height: 12),
          _detailGrid(record),
          const SizedBox(height: 12),
          _paymentPanel(record),
          const SizedBox(height: 12),
          const Text(
            'Complete Supervisor Inputs & Validation Audit',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...record.details.entries.map(
            (entry) => _detailLine(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(ReportRecord record) {
    final selected = _selectedRecord?.id == record.id;
    final color = _moduleColor(record.module);
    return InkWell(
      onTap: () => setState(() => _selectedRecord = record),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_moduleIcon(record.module), color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _miniPill(record.module, color),
                      _miniPill(_formatDate(record.date), AppTheme.textMuted),
                      if (record.invoice != '-')
                        _miniPill(record.invoice, AppTheme.info),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(record.amount),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                _statusChip(record.status, _statusColor(record.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailGrid(ReportRecord record) {
    final fields = [
      ('ID', record.id),
      ('Supplier', record.supplier),
      ('Type', record.type),
      ('Brand', record.brand),
      ('Shop', record.shop),
      ('Invoice', record.invoice),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.9,
      children: fields.map((field) => _smallInfo(field.$1, field.$2)).toList(),
    );
  }

  Widget _paymentPanel(ReportRecord record) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppTheme.success, size: 18),
              SizedBox(width: 8),
              Text(
                'Financial Reconciliation Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _paymentMetric('Gross Amount', _money(record.amount))),
              const SizedBox(width: 8),
              Expanded(child: _paymentMetric('Paid Amount', _money(record.paid))),
              const SizedBox(width: 8),
              Expanded(
                  child: _paymentMetric('Balance Due', _money(record.balance))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.subtleShadow,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
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
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _datasetCard(ReportDataset dataset, bool selected) {
    return InkWell(
      onTap: () => setState(() {
        _selectedDataset = dataset.id;
        _selectedRecord = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? dataset.color.withValues(alpha: 0.12)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? dataset.color : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(dataset.icon, color: dataset.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dataset.module,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: dataset.color,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              dataset.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              dataset.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdownFilter({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
          items: values.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<String> _filterValues(String key, String allLabel) {
    final set = <String>{allLabel};
    for (var r in _records) {
      final val = switch (key) {
        'status' => r.status,
        'supplier' => r.supplier,
        'type' => r.type,
        'brand' => r.brand,
        'shop' => r.shop,
        _ => '-',
      };
      if (val != '-') set.add(val);
    }
    return set.toList();
  }

  Widget _metricTile(
    String label,
    String count,
    IconData icon,
    Color color, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _miniPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _smallInfo(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_outlined,
                size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            const Text(
              'No matching records found',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search query, module filters or selected period range.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _resetAdvancedFilters() {
    _selectedStatus = 'All Status';
    _selectedSupplier = 'All Suppliers';
    _selectedType = 'All Types';
    _selectedBrand = 'All Brands';
    _selectedShop = 'All Shops';
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedRecord = null;
      });
    }
  }

  String _datasetTitle(String datasetId) {
    if (datasetId == 'All Data Sets') return 'All Data Sets';
    final found = _datasets.where((d) => d.id == datasetId);
    return found.isNotEmpty ? found.first.title : datasetId;
  }

  String _periodLabel(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.daily:
        return 'Daily';
      case ReportPeriod.weekly:
        return 'Weekly';
      case ReportPeriod.monthly:
        return 'Monthly';
      case ReportPeriod.yearly:
        return 'Yearly';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _money(double val) {
    return '₹${val.toStringAsFixed(0)}';
  }

  Color _moduleColor(String module) {
    switch (module) {
      case 'Workers':
        return AppTheme.success;
      case 'Machines':
        return AppTheme.info;
      case 'Suppliers':
        return AppTheme.warning;
      case 'Rentals':
        return AppTheme.danger;
      case 'Stock':
        return AppTheme.info;
      case 'Payments':
        return AppTheme.success;
      case 'Cash':
        return AppTheme.success;
      case 'Food':
        return AppTheme.warning;
      case 'Transfers':
        return AppTheme.info;
      case 'Tasks':
        return AppTheme.success;
      case 'Other Expenses':
        return AppTheme.danger;
      case 'Session':
        return AppTheme.primary;
      default:
        return AppTheme.primary;
    }
  }

  IconData _moduleIcon(String module) {
    switch (module) {
      case 'Workers':
        return Icons.groups_outlined;
      case 'Machines':
        return Icons.precision_manufacturing_outlined;
      case 'Suppliers':
        return Icons.store_mall_directory_outlined;
      case 'Rentals':
        return Icons.key_outlined;
      case 'Stock':
        return Icons.inventory_2_outlined;
      case 'Payments':
        return Icons.payments_outlined;
      case 'Cash':
        return Icons.account_balance_wallet_outlined;
      case 'Food':
        return Icons.restaurant_menu_outlined;
      case 'Transfers':
        return Icons.swap_horiz_outlined;
      case 'Tasks':
        return Icons.task_alt_outlined;
      case 'Other Expenses':
        return Icons.receipt_outlined;
      case 'Session':
        return Icons.login_outlined;
      default:
        return Icons.dashboard_outlined;
    }
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('inactive') || lower.contains('warning') || lower.contains('high')) return AppTheme.warning;
    if (lower.contains('active') ||
        lower.contains('completed') ||
        lower.contains('paid') ||
        lower.contains('healthy') ||
        lower.contains('received') ||
        lower.contains('submitted') ||
        lower.contains('closed') ||
        lower.contains('matched') ||
        lower.contains('verified') ||
        lower.contains('validated') ||
        lower.contains('accepted') ||
        lower.contains('available') ||
        lower.contains('logged')) {
      return AppTheme.success;
    }
    if (lower.contains('pending') ||
        lower.contains('due') ||
        lower.contains('partial') ||
        lower.contains('progress') ||
        lower.contains('transit') ||
        lower.contains('request')) {
      return AppTheme.info;
    }
    return AppTheme.danger;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _exportFileName(String prefix) {
    final mod = _selectedModule.replaceAll(' ', '_').toLowerCase();
    final dat = _selectedDataset.replaceAll(' ', '_').toLowerCase();
    final dateStr = _formatDate(_selectedDate);
    return '${prefix}_${mod}_${dat}_$dateStr.csv';
  }

  String _buildSummaryCsv(List<ReportRecord> records) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Module,DataSet,ID,Title,Status,Supplier,Type,Amount,Paid,Balance,ValidationStatus');
    for (var r in records) {
      final valid = r.details['Validation Status'] ?? 'Valid';
      buffer.writeln(
        '"${_formatDate(r.date)}","${r.module}","${_datasetTitle(r.dataset)}","${r.id}","${r.title.replaceAll('"', '""')}","${r.status}","${r.supplier}","${r.type}",${r.amount},${r.paid},${r.balance},"${valid}"',
      );
    }
    return buffer.toString();
  }

  String _buildDetailedCsv(List<ReportRecord> records) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Module,DataSet,ID,Title,Subtitle,Status,Supplier,Type,Brand,Shop,Invoice,Amount,Paid,Balance,DetailKeysValues');
    for (var r in records) {
      final detailsStr = r.details.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
      buffer.writeln(
        '"${_formatDate(r.date)}","${r.module}","${_datasetTitle(r.dataset)}","${r.id}","${r.title.replaceAll('"', '""')}","${r.subtitle.replaceAll('"', '""')}","${r.status}","${r.supplier}","${r.type}","${r.brand}","${r.shop}","${r.invoice}",${r.amount},${r.paid},${r.balance},"${detailsStr.replaceAll('"', '""')}"',
      );
    }
    return buffer.toString();
  }

  void _showExportSheet({
    required String title,
    required String fileName,
    required String csv,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.file_download_outlined, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'File Name: $fileName',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final path = await downloadCsvFile(
                          fileName: fileName,
                          csv: csv,
                        );
                        if (context.mounted) Navigator.pop(context);
                        if (path != null) {
                          _showSnack('Report saved to $path');
                        } else {
                          _showSnack('Report download started.');
                        }
                      },
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Download CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csv));
                        Navigator.pop(context);
                        _showSnack('CSV content copied to clipboard.');
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copy CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
