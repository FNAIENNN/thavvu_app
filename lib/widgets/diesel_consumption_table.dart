// File: lib/widgets/diesel_consumption_table.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DieselConsumptionTable extends StatefulWidget {
  final List<String> fuelTypes;
  final List<String> stockPoints;
  final Function(List<Map<String, dynamic>>)? onChanged;

  const DieselConsumptionTable({
    super.key,
    required this.fuelTypes,
    required this.stockPoints,
    this.onChanged,
  });

  @override
  State<DieselConsumptionTable> createState() => _DieselConsumptionTableState();
}

class _DieselConsumptionTableState extends State<DieselConsumptionTable> {
  final List<Map<String, dynamic>> _rows = [];
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedFuelType;
  String? _selectedStockPoint;
  int? _numberOfLiners;
  double _autoAmount = 0.0;
  final double _ratePerLiter = 100.0; // ₹100 per liter

  void _addRow() {
    if (_selectedFuelType != null && 
        _selectedStockPoint != null && 
        _numberOfLiners != null) {
      setState(() {
        _rows.add({
          'fuelType': _selectedFuelType,
          'stockPoint': _selectedStockPoint,
          'numberOfLiners': _numberOfLiners,
          'amount': _autoAmount,
        });
        _selectedFuelType = null;
        _selectedStockPoint = null;
        _numberOfLiners = null;
        _quantityController.clear();
        _autoAmount = 0.0;
      });
      widget.onChanged?.call(_rows);
    }
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
    widget.onChanged?.call(_rows);
  }

  void _calculateAmount() {
    if (_numberOfLiners != null) {
      setState(() {
        _autoAmount = _numberOfLiners! * _ratePerLiter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add Row Form
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Fuel Type Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFuelType,
                      decoration: const InputDecoration(
                        labelText: 'Fuel Type',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: widget.fuelTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFuelType = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stock Point Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStockPoint,
                      decoration: const InputDecoration(
                        labelText: 'Stock Point',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: widget.stockPoints.map((point) {
                        return DropdownMenuItem(
                          value: point,
                          child: Text(point, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStockPoint = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Number of Liners
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'No. of Liners',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _numberOfLiners = int.tryParse(value) ?? 0;
                          _calculateAmount();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Auto-generated Amount
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '₹${_autoAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addRow,
                    icon: const Icon(Icons.add_circle, color: AppTheme.success),
                    tooltip: 'Add Row',
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Data Table
        if (_rows.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Fuel Type', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Stock Point', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('No. of Liners', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: _rows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  return DataRow(
                    cells: [
                      DataCell(Text(row['fuelType'])),
                      DataCell(Text(row['stockPoint'])),
                      DataCell(Text(row['numberOfLiners'].toString())),
                      DataCell(Text('₹${row['amount'].toStringAsFixed(2)}')),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppTheme.danger, size: 20),
                          onPressed: () => _removeRow(index),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '₹${_rows.fold<double>(0, (sum, row) => sum + (row['amount'] as double)).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }
}