/// Static stock item catalog + unit preferences for the Thavvu backend.
///
/// The catalog is the single source of truth for which units and categories a
/// named stock item uses (diesel/petrol → Litres, chemicals → Bags/Kg,
/// grease → Tubes, bolts → Pieces, etc.).
import 'app_models.dart';

class StockCatalog {
  StockCatalog._();

  static const List<StockItemDef> items = [
    StockItemDef(id: 'ITM-DIESEL', name: 'Diesel', category: StockCategory.fuel, unit: 'Litres', reorderLevel: 100),
    StockItemDef(id: 'ITM-PETROL', name: 'Petrol', category: StockCategory.fuel, unit: 'Litres', reorderLevel: 50),
    StockItemDef(id: 'ITM-ENGINE-OIL', name: 'Engine Oil', category: StockCategory.lubricant, unit: 'Litres', reorderLevel: 30),
    StockItemDef(id: 'ITM-HYD-FLUID', name: 'Hydraulic Fluid', category: StockCategory.lubricant, unit: 'Litres', reorderLevel: 25),
    StockItemDef(id: 'ITM-GREASE', name: 'Grease', category: StockCategory.lubricant, unit: 'Tubes', reorderLevel: 15),
    StockItemDef(id: 'ITM-COOLANT', name: 'Coolant', category: StockCategory.chemical, unit: 'Litres', reorderLevel: 20),
    StockItemDef(id: 'ITM-CEMENT', name: 'Cement', category: StockCategory.chemical, unit: 'Bags', reorderLevel: 40),
    StockItemDef(id: 'ITM-ADMIXTURE', name: 'Admixture', category: StockCategory.chemical, unit: 'Kg', reorderLevel: 30),
    StockItemDef(id: 'ITM-BOLTS-NUTS', name: 'Bolts & Nuts', category: StockCategory.parts, unit: 'Pieces', reorderLevel: 200),
    StockItemDef(id: 'ITM-WELDING-RODS', name: 'Welding Rods', category: StockCategory.parts, unit: 'Kg', reorderLevel: 25),
    StockItemDef(id: 'ITM-SAND', name: 'Sand', category: StockCategory.material, unit: 'Bags', reorderLevel: 50),
    StockItemDef(id: 'ITM-AGGREGATE', name: 'Aggregate', category: StockCategory.material, unit: 'Kg', reorderLevel: 500),
  ];

  static StockItemDef? byName(String name) {
    final needle = name.trim().toLowerCase();
    for (final item in items) {
      if (item.name.toLowerCase() == needle) return item;
    }
    return null;
  }

  static StockItemDef? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<StockItemDef> byCategory(String category) =>
      items.where((i) => i.category == category).toList();

  static List<String> get names => items.map((e) => e.name).toList();

  /// Resolve the preferred unit for an item name, falling back to the category
  /// default and finally to 'Nos'.
  static String unitForName(String name, {String fallbackCategory = StockCategory.other}) {
    final def = byName(name);
    if (def != null) return def.unit;
    return StockCategory.defaultUnit(fallbackCategory);
  }

  static String categoryForName(String name) {
    final def = byName(name);
    return def?.category ?? StockCategory.other;
  }
}
