import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Screen hosting the client-side rPPG (photoplethysmography) heart-rate
/// detection web engine served over a local HTTP server.
class RppgScreen extends StatefulWidget {
  const RppgScreen({super.key});

  @override
  State<RppgScreen> createState() => _RppgScreenState();
}

class _RppgScreenState extends State<RppgScreen> with SingleTickerProviderStateMixin {
  late final InAppLocalhostServer _localhostServer;
  InAppWebViewController? _webViewController;
  bool _isServerRunning = false;
  bool _isLoading = true;
  double? _liveBpm;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const int _serverPort = 8080;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startLocalServer();
  }

  Future<void> _startLocalServer() async {
    _localhostServer = InAppLocalhostServer(
      documentRoot: 'assets/rppg_demo',
      port: _serverPort,
    );

    try {
      await _localhostServer.start();
      if (mounted) {
        setState(() {
          _isServerRunning = true;
        });
      }
    } catch (e) {
      debugPrint('Error starting InAppLocalhostServer: $e');
      if (mounted) {
        setState(() {
          _isServerRunning = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    try {
      _localhostServer.close();
    } catch (e) {
      debugPrint('Error closing InAppLocalhostServer: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate aesthetic for medical vision
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'rPPG Pulse Monitor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Contactless Facial Video Inference',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: 'Reload Camera Feed',
            onPressed: () {
              setState(() {
                _liveBpm = null;
                _isLoading = true;
              });
              _webViewController?.reload();
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                SizedBox(width: 6),
                Text(
                  'ON-DEVICE AI',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // TOP LIVE BPM HUD
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF4D4D),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HEART RATE (BPM)',
                          style: TextStyle(
                            color: Color(0xFFDDD6FE),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _liveBpm != null ? _liveBpm!.toStringAsFixed(1) : '--',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'bpm',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.waves_rounded, color: Colors.white, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          _liveBpm != null ? 'SYNCED' : 'READY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // WEBVIEW EMBED
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (_isServerRunning)
                      InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri('http://localhost:$_serverPort/index.html'),
                        ),
                        initialSettings: InAppWebViewSettings(
                          isInspectable: kDebugMode,
                          mediaPlaybackRequiresUserGesture: false,
                          allowsInlineMediaPlayback: true,
                          javaScriptEnabled: true,
                          cacheEnabled: false,
                          transparentBackground: false,
                          preferredContentMode: UserPreferredContentMode.MOBILE,
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;

                          // Register JavaScript handler to receive live BPM data from main.js
                          controller.addJavaScriptHandler(
                            handlerName: 'onHeartRate',
                            callback: (args) {
                              if (args.isNotEmpty && mounted) {
                                final dynamic rawValue = args[0];
                                final double? parsed = double.tryParse(rawValue.toString());
                                if (parsed != null && parsed > 0) {
                                  setState(() {
                                    _liveBpm = parsed;
                                  });
                                }
                              }
                              return null;
                            },
                          );
                        },
                        onPermissionRequest: (controller, request) async {
                          // Auto-grant camera permission when requested by getUserMedia
                          return PermissionResponse(
                            resources: request.resources,
                            action: PermissionResponseAction.GRANT,
                          );
                        },
                        onLoadStop: (controller, url) {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          debugPrint('WebView load error: ${error.description}');
                        },
                      )
                    else
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                            SizedBox(height: 16),
                            Text(
                              'Starting local rPPG server...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),

                    if (_isLoading && _isServerRunning)
                      Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF8B5CF6),
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading AI Vision & ONNX Models...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Preparing face detection & signal processing',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // BOTTOM HELPFUL GUIDANCE CARD
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFA78BFA), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Center your face in good lighting and remain still. Tap "Start" inside the camera panel to begin live reading.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
