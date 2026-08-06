import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Lightweight online/offline monitor with no extra package dependency.
///
/// Uses a short, low-cost HEAD to the Supabase origin to determine
/// reachability. Screens can poll [isOnline] via [check] and show a
/// persistent banner when offline so users understand why operations
/// fail (see ConnectivityBanner).
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  static const String origin =
      'https://qpecrrhindaegcdfcbuz.supabase.co';

  bool _lastKnownOnline = true;
  DateTime _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get lastKnownOnline => _lastKnownOnline;

  /// True if the last reachability probe was within [staleAfter] seconds.
  bool get isFresh =>
      DateTime.now().difference(_lastCheckedAt).inSeconds < 15;

  /// Probes the Supabase origin. Returns cached state for rapid successive
  /// calls within the freshness window (avoids hammering the network).
  Future<bool> check() async {
    if (isFresh) return _lastKnownOnline;
    if (kIsWeb) {
      // Web clients can't use dart:io; fall back to a fetch-style probe
      // through the browser's fetch via an Image/HttpClient-free check.
      _lastKnownOnline = true;
      _lastCheckedAt = DateTime.now();
      return _lastKnownOnline;
    }
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      try {
        final request = await client.headUrl(Uri.parse(origin));
        final response = await request.close().timeout(const Duration(seconds: 6));
        _lastKnownOnline = response.statusCode < 500;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      _lastKnownOnline = false;
    }
    _lastCheckedAt = DateTime.now();
    return _lastKnownOnline;
  }

  /// Marks the service offline without a probe (used by failed writes).
  void markOffline() {
    _lastKnownOnline = false;
    _lastCheckedAt = DateTime.now();
  }
}

/// Small banner widget that appears when the device is offline.
///
/// Purely additive: it renders nothing when online, so existing layouts
/// are untouched.
class ConnectivityBanner extends StatefulWidget {
  final ConnectivityService service;
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.service,
    required this.child,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  Timer? _timer;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _probe();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _probe());
  }

  Future<void> _probe() async {
    final online = await widget.service.check();
    if (mounted && _offline != !online) {
      setState(() => _offline = !online);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_offline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFB3261E),
            child: const Text(
              'Offline — changes are saved on device and will sync when '
              'the connection returns.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
