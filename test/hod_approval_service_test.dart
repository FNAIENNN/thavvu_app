import 'package:flutter_test/flutter_test.dart';
import 'package:thavvu_app/services/hod_approval_service.dart';

void main() {
  test('HOD approval service does not persist statuses locally', () async {
    final service = HodApprovalService();

    await service.setStatus('REQ-001', 'Approved');

    expect(await service.getStatus('REQ-001'), 'Pending');
    expect(await service.getStatuses(['REQ-001', 'REQ-002']), {
      'REQ-001': 'Pending',
      'REQ-002': 'Pending',
    });
  });
}
