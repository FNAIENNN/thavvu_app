// lib/screens/face_capture_screen.dart
//
// Professional in-app face capture screen for both enrollment and matching.
// Uses ImagePicker (camera) with an animated overlay UI — no third-party
// camera package needed. The overlay communicates the flow state clearly
// so the user always knows what step they are on.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/face_signature_service.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// The mode in which [FaceCaptureScreen] is opened.
enum FaceCaptureMode {
  /// Enroll a worker: capture → compute signature → return it.
  enroll,

  /// Match check-in: capture → match → confirm → return match.
  checkIn,

  /// Match check-out: capture → match → confirm → return match.
  checkOut,
}

/// Returned when mode == [FaceCaptureMode.enroll].
class FaceEnrollResult {
  final String signature;
  final Uint8List imageBytes;
  const FaceEnrollResult({required this.signature, required this.imageBytes});
}

/// Returned when mode == [FaceCaptureMode.checkIn] or [checkOut].
class FaceMatchResult {
  final String workerId;
  final String workerName;
  final String department;
  final int distance;
  final Uint8List imageBytes;
  const FaceMatchResult({
    required this.workerId,
    required this.workerName,
    required this.department,
    required this.distance,
    required this.imageBytes,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// A full-screen professional face capture UI.
///
/// Usage — enrollment:
/// ```dart
/// final result = await Navigator.push<FaceEnrollResult>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => FaceCaptureScreen.enroll(workerName: worker.name),
///   ),
/// );
/// ```
///
/// Usage — check-in matching:
/// ```dart
/// final result = await Navigator.push<FaceMatchResult>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => FaceCaptureScreen.checkIn(
///       enrolledSignatures: {'workerId': 'hexSig', ...},
///       workerProfiles: {'workerId': ('Name', 'Dept')},
///     ),
///   ),
/// );
/// ```
class FaceCaptureScreen extends StatefulWidget {
  final FaceCaptureMode mode;
  final String? workerNameHint; // shown for enroll mode
  final Map<String, String> enrolledSignatures; // workerId → hex sig
  final Map<String, (String, String)> workerProfiles; // workerId → (name, dept)

  const FaceCaptureScreen._({
    required this.mode,
    this.workerNameHint,
    required this.enrolledSignatures,
    required this.workerProfiles,
  });

  factory FaceCaptureScreen.enroll({String? workerName}) {
    return FaceCaptureScreen._(
      mode: FaceCaptureMode.enroll,
      workerNameHint: workerName,
      enrolledSignatures: const {},
      workerProfiles: const {},
    );
  }

  factory FaceCaptureScreen.checkIn({
    required Map<String, String> enrolledSignatures,
    required Map<String, (String, String)> workerProfiles,
  }) {
    return FaceCaptureScreen._(
      mode: FaceCaptureMode.checkIn,
      enrolledSignatures: enrolledSignatures,
      workerProfiles: workerProfiles,
    );
  }

  factory FaceCaptureScreen.checkOut({
    required Map<String, String> enrolledSignatures,
    required Map<String, (String, String)> workerProfiles,
  }) {
    return FaceCaptureScreen._(
      mode: FaceCaptureMode.checkOut,
      enrolledSignatures: enrolledSignatures,
      workerProfiles: workerProfiles,
    );
  }

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

// ---------------------------------------------------------------------------
// Flow steps
// ---------------------------------------------------------------------------

enum _Step {
  ready, // waiting for user to tap Capture
  capturing, // ImagePicker is open / processing
  processing, // computing hash / matching
  matchFound, // a match was found — awaiting confirm/retry/notMe
  noMatch, // no match above threshold
  enrolled, // enrollment succeeded
  failed, // image too small or unreadable
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.ready;
  Uint8List? _capturedBytes;

  // Match result (check-in/out modes)
  String? _matchedWorkerId;
  String? _matchedWorkerName;
  String? _matchedWorkerDept;
  int _matchDistance = 0;

  // Enrollment result
  String? _enrolledSignature;

  // Animations
  late final AnimationController _scanController;
  late final AnimationController _pulseController;
  late final Animation<double> _scanAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step machine
  // ---------------------------------------------------------------------------

  Future<void> _onCaptureTapped() async {
    if (_step == _Step.capturing || _step == _Step.processing) return;

    setState(() => _step = _Step.capturing);

    XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );
    } catch (_) {
      photo = null;
    }

    if (!mounted) return;

    if (photo == null) {
      // User cancelled
      setState(() => _step = _Step.ready);
      return;
    }

    setState(() => _step = _Step.processing);

    final bytes = await photo.readAsBytes();

    if (!mounted) return;

    if (widget.mode == FaceCaptureMode.enroll) {
      _handleEnrollment(bytes);
    } else {
      _handleMatching(bytes);
    }
  }

  void _handleEnrollment(Uint8List bytes) {
    final sig = FaceSignatureService.computeSignature(bytes);
    if (sig == null) {
      setState(() {
        _step = _Step.failed;
        _capturedBytes = bytes;
      });
      return;
    }
    setState(() {
      _step = _Step.enrolled;
      _capturedBytes = bytes;
      _enrolledSignature = sig;
    });
  }

  void _handleMatching(Uint8List bytes) {
    final probe = FaceSignatureService.computeSignature(bytes);
    if (probe == null) {
      setState(() {
        _step = _Step.failed;
        _capturedBytes = bytes;
      });
      return;
    }

    final match =
        FaceSignatureService.bestMatch(probe, widget.enrolledSignatures);
    if (match == null) {
      setState(() {
        _step = _Step.noMatch;
        _capturedBytes = bytes;
      });
      return;
    }

    final profile = widget.workerProfiles[match.workerId];
    setState(() {
      _step = _Step.matchFound;
      _capturedBytes = bytes;
      _matchedWorkerId = match.workerId;
      _matchedWorkerName = profile?.$1 ?? 'Unknown Worker';
      _matchedWorkerDept = profile?.$2 ?? '';
      _matchDistance = match.distance;
    });
  }

  void _onConfirmMatch() {
    if (!mounted) return;
    Navigator.of(context).pop(FaceMatchResult(
      workerId: _matchedWorkerId!,
      workerName: _matchedWorkerName!,
      department: _matchedWorkerDept!,
      distance: _matchDistance,
      imageBytes: _capturedBytes!,
    ));
  }

  void _onConfirmEnrollment() {
    if (!mounted) return;
    Navigator.of(context).pop(FaceEnrollResult(
      signature: _enrolledSignature!,
      imageBytes: _capturedBytes!,
    ));
  }

  void _onRetry() {
    setState(() {
      _step = _Step.ready;
      _capturedBytes = null;
      _matchedWorkerId = null;
      _enrolledSignature = null;
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepIndicator(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String title;
    final Color accent;
    switch (widget.mode) {
      case FaceCaptureMode.enroll:
        title = 'Face Enrollment';
        accent = AppTheme.warning;
        break;
      case FaceCaptureMode.checkIn:
        title = 'Face Check-In';
        accent = AppTheme.success;
        break;
      case FaceCaptureMode.checkOut:
        title = 'Face Check-Out';
        accent = AppTheme.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white70, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                if (widget.workerNameHint != null)
                  Text(
                    widget.workerNameHint!,
                    style: TextStyle(
                      fontSize: 12,
                      color: accent.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.mode == FaceCaptureMode.enroll
                      ? Icons.face_retouching_natural
                      : Icons.face_unlock_outlined,
                  color: accent,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.mode == FaceCaptureMode.enroll ? 'Enroll' : 'Match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4-step progress indicator
  Widget _buildStepIndicator() {
    final steps = widget.mode == FaceCaptureMode.enroll
        ? ['Place Face', 'Capture', 'Processing', 'Enrolled']
        : ['Place Face', 'Capture', 'Matching', 'Confirm'];

    int activeStep;
    switch (_step) {
      case _Step.ready:
        activeStep = 0;
        break;
      case _Step.capturing:
        activeStep = 1;
        break;
      case _Step.processing:
        activeStep = 2;
        break;
      case _Step.matchFound:
      case _Step.enrolled:
        activeStep = 3;
        break;
      default:
        activeStep = 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isDone = i < activeStep;
          final isActive = i == activeStep;
          final stepColor = isActive || isDone ? AppTheme.primary : Colors.white24;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isActive ? 28 : 22,
                        height: isActive ? 28 : 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppTheme.success
                              : isActive
                                  ? AppTheme.primary
                                  : Colors.white12,
                          border: Border.all(
                            color: stepColor,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 13)
                              : isActive
                                  ? _step == _Step.processing ||
                                          _step == _Step.capturing
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                  : Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: isActive || isDone
                              ? Colors.white70
                              : Colors.white30,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 20,
                    height: 1,
                    color: i < activeStep ? AppTheme.success : Colors.white12,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case _Step.ready:
        return _buildReadyState();
      case _Step.capturing:
        return _buildCapturingState();
      case _Step.processing:
        return _buildProcessingState();
      case _Step.matchFound:
        return _buildMatchFoundState();
      case _Step.noMatch:
        return _buildNoMatchState();
      case _Step.enrolled:
        return _buildEnrolledState();
      case _Step.failed:
        return _buildFailedState();
    }
  }

  // Ready: animated oval face guide + Capture button
  Widget _buildReadyState() {
    final modeColor = widget.mode == FaceCaptureMode.enroll
        ? AppTheme.warning
        : AppTheme.success;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFaceGuideOval(modeColor),
                const SizedBox(height: 28),
                Text(
                  widget.mode == FaceCaptureMode.enroll
                      ? 'Position the worker\'s face\nwithin the oval frame'
                      : 'Position your face\nclearly within the frame',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Good lighting • Front-facing • Stable position',
                  style: TextStyle(
                    color: modeColor.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTipsRow(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onCaptureTapped,
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: Text(
                    widget.mode == FaceCaptureMode.enroll
                        ? 'Open Camera to Enroll'
                        : 'Open Camera to Scan',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: modeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaceGuideOval(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 220,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(110),
              border: Border.all(
                  color: color.withValues(alpha: 0.2), width: 12),
            ),
          ),
          // Main oval frame
          Container(
            width: 200,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: color, width: 2.5),
              color: color.withValues(alpha: 0.04),
            ),
          ),
          // Animated scan line
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, _) {
              final top = _scanAnimation.value * 220;
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  width: 200,
                  height: 260,
                  child: Stack(
                    children: [
                      Positioned(
                        top: top,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              color.withValues(alpha: 0.8),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Face icon placeholder
          Icon(
            Icons.face_outlined,
            size: 80,
            color: color.withValues(alpha: 0.25),
          ),
          // Corner brackets
          ..._buildCornerBrackets(color),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBrackets(Color color) {
    const size = 24.0;
    const stroke = 3.0;
    const offset = 0.0;

    List<Widget> brackets = [];
    final positions = [
      (-88.0, -118.0, 0.0, 0.0), // top-left
      (88.0 - size, -118.0, 0.0, 0.0), // top-right  
      (-88.0, 118.0 - size, 0.0, 0.0), // bottom-left
      (88.0 - size, 118.0 - size, 0.0, 0.0), // bottom-right
    ];

    for (var i = 0; i < 4; i++) {
      final (dx, dy, _, _) = positions[i];
      final isLeft = i % 2 == 0;
      final isTop = i < 2;

      brackets.add(
        Positioned(
          left: 100 + dx + offset,
          top: 130 + dy + offset,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CornerBracketPainter(
                color: color,
                strokeWidth: stroke,
                isLeft: isLeft,
                isTop: isTop,
              ),
            ),
          ),
        ),
      );
    }
    return brackets;
  }

  Widget _buildTipsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _tip(Icons.wb_sunny_outlined, 'Good\nLighting'),
        _tip(Icons.face_retouching_natural, 'Front\nFacing'),
        _tip(Icons.do_not_touch_rounded, 'No\nGlasses'),
      ],
    );
  }

  Widget _tip(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 10, color: Colors.white38, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildCapturingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Opening Camera...',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Ready your front camera',
              style: TextStyle(
                  color: AppTheme.primary.withValues(alpha: 0.6),
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 4,
                ),
              ),
              Icon(
                widget.mode == FaceCaptureMode.enroll
                    ? Icons.face_retouching_natural
                    : Icons.manage_search_rounded,
                color: AppTheme.primary,
                size: 44,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            widget.mode == FaceCaptureMode.enroll
                ? 'Computing Face Signature...'
                : 'Matching Face...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.mode == FaceCaptureMode.enroll
                ? 'Generating 64-bit perceptual hash'
                : 'Searching enrolled workers',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchFoundState() {
    final confidence = FaceSignatureService.confidenceLabel(_matchDistance);
    final confidenceColor = _matchDistance <= 4
        ? AppTheme.success
        : _matchDistance <= 8
            ? const Color(0xFF4CAF50)
            : AppTheme.warning;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Match found icon with pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success.withValues(alpha: 0.15),
                          border: Border.all(
                              color: AppTheme.success, width: 2.5),
                        ),
                        child: const Icon(
                          Icons.how_to_reg_rounded,
                          color: AppTheme.success,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Face Match Found',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _matchedWorkerName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _matchedWorkerDept ?? '',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: confidenceColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: confidenceColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          confidence,
                          style: TextStyle(
                            color: confidenceColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(distance: $_matchDistance/64)',
                          style: TextStyle(
                            color: confidenceColor.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildBottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onConfirmMatch,
                  icon: Icon(
                    widget.mode == FaceCaptureMode.checkIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    size: 22,
                  ),
                  label: Text(
                    widget.mode == FaceCaptureMode.checkIn
                        ? 'Confirm Check-In'
                        : 'Confirm Check-Out',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warning,
                        side: const BorderSide(color: AppTheme.warning),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Not Me'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoMatchState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    border: Border.all(color: AppTheme.warning, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.face_outlined,
                    color: AppTheme.warning,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No Match Found',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The face could not be matched\nagainst any enrolled worker.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Column(
                    children: [
                      _Tip(icon: Icons.wb_sunny_outlined,
                          text: 'Ensure good lighting'),
                      SizedBox(height: 6),
                      _Tip(icon: Icons.face_retouching_natural,
                          text: 'Face the camera directly'),
                      SizedBox(height: 6),
                      _Tip(icon: Icons.assignment_ind_outlined,
                          text: 'Worker must be enrolled first'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onRetry,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text('Try Again',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Use Manual Entry Instead',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnrolledState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        border:
                            Border.all(color: AppTheme.warning, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.how_to_reg_rounded,
                        color: AppTheme.warning,
                        size: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Face Signature Ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.workerNameHint != null
                      ? '${widget.workerNameHint} — enrolled successfully'
                      : 'Enrollment complete',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint,
                          color: AppTheme.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Sig: ${_enrolledSignature?.substring(0, 8)}...',
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onConfirmEnrollment,
                  icon: const Icon(Icons.save_alt_rounded, size: 22),
                  label: const Text('Save Face Signature',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retake Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFailedState() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.danger.withValues(alpha: 0.15),
                    border: Border.all(color: AppTheme.danger, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.danger,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Image Quality Issue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The photo was too small or unclear\nfor face signature processing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomPanel(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onRetry,
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: const Text('Retake Photo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isLeft;
  final bool isTop;

  const _CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.isLeft,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;

    final xEnd = isLeft ? size.width * 0.5 : size.width * 0.5;
    final yEnd = isTop ? size.height * 0.5 : size.height * 0.5;

    canvas.drawLine(Offset(x, y), Offset(xEnd, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, yEnd), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
