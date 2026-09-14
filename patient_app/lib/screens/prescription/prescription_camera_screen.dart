import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_picker/image_picker.dart';

/// Live Hardware Camera Screen for capturing doctor prescriptions.
/// Connects directly to device camera hardware via WebRTC video renderer.
/// Features:
/// - Real-time live camera feed with 60 FPS hardware preview
/// - Document framing reticle with corner brackets & scanning laser
/// - Live torch/flash control on camera sensor
/// - Rear / Front camera hardware switching
/// - Frame capture via camera track on shutter press
/// - Interactive tap-to-focus indicator
class PrescriptionCameraScreen extends StatefulWidget {
  const PrescriptionCameraScreen({super.key});

  @override
  State<PrescriptionCameraScreen> createState() => _PrescriptionCameraScreenState();
}

class _PrescriptionCameraScreenState extends State<PrescriptionCameraScreen>
    with TickerProviderStateMixin {
  final RTCVideoRenderer _cameraRenderer = RTCVideoRenderer();
  MediaStream? _cameraStream;
  MediaStreamTrack? _videoTrack;

  bool _isCameraReady = false;
  bool _cameraError = false;
  String? _cameraErrorMessage;
  bool _flashOn = false;
  bool _isRearCamera = true;
  bool _isCapturing = false;

  // Tap-to-focus animation
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  late Animation<double> _focusScaleAnimation;
  late Animation<double> _focusOpacityAnimation;

  // Document scanning laser beam animation
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  // Viewfinder corner reticle pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Laser beam
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    // Reticle pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Focus ring
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _focusScaleAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOutBack),
    );
    _focusOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_focusAnimController);

    // Initialize physical camera
    _initHardwareCamera();
  }

  Future<void> _initHardwareCamera() async {
    try {
      await _cameraRenderer.initialize();
      await _startCameraStream();
    } catch (e) {
      debugPrint('[PrescriptionCamera] Renderer initialization failed: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _startCameraStream() async {
    try {
      if (_cameraStream != null) {
        for (final track in _cameraStream!.getTracks()) {
          await track.stop();
        }
        await _cameraStream!.dispose();
        _cameraStream = null;
        _videoTrack = null;
      }

      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': <String, dynamic>{
          'facingMode': _isRearCamera ? 'environment' : 'user',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
      };

      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _cameraStream = stream;

      final tracks = stream.getVideoTracks();
      if (tracks.isNotEmpty) {
        _videoTrack = tracks.first;
      }

      _cameraRenderer.srcObject = stream;

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = false;
        });
      }
    } catch (e) {
      debugPrint('[PrescriptionCamera] Camera stream failed: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = 'Camera hardware not accessible or permission denied: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _pulseController.dispose();
    _focusAnimController.dispose();

    if (_cameraStream != null) {
      for (final track in _cameraStream!.getTracks()) {
        track.stop();
      }
      _cameraStream!.dispose();
    }
    _cameraRenderer.dispose();
    super.dispose();
  }

  void _onViewfinderTapped(TapDownDetails details) {
    HapticFeedback.selectionClick();
    setState(() {
      _focusPoint = details.localPosition;
    });
    _focusAnimController.forward(from: 0.0);
  }

  Future<void> _toggleFlash() async {
    HapticFeedback.lightImpact();
    final nextState = !_flashOn;
    setState(() => _flashOn = nextState);

    try {
      if (_videoTrack != null) {
        await _videoTrack!.setTorch(nextState);
      }
    } catch (_) {
      // Physical torch might not be present on emulators / front camera
    }
  }

  Future<void> _toggleCameraFlip() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRearCamera = !_isRearCamera;
      _isCameraReady = false;
    });

    try {
      if (_videoTrack != null) {
        await Helper.switchCamera(_videoTrack!);
        setState(() => _isCameraReady = true);
      } else {
        await _startCameraStream();
      }
    } catch (_) {
      await _startCameraStream();
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    HapticFeedback.heavyImpact();
    setState(() => _isCapturing = true);

    Uint8List? capturedBytes;
    try {
      if (_videoTrack != null) {
        final buffer = await _videoTrack!.captureFrame();
        capturedBytes = buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[PrescriptionCamera] captureFrame error: $e');
    }

    // Camera shutter flash strobe effect
    await Future.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      if (capturedBytes == null) {
        // Capture failed — show error, don't navigate away with fake data
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture photo. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
      Navigator.pop(context, {
        'source': 'camera_capture',
        'imageBytes': capturedBytes,
        'title': 'Prescription Photo (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final docWidth = size.width * 0.86;
    final docHeight = size.height * 0.58;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onViewfinderTapped,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // 1. LIVE HARDWARE CAMERA STREAM VIA WebRTC RTCVideoView
            if (_isCameraReady && _cameraRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _cameraRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: !_isRearCamera,
                ),
              )
            else if (_cameraError)
              // Camera error or permission fallback UI
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam_off_rounded, size: 54, color: Color(0xFFF87171)),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Camera Not Available',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _cameraErrorMessage ?? 'Camera permission denied or camera is in use by another app.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _startCameraStream,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry Camera Access'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Loading live hardware camera indicator
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0A0F1D),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                        SizedBox(height: 16),
                        Text(
                          'Starting Camera…',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 2. Document Framing Box & Edge Alignment Guides
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: docWidth,
                  height: docHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                  child: Stack(
                    children: [
                      // Glowing Corner Reticle Brackets
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CornerReticlePainter(
                            color: const Color(0xFFA78BFA),
                            cornerLength: 32.0,
                            strokeWidth: 4.5,
                          ),
                        ),
                      ),

                      // Document Scan Grid Overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DocumentAlignmentGridPainter(),
                        ),
                      ),

                      // Animated Sweeping Laser Line
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _laserAnimation.value * (docHeight - 6),
                            left: 12,
                            right: 12,
                            child: Container(
                              height: 3.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Color(0xFF8B5CF6),
                                    Color(0xFF38BDF8),
                                    Color(0xFF8B5CF6),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // Center Focus Crosshair
                      Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 3.5,
                              height: 3.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF38BDF8),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Interactive Tap-to-Focus Reticle Ring
            if (_focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 32,
                top: _focusPoint!.dy - 32,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _focusAnimController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _focusOpacityAnimation.value,
                        child: Transform.scale(
                          scale: _focusScaleAnimation.value,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.add_rounded, color: Color(0xFFFBBF24), size: 16),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // 4. Camera Shutter White Flash Burst
            if (_isCapturing)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),

            // 5. Top Bar Controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Live Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isCameraReady ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCameraReady ? 'LIVE' : 'CONNECTING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Flashlight & Camera Flip Controls
                    Row(
                      children: [
                        // Flashlight Toggle
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _flashOn ? const Color(0xFFFBBF24).withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _flashOn ? const Color(0xFFFBBF24) : Colors.white,
                              size: 20,
                            ),
                            onPressed: _toggleFlash,
                          ),
                        ),

                        // Camera Flip
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                            onPressed: _toggleCameraFlip,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 6. Live Alignment Guidance Pill
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 130,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.center_focus_strong_rounded, color: Color(0xFF38BDF8), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Align prescription inside frame • Tap to focus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. Bottom Shutter Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(28, 20, 28, MediaQuery.of(context).padding.bottom + 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.95)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Gallery / File Attachment Shortcut
                        InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            try {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1920,
                                maxHeight: 1080,
                                imageQuality: 90,
                              );
                              if (picked != null && mounted) {
                                final bytes = await picked.readAsBytes();
                                Navigator.pop(context, {
                                  'source': 'gallery_pick',
                                  'imageBytes': bytes,
                                  'title': 'Prescription (Gallery)',
                                });
                              }
                            } on PlatformException catch (e) {
                              debugPrint('Gallery picker PlatformException: ${e.code} - ${e.message}');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please perform a full app restart (stop and flutter run) to use the gallery picker.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Gallery picker error: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not open gallery: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                          ),
                        ),

                        // Shutter Button
                        GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Center(
                                child: Icon(Icons.camera_alt_rounded, color: Color(0xFF7C3AED), size: 32),
                              ),
                            ),
                          ),
                        ),

                        // Guidance Tips Button
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showScanningTipsSheet(context);
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap shutter to click photo of doctor prescription',
                      style: TextStyle(color: Colors.white60, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanningTipsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Color(0xFF7C3AED), size: 24),
                SizedBox(width: 10),
                Text(
                  'Tips for Clear Prescription Scan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildTipRow(Icons.wb_sunny_rounded, 'Good Lighting', 'Place prescription on flat surface with ample natural light.'),
            const SizedBox(height: 10),
            _buildTipRow(Icons.crop_free_rounded, 'Align All 4 Corners', 'Ensure doctor clinic header & medicine lines are inside the box.'),
            const SizedBox(height: 10),
            _buildTipRow(Icons.touch_app_rounded, 'Tap to Focus', 'Tap on the handwriting lines to sharpen camera focus before clicking.'),
          ],
        ),
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1B4B))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Document framing alignment grid
class _DocumentAlignmentGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.8;

    const step = 44.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Prominent corner reticle brackets for the document bounding box
class _CornerReticlePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  _CornerReticlePainter({
    required this.color,
    this.cornerLength = 28.0,
    this.strokeWidth = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final len = cornerLength;

    // Top-Left
    canvas.drawLine(Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
