import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/hod_login_gate_service.dart';
import '../theme/app_theme.dart';
import 'hod/hod_main_shell.dart';

/// HOD login owner-approval gate.
///
/// After a successful HOD sign-in the user lands here until the owner
/// approves the login (message sent to the owner's WhatsApp; status is
/// polled from `hod_login_approvals`). Repeat HOD logins with a recent
/// approval skip the screen automatically.
class HodApprovalScreen extends StatefulWidget {
  final String email;
  final bool isDemo;

  const HodApprovalScreen({
    super.key,
    required this.email,
    this.isDemo = false,
  });

  @override
  State<HodApprovalScreen> createState() => _HodApprovalScreenState();
}

class _HodApprovalScreenState extends State<HodApprovalScreen> {
  final _gate = HodLoginGateService();
  HodApprovalRequest? _request;
  bool _loading = true;
  String _statusMessage = '';
  Timer? _pollTimer;
  bool _messaged = false;

  @override
  void initState() {
    super.initState();
    _initGate();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initGate() async {
    try {
      await _loadRequesterProfile();
      final request = await _gate.requestApproval(widget.email);
      if (!mounted) return;
      setState(() {
        _request = request;
        _loading = false;
        _statusMessage = request.isNew
            ? 'Approval request created. Waiting for the owner…'
            : 'Approval request already exists for this account.';
      });
      if (request.isApproved) {
        _proceed();
        return;
      }
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusMessage = 'Could not reach the approval service: $e';
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final token = _request?.token;
      if (token == null || token.isEmpty) return;
      try {
        final status = await _gate.checkStatus(token);
        if (!mounted) return;
        if (status == 'approved') {
          _pollTimer?.cancel();
          setState(() => _statusMessage = 'Approved by owner ✓');
          _proceed();
        }
      } catch (_) {
        // Transient network error — keep polling.
      }
    });
  }

  String _requesterName = '';
  String _requesterPhone = '';

  /// Loads the signed-in HOD's real profile so the approval prompt sent to
  /// the owner (WhatsApp / Telegram) shows name, email and phone.
  Future<void> _loadRequesterProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone')
          .eq('id', user.id)
          .limit(1);
      if (rows.isNotEmpty) {
        _requesterName = rows.first['full_name']?.toString() ?? '';
        _requesterPhone = rows.first['phone']?.toString() ?? '';
      }
    } catch (_) {
      // Non-fatal — the prompt still shows the email.
    }
  }

  Future<void> _requestOwnerApproval() async {
    final request = _request;
    if (request == null || request.token.isEmpty) return;
    // Send the approval prompt to the owner via the Telegram bot Edge
    // Function (the bot token lives as a server secret, never in the app).
    try {
      final response = await Supabase.instance.client.functions
          .invoke('telegram-approval-bot/send', body: {
        'token': request.token,
        'email': widget.email,
        'name': _requesterName,
        'phone': _requesterPhone,
      });
      final data = response.data;
      final ok = data is Map && data['ok'] == true;
      final reason = data is Map ? data['reason']?.toString() : null;
      if (!mounted) return;
      setState(() {
        _messaged = true;
        _statusMessage = ok
            ? 'Approval message sent to the owner on Telegram. Waiting for '
                '"okay send"… this screen checks every 5 seconds.'
            : reason == 'owner_not_started'
                ? 'The owner must open the bot in Telegram and send /start '
                    'once before the first approval can be sent.'
                : 'Could not send the Telegram message (${reason ?? 'error'}). '
                    'Try again, or use the demo approval below.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messaged = true;
        _statusMessage = 'Could not reach the approval bot: $e';
      });
    }
  }

  Future<void> _checkNow() async {
    final token = _request?.token;
    if (token == null || token.isEmpty) return;
    try {
      final status = await _gate.checkStatus(token);
      if (!mounted) return;
      setState(() {
        _statusMessage = status == 'approved'
            ? 'Approved by owner ✓'
            : 'Still waiting — status: $status';
      });
      if (status == 'approved') _proceed();
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Check failed: $e');
    }
  }

  Future<void> _simulateOwnerReply() async {
    final token = _request?.token;
    if (token == null || token.isEmpty) return;
    final ok = await _gate.approveForDemo(token);
    if (!mounted) return;
    setState(() {
      _statusMessage =
          ok ? 'Owner reply "okay" recorded — approved ✓' : 'Approval failed';
    });
    if (ok) _proceed();
  }

  void _proceed() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HodMainShell(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user,
                          color: AppTheme.primary, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Owner Approval Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your HOD login for ${widget.email} needs the owner\'s '
                      'confirmation before you can access the admin app.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Message the owner receives in Telegram',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.infoBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppTheme.info.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Thavvu — HOD login approval requested.\n'
                              'Name: ${_requesterName.isEmpty ? '—' : _requesterName}\n'
                              'Email: ${widget.email}\n'
                              'Phone: ${_requesterPhone.isEmpty ? '—' : _requesterPhone}\n'
                              'Request: ${_request?.token ?? '…'}\n'
                              'Reply "okay send" to approve.',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _messaged ? null : _requestOwnerApproval,
                      icon: Icon(
                          _messaged ? Icons.check_circle : Icons.send,
                          size: 20),
                      label: Text(
                        _messaged
                            ? 'Request sent — waiting for owner'
                            : 'Send approval via Telegram bot',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: AppTheme.primary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _checkNow,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Check approval status',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (widget.isDemo) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.warning.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Demo mode',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.warning)),
                            const SizedBox(height: 4),
                            const Text(
                              'Production receives the owner\'s Telegram reply '
                              'via the bot webhook. For the demo, tap the '
                              'button to record the owner\'s "okay" reply now.',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.warning,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                onPressed: _simulateOwnerReply,
                                icon: const Icon(Icons.mark_email_read,
                                    size: 18),
                                label: const Text(
                                    'Demo: owner replied "okay" (approve)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_statusMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.info),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel login',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
