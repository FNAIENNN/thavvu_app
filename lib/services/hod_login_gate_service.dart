import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/web_launcher.dart';

/// Owner-approval gate for HOD logins (enterprise guard rail).
///
/// Flow:
///   1. A HOD signs in with valid Supabase credentials.
///   2. The app calls [requestApproval] — the database creates (or reuses)
///      a `hod_login_approvals` row with a secret token and status
///      `pending` (an `approved` row younger than 24h lets the HOD straight
///      through on repeat logins).
///   3. [openOwnerWhatsApp] composes a WhatsApp message to the owner
///      (default +91 7207507251) with the approval text + token pre-filled.
///   4. The HOD screen polls [checkStatus]; when the owner replies
///      "okay send" the production WhatsApp Business webhook calls
///      `approve_hod_login_request(token, 'okay')` — the demo HOD screen
///      has a clearly-labeled simulator that calls the same RPC.
///   5. Once status is `approved` the HOD shell opens.
class HodLoginGateService {
  HodLoginGateService({SupabaseClient? client}) : _providedClient = client;

  /// Lazy so widget tests never touch Supabase until the first call.
  final SupabaseClient? _providedClient;
  late final SupabaseClient _client =
      _providedClient ?? Supabase.instance.client;

  static const String ownerPhone = '7207507251';

  Future<HodApprovalRequest> requestApproval(String email) async {
    final response = await _client
        .rpc('request_hod_approval', params: {'p_email': email});
    return HodApprovalRequest.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<String> checkStatus(String token) async {
    final response = await _client
        .rpc('check_hod_approval', params: {'p_token': token});
    final map = Map<String, dynamic>.from(response as Map);
    return map['status']?.toString() ?? 'unknown';
  }

  /// Demo-only: simulates the owner's WhatsApp reply "okay send" by calling
  /// the same SECURITY DEFINER RPC a production webhook would call.
  Future<bool> approveForDemo(String token) async {
    final ok = await _client
        .rpc('approve_hod_login_request', params: {'p_token': token});
    return ok == true;
  }

  /// Opens WhatsApp with the approval message pre-filled for the owner.
  void openOwnerWhatsApp(String token, String email) {
    final text = 'Thavvu — HOD login approval requested.\n'
        'Email: $email\n'
        'Request: $token\n'
        'Reply "okay send" to approve.';
    openUrlInBrowser(
      'https://wa.me/91$ownerPhone?text=${Uri.encodeComponent(text)}',
    );
  }
}

/// A row from `hod_login_approvals` returned by `request_hod_approval`.
class HodApprovalRequest {
  final String id;
  final String token;
  final String status; // pending | approved | rejected
  final bool isNew;

  const HodApprovalRequest({
    required this.id,
    required this.token,
    required this.status,
    required this.isNew,
  });

  factory HodApprovalRequest.fromJson(Map<String, dynamic> json) {
    return HodApprovalRequest(
      id: json['id']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      isNew: json['new'] == true,
    );
  }

  bool get isApproved => status == 'approved';
}
