import '../models/hod_workflow_models.dart';

/// Repository boundary for HOD/supervisor workflows.
///
/// Local module data was intentionally removed. Keep this API shape as the
/// future backend connection point, but do not persist or share workflow data
/// on the device.
class HodWorkflowStore {
  Future<void> saveUsers(List<ThavvuUser> users) async {}

  Future<List<ThavvuUser>> users() async => const [];

  Future<void> saveSites(List<ThavvuSite> sites) async {}

  Future<List<ThavvuSite>> sites() async => const [];

  Future<void> upsertApprovalRequest(ApprovalRequestRecord request) async {}

  Future<List<ApprovalRequestRecord>> approvalRequests() async => const [];

  Future<List<ApprovalRequestRecord>> requestsForHod(String hodId) async =>
      const [];

  Future<List<ApprovalRequestRecord>> requestsForSupervisor(
    String supervisorId,
  ) async =>
      const [];

  Future<void> saveHodMapUpload(HodMapUploadRecord upload) async {}

  Future<List<HodMapUploadRecord>> hodMapUploads() async => const [];

  Future<List<HodMapUploadRecord>> mapUploadsForSite(String siteId) async =>
      const [];

  Future<List<HodMapUploadRecord>> mapUploadsForSupervisor(
    String supervisorId,
  ) async =>
      const [];

  Future<List<HodMapUploadRecord>> mapUploadsForHod(String hodId) async =>
      const [];

  Future<void> recordSupervisorAction(SupervisorActionRecord action) async {}

  Future<List<SupervisorActionRecord>> supervisorActions() async => const [];

  Future<List<SupervisorActionRecord>> supervisorActionsForHod(
    String hodId,
  ) async =>
      const [];

  Future<HodDashboardSummary> hodDashboardSummary(String hodId) async {
    return const HodDashboardSummary(
      totalRequests: 0,
      pendingRequests: 0,
      statusCounts: {},
      moduleCounts: {},
      supervisorCounts: {},
      recentRequests: [],
      recentSupervisorActions: [],
    );
  }

  Future<ApprovalRequestRecord> updateRequestStatus({
    required String requestId,
    required ApprovalStatus status,
    required String actorId,
    DateTime? actedAt,
    String? note,
  }) async {
    throw StateError(
      'Local HOD workflow store is disabled. Connect this action to the backend repository.',
    );
  }

  Future<List<AuditLogRecord>> auditLogs() async => const [];
}
