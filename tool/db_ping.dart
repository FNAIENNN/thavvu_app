import 'package:thavvu_supervisor/services/db_client.dart';
import 'package:thavvu_supervisor/services/remote_repository.dart';

Future<void> main() async {
  final repo = RemoteRepository();
  final ok = await repo.ping();
  print('ping=$ok err=${repo.lastError}');
  if (!ok) return;
  final user = await repo.login('supervisor@thavvu.com', 'password');
  print('login=${user?['email']} role=${user?['role']} id=${user?['id']}');
  final hod = await repo.login('hod@thavvu.com', 'password');
  print('hod=${hod?['email']} role=${hod?['role']}');
  final items = await repo.stockItems();
  print('stockItems=${items.length}');
  for (final e in items.take(5)) {
    print('  ${e['name']} | ${e['category']} | ${e['primary_uom']}');
  }
  final sites = await repo.allSites();
  print('sites=${sites.map((e) => e['id']).toList()}');
  final bal = await repo.stockBalances(thavvuPointId: 'TP-VIZ-001');
  print('balances=${bal.length}');
  for (final e in bal) {
    print('  ${e['item_name']}=${e['available_qty']}');
  }
  await DbClient.instance.close();
}
