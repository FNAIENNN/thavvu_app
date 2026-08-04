import 'hod_workflow_store.dart';

/// Backend seeding placeholder.
///
/// Local demo seeding was removed so module data does not appear connected on
/// the device. Real seed/bootstrap logic should live in the backend or a
/// backend-backed repository implementation.
class ThavvuWorkflowSeedService {
  final HodWorkflowStore store;

  ThavvuWorkflowSeedService({HodWorkflowStore? store})
      : store = store ?? HodWorkflowStore();

  Future<void> ensureSeeded() async {}
}
