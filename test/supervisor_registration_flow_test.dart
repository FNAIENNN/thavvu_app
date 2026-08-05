import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thavvu_app/screens/login_screen.dart';
import 'package:thavvu_app/services/supervisor_registration_repository.dart';

void main() {
  group('SupervisorRegistration model', () {
    test('parses a pending request', () {
      final request = SupervisorRegistration.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'full_name': 'Mohan Chandra',
        'emp_id': 'THV-SUP-008',
        'phone': '+91 98765 43210',
        'site_name': 'Site A - Chennai',
        'email': 'mohan@thavvu.com',
        'status': 'pending',
        'admin_note': null,
        'reviewed_at': null,
        'created_at': '2026-08-05T10:00:00Z',
      });

      expect(request.id, '11111111-1111-1111-1111-111111111111');
      expect(request.fullName, 'Mohan Chandra');
      expect(request.empId, 'THV-SUP-008');
      expect(request.phone, '+91 98765 43210');
      expect(request.siteName, 'Site A - Chennai');
      expect(request.email, 'mohan@thavvu.com');
      expect(request.status, 'pending');
      expect(request.isPending, isTrue);
      expect(request.isApproved, isFalse);
      expect(request.isRejected, isFalse);
      expect(request.adminNote, isNull);
      expect(request.reviewedAt, isNull);
      expect(request.createdAt.isUtc, isTrue);
    });

    test('parses a rejected request with admin note', () {
      final request = SupervisorRegistration.fromJson({
        'id': '22222222-2222-2222-2222-222222222222',
        'full_name': 'Ravi',
        'emp_id': 'EMP009',
        'phone': '9999999999',
        'site_name': '',
        'email': 'ravi@thavvu.com',
        'status': 'rejected',
        'admin_note': 'Employee ID mismatch',
        'reviewed_at': '2026-08-05T11:30:00Z',
        'created_at': '2026-08-05T09:00:00Z',
      });

      expect(request.isRejected, isTrue);
      expect(request.adminNote, 'Employee ID mismatch');
      expect(request.reviewedAt, isNotNull);
    });

    test('parses an approved request', () {
      final request = SupervisorRegistration.fromJson({
        'id': '33333333-3333-3333-3333-333333333333',
        'full_name': 'Sita',
        'emp_id': 'THV-SUP-009',
        'phone': '8888888888',
        'site_name': 'Site B',
        'email': 'sita@thavvu.com',
        'status': 'approved',
        'created_at': '2026-08-05T08:00:00Z',
      });

      expect(request.isApproved, isTrue);
      expect(request.isPending, isFalse);
    });

    test('survives missing/empty fields', () {
      final request = SupervisorRegistration.fromJson(const {});
      expect(request.id, '');
      expect(request.fullName, '');
      expect(request.status, 'pending');
      expect(request.createdAt, isNotNull);
    });
  });

  group('RegistrationSiteOption model', () {
    test('label combines name and place', () {
      const site = RegistrationSiteOption(
          id: 'SITE-VJA-001', name: 'Vijayawada Site', place: 'Andhra');
      expect(site.label, 'Vijayawada Site · Andhra');
    });

    test('label falls back to id when name is empty', () {
      const site = RegistrationSiteOption(id: 'SITE-X', name: '', place: '');
      expect(site.label, 'SITE-X');
    });
  });

  group('LoginScreen create-account form', () {
    Future<void> pumpLogin(WidgetTester tester,
        _FakeRegistrationRepository fake) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(registrationRepository: fake)));
      await tester.ensureVisible(find.text('Create New Account'));
      await tester.tap(find.text('Create New Account'));
      await tester.pumpAndSettle();
    }

    testWidgets('validates before submitting', (tester) async {
      var submitCalls = 0;
      final fake = _FakeRegistrationRepository((params) async {
        submitCalls++;
        return {'id': 'req-1', 'status': 'pending', 'message': 'Submitted'};
      });

      await pumpLogin(tester, fake);

      // Empty form → validation errors, no RPC call.
      await tester.ensureVisible(find.text('Submit for Approval'));
      await tester.tap(find.text('Submit for Approval'));
      await tester.pumpAndSettle();
      expect(submitCalls, 0);
      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Password must be at least 6 characters'),
          findsOneWidget);
    });

    testWidgets('submits the request and returns to login on success',
        (tester) async {
      Map<String, dynamic>? received;
      final fake = _FakeRegistrationRepository((params) async {
        received = params;
        return {
          'id': 'req-1',
          'status': 'pending',
          'message': 'Request submitted for HOD approval.',
        };
      });

      await pumpLogin(tester, fake);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Mohan Chandra');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Employee ID'), 'THV-SUP-010');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone Number'), '+91 98765 43210');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Site / Stock Point'),
          'Site A - Chennai');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'mohan.chandra@thavvu.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Create Password'), 'Secret123');
      await tester.pump();

      await tester.ensureVisible(find.text('Submit for Approval'));
      await tester.tap(find.text('Submit for Approval'));
      await tester.pumpAndSettle();

      expect(received, isNotNull);
      expect(received!['fullName'], 'Mohan Chandra');
      expect(received!['empId'], 'THV-SUP-010');
      expect(received!['email'], 'mohan.chandra@thavvu.com');
      expect(received!['password'], 'Secret123');
      expect(received!['siteName'], 'Site A - Chennai');

      // Success snackbar + back on the login view.
      expect(find.text('Request submitted for HOD approval.'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('shows server-side error message on duplicate email',
        (tester) async {
      final fake = _FakeRegistrationRepository((params) async {
        throw RegistrationSubmitException(
            'An account already exists with this email — please sign in');
      });

      await pumpLogin(tester, fake);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'), 'Mohan Chandra');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Employee ID'), 'THV-SUP-010');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Phone Number'), '+91 98765 43210');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Site / Stock Point'),
          'Site A - Chennai');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address'),
          'mohan.chandra@thavvu.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Create Password'), 'Secret123');
      await tester.pump();

      await tester.ensureVisible(find.text('Submit for Approval'));
      await tester.tap(find.text('Submit for Approval'));
      await tester.pumpAndSettle();

      expect(
          find.text('An account already exists with this email — please sign in'),
          findsOneWidget);
      // Still on the create-account view after a failure.
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}

class _FakeRegistrationRepository implements SupervisorRegistrationRepository {
  _FakeRegistrationRepository(this.onSubmit);

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> params)
      onSubmit;

  @override
  Future<Map<String, dynamic>> submit({
    required String fullName,
    required String empId,
    required String phone,
    required String siteName,
    required String email,
    required String password,
  }) {
    return onSubmit({
      'fullName': fullName,
      'empId': empId,
      'phone': phone,
      'siteName': siteName,
      'email': email,
      'password': password,
    });
  }

  @override
  Future<List<SupervisorRegistration>> fetchRequests({String? status}) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> approve(String requestId, {String? siteId}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> reject(String requestId, {String? reason}) {
    throw UnimplementedError();
  }

  @override
  Future<List<RegistrationSiteOption>> fetchSites() {
    throw UnimplementedError();
  }

  @override
  RealtimeChannel watchRequests(void Function() onChanged) {
    throw UnimplementedError();
  }

  @override
  Future<void> stopWatching(RealtimeChannel? channel) async {}
}
