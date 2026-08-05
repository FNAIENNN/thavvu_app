import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A supervisor self-registration request awaiting (or after) HOD review.
class SupervisorRegistration {
  final String id;
  final String fullName;
  final String empId;
  final String phone;
  final String siteName;
  final String email;
  final String status; // pending | approved | rejected
  final String? adminNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const SupervisorRegistration({
    required this.id,
    required this.fullName,
    required this.empId,
    required this.phone,
    required this.siteName,
    required this.email,
    required this.status,
    this.adminNote,
    this.reviewedAt,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory SupervisorRegistration.fromJson(Map<String, dynamic> json) {
    return SupervisorRegistration(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      empId: json['emp_id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      siteName: json['site_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      adminNote: json['admin_note']?.toString(),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// A site option for the HOD approval site picker.
class RegistrationSiteOption {
  final String id;
  final String name;
  final String place;

  const RegistrationSiteOption({
    required this.id,
    required this.name,
    required this.place,
  });

  String get label => name.isEmpty ? id : '$name · $place'.trim();

  factory RegistrationSiteOption.fromJson(Map<String, dynamic> json) {
    return RegistrationSiteOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
    );
  }
}

/// Backend for the supervisor self-registration + HOD approval flow.
///
/// Reads are plain PostgREST selects (RLS limits them to HOD/admin and keeps
/// the `password_hash` column out of the payload by selecting explicit
/// columns). All writes go through SECURITY DEFINER RPCs.
class SupervisorRegistrationRepository {
  SupervisorRegistrationRepository({SupabaseClient? client})
      : _providedClient = client;

  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const _table = 'supervisor_registration_requests';

  /// Fetches registration requests, newest first. `status` is optional.
  Future<List<SupervisorRegistration>> fetchRequests({String? status}) async {
    try {
      var query = _client
          .from(_table)
          .select(
              'id, full_name, emp_id, phone, site_name, email, status, admin_note, reviewed_at, created_at');
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .map((row) => SupervisorRegistration.fromJson(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('fetchSupervisorRegistrations failed: $e');
      return [];
    }
  }

  /// Submits a new registration request (login screen, anonymous caller).
  /// No password is collected — the HOD assigns it at approval.
  /// Returns the RPC result map; throws [RegistrationSubmitException] with a
  /// user-friendly message on validation / duplicate errors.
  Future<Map<String, dynamic>> submit({
    required String fullName,
    required String empId,
    required String phone,
    required String siteName,
    required String email,
  }) async {
    try {
      final result = await _client.rpc('submit_supervisor_registration', params: {
        'p_full_name': fullName,
        'p_emp_id': empId,
        'p_phone': phone,
        'p_site_name': siteName,
        'p_email': email,
      });
      final map = _asMap(result);
      return map;
    } on PostgrestException catch (e) {
      debugPrint('submit_supervisor_registration failed: ${e.message}');
      throw RegistrationSubmitException(
          _friendlyRpcError(e.message));
    } catch (e) {
      debugPrint('submit_supervisor_registration failed: $e');
      throw RegistrationSubmitException(
          'Connection error while submitting. Please try again.');
    }
  }

  /// HOD approval. Assigns the HOD-chosen password and optionally binds the
  /// supervisor to a site (and its first active Thavvu Point). Returns the
  /// created account summary.
  Future<Map<String, dynamic>?> approve(String requestId,
      {String? siteId, required String password}) async {
    try {
      final result = await _client.rpc('approve_supervisor_registration',
          params: {
            'p_request_id': requestId,
            'p_site_id': siteId ?? '',
            'p_password': password,
          });
      return _asMap(result);
    } catch (e) {
      debugPrint('approve_supervisor_registration failed: $e');
      return null;
    }
  }

  /// HOD rejection with an optional reason.
  Future<bool> reject(String requestId, {String? reason}) async {
    try {
      final result = await _client.rpc('reject_supervisor_registration',
          params: {
            'p_request_id': requestId,
            'p_reason': reason ?? '',
          });
      return result == true;
    } catch (e) {
      debugPrint('reject_supervisor_registration failed: $e');
      return false;
    }
  }

  /// Active sites for the approval site picker (RLS allows HOD reads).
  Future<List<RegistrationSiteOption>> fetchSites() async {
    try {
      final response = await _client
          .from('sites')
          .select('id, name, place')
          .eq('status', 'active')
          .order('name', ascending: true);
      return (response as List)
          .map((row) => RegistrationSiteOption.fromJson(
              Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('fetchRegistrationSites failed: $e');
      return [];
    }
  }

  /// Realtime: refresh the approvals list whenever a request is inserted or
  /// updated (RLS filters delivery to HOD/admin).
  RealtimeChannel watchRequests(void Function() onChanged) {
    return _client
        .channel('public:$_table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel? channel) async {
    if (channel == null) return;
    await _client.removeChannel(channel);
  }

  Map<String, dynamic> _asMap(Object? result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    return const {};
  }

  /// PostgREST wraps RPC RAISE EXCEPTION messages in `{...}` + the message
  /// text; keep only the human-readable part.
  String _friendlyRpcError(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'^\s*\{'), '')
        .replaceAll(RegExp(r'\}\s*$'), '');
    final idx = cleaned.indexOf('ERROR:');
    return idx >= 0 ? cleaned.substring(idx + 6).trim() : cleaned.trim();
  }
}

class RegistrationSubmitException implements Exception {
  final String message;
  RegistrationSubmitException(this.message);

  @override
  String toString() => message;
}
