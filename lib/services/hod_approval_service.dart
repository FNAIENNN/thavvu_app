/// Approval service boundary with device-local persistence disabled.
///
/// Wire these methods to the real backend when approval workflows are
/// implemented. Until then, no module approval state is stored locally.
class HodApprovalService {
  Future<void> setStatus(String requestId, String status) async {}

  Future<String> getStatus(String requestId) async => 'Pending';

  Future<Map<String, String>> getStatuses(Iterable<String> requestIds) async {
    return {for (final id in requestIds) id: 'Pending'};
  }

  Future<void> clearStatus(String requestId) async {}
}
