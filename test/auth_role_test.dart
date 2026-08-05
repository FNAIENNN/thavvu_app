import 'package:flutter_test/flutter_test.dart';

import 'package:thavvu_app/services/auth_service.dart';

void main() {
  group('AuthService.resolveRealRole', () {
    test('returns the metadata role lowercased', () {
      expect(AuthService.resolveRealRole({'role': 'HOD'}), 'hod');
      expect(AuthService.resolveRealRole({'role': 'Supervisor'}), 'supervisor');
      expect(AuthService.resolveRealRole({'role': '  ADMIN  '}), 'admin');
    });

    test('returns empty when metadata has no role', () {
      expect(AuthService.resolveRealRole(null), '');
      expect(AuthService.resolveRealRole(const {}), '');
      expect(AuthService.resolveRealRole({'full_name': 'X'}), '');
      expect(AuthService.resolveRealRole({'role': '  '}), '');
    });

    test('ignores non-string role values', () {
      expect(AuthService.resolveRealRole({'role': 42}), '');
      expect(AuthService.resolveRealRole({'role': ['hod']}), '');
    });
  });
}
