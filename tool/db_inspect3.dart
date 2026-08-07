import 'package:thavvu_supervisor/services/db_client.dart';
import 'package:thavvu_supervisor/services/remote_repository.dart';

Future<void> main() async {
  final repo = RemoteRepository();
  final ok = await repo.ping();
  print('ping=$ok');
  if (!ok) return;

  Future<void> dump(String label, Future<List<Map<String, dynamic>>> fut) async {
    try {
      final rows = await fut;
      print('--- $label (${rows.length}) ---');
      if (rows.isNotEmpty) print(rows.first);
    } catch (e) {
      print('--- $label ERROR: $e ---');
    }
  }

  await dump('sites', repo.allSites());
  await dump('thavvuPoints', repo.thavvuPointsForSite('SITE-VIZ-001'));
  await dump('stockItems', repo.stockItems());
  await dump('stockBalances', repo.stockBalances(thavvuPointId: 'TP-VIZ-001'));
  await dump('stockOrders', repo.stockOrders());
  await dump('stockTransfers', repo.stockTransfers());
  await dump('machines', repo.machines());
  await dump('dailyLogs', repo.dailyLogs());
  await dump('suppliers', repo.suppliers());
  await dump('supplierPaymentRequests', repo.supplierPaymentRequests());
  await dump('workers', repo.workers());
  await dump('tasks', repo.tasks());
  await dump('activity', repo.activityReport(limit: 5));

  await DbClient.instance.close();
}
