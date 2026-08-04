import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/models/hod_workflow_models.dart';
import 'package:thavvu_app/services/hod_workflow_store.dart';

void main() {
  test('HOD workflow store does not persist module data locally', () async {
    final store = HodWorkflowStore();

    await store.saveUsers(const [
      ThavvuUser(
        id: 'HOD-001',
        name: 'HOD One',
        role: ThavvuRole.hod,
        assignedSiteIds: ['SITE-001'],
      ),
    ]);
    await store.saveSites(const [
      ThavvuSite(id: 'SITE-001', name: 'Site One', place: 'Vijayawada'),
    ]);
    await store.upsertApprovalRequest(ApprovalRequestRecord(
      id: 'REQ-001',
      module: 'Cash',
      title: 'Cash request',
      siteId: 'SITE-001',
      supervisorId: 'SUP-001',
      status: ApprovalStatus.pending,
      createdAt: DateTime.utc(2026, 1, 1),
    ));

    expect(await store.users(), isEmpty);
    expect(await store.sites(), isEmpty);
    expect(await store.approvalRequests(), isEmpty);
    expect(await store.requestsForHod('HOD-001'), isEmpty);
    expect(await store.requestsForSupervisor('SUP-001'), isEmpty);
  });

  test('local HOD status updates are disabled until backend is connected',
      () async {
    final store = HodWorkflowStore();

    expect(
      () => store.updateRequestStatus(
        requestId: 'REQ-001',
        status: ApprovalStatus.approved,
        actorId: 'HOD-001',
      ),
      throwsStateError,
    );
  });
}
