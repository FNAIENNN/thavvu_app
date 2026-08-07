import 'package:thavvu_supervisor/services/db_client.dart';

Future<void> main() async {
  final tables = [
    'stock_transfers',
    'machine_daily_logs',
    'supplier_payment_requests',
    'sites',
    'thavvu_points',
    'app_activity_events',
    'machine_assets',
    'stock_orders',
  ];
  for (final t in tables) {
    final rows = await DbClient.instance.maps(
      "select column_name, data_type from information_schema.columns where table_name = @t order by ordinal_position",
      parameters: {'t': t},
    );
    print('--- $t ---');
    for (final r in rows) {
      print('  ${r['column_name']}: ${r['data_type']}');
    }
  }
  await DbClient.instance.close();
}
