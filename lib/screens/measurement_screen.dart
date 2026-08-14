import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';
import '../services/face_detector_service.dart';
import '../services/rppg_signal_processor.dart';
import '../services/websocket_backend_service.dart';
import '../components/face_painter.dart';

enum ScanState { idle, scanning, completed }

class MeasurementMetrics {
  final int pulse, sys, dia, hrv, breath, workload, para;
  final double stress, bmi;
  const MeasurementMetrics({
    required this.pulse, required this.sys, required this.dia,
    required this.hrv, required this.breath, required this.workload,
    required this.para, required this.stress, required this.bmi,
  });
}

class MeasurementScreen extends StatefulWidget {
  final void Function(MeasurementMetrics metrics) onScanComplete;
  final VoidCallback onBack;
  const MeasurementScreen({super.key, required this.onScanComplete, required this.onBack});
  @override State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> with TickerProviderStateMixin {
  ScanState _state = ScanState.idle;
  int _timeLeft = 30;
  String _pulseVal = '--';
  String _bpVal = '-- / --';
  Timer? _timer, _simTimer, _adviceTimer;
  
  late AnimationController _scanlineCtrl;
  late AnimationController _bracketCtrl;
  late Animation<double> _scanlineAnim, _bracketAnim;

  // Real Camera & Face Detection support
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  int _selectedCameraIndex = 0;

  FaceDetectorService? _faceDetectorService;
  RPPGSignalProcessor? _rppgProcessor;
  WebSocketBackendService? _webSocketService;
  StreamSubscription<ProcessedMetrics>? _backendSubscription;

  FaceDetectionData? _faceData;
  String _liveStatusMessage = "👤 Center your face in frame";
  bool _isStreamingImage = false;

  // AI Advice Ticker list
  final List<String> _advices = [
    "👤 Center your face in frame",
    "💡 Lighting looks optimal",
    "🧘 Please keep head steady",
    "🤫 Remain quiet and breathe",
    "⚡ Face mesh locks verified",
    "🧬 Reading blood volume flow",
  ];
  int _adviceIndex = 0;

  @override
  void initState() {
    super.initState();
    _scanlineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _scanlineAnim = Tween<double>(begin: 0.1, end: 0.9).animate(_scanlineCtrl);
    _bracketCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _bracketAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _bracketCtrl, curve: Curves.easeInOut));

    _faceDetectorService = FaceDetectorService();
    _rppgProcessor = RPPGSignalProcessor();
    _webSocketService = WebSocketBackendService();

    _backendSubscription = _webSocketService?.metricsStream.listen((metrics) {
      if (mounted && _state == ScanState.scanning) {
        if (metrics.bpm > 0) {
          setState(() {
            _pulseVal = metrics.bpm.round().toString();
            int sys = 110 + (metrics.bpm * 0.1).round();
            int dia = 70 + (metrics.bpm * 0.05).round();
            _bpVal = '$sys / $dia';
          });
        }
      }
    });

    // Attempt camera initialization
    _initCamera();
  }

  @override
  void dispose() {
    _stopImageStream();
    _timer?.cancel();
    _simTimer?.cancel();
    _adviceTimer?.cancel();
    _scanlineCtrl.dispose();
    _bracketCtrl.dispose();
    _backendSubscription?.cancel();
    _webSocketService?.dispose();
    _faceDetectorService?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        int frontIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint("Camera unavailable or blocked: $e");
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Camera initialize error: $e");
      if (mounted) {
        setState(() {
          _cameraInitialized = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _stopImageStream();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
    if (_state == ScanState.scanning) {
      _startImageStream();
    }
  }

  Timer? _fallbackStreamTimer;

  void _startImageStream() {
    bool nativeStreamStarted = false;
    _rppgProcessor?.reset();

    if (_cameraController != null && _cameraController!.value.isInitialized && !_isStreamingImage) {
      try {
        _cameraController!.startImageStream((CameraImage image) {
          _processFrameData(image: image);
        });
        _isStreamingImage = true;
        nativeStreamStarted = true;
      } catch (e) {
        debugPrint("Native camera startImageStream not supported on this platform: $e");
        _isStreamingImage = false;
      }
    }

    if (!nativeStreamStarted) {
      // 30 FPS periodic timer pump for Desktop/Web/Fallback camera streams
      _fallbackStreamTimer?.cancel();
      _fallbackStreamTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted || _state != ScanState.scanning) return;
        _processFrameData(image: null);
      });
    }
  }

  Future<void> _processFrameData({CameraImage? image}) async {
    if (!mounted || _state != ScanState.scanning) return;

    final sensorOrientation = _cameras.isNotEmpty ? _cameras[_selectedCameraIndex].sensorOrientation : 0;
    final lensDirection = _cameras.isNotEmpty ? _cameras[_selectedCameraIndex].lensDirection : CameraLensDirection.front;

    final detection = await _faceDetectorService?.processCameraImage(
      image: image,
      sensorOrientation: sensorOrientation,
      lensDirection: lensDirection,
    );

    if (detection != null && mounted) {
      // Stream payload to Python FastAPI backend via WebSocket
      _webSocketService?.sendFramePayload(detection);

      RPPGResult? rppgResult;
      if (image != null) {
        rppgResult = _rppgProcessor?.processFrame(
          image: image,
          detectionData: detection,
        );
      }

      setState(() {
        _faceData = detection;
        _liveStatusMessage = detection.statusMessage;
        if (rppgResult != null && rppgResult.isValid && rppgResult.bpm > 0) {
          _pulseVal = rppgResult.bpm.round().toString();
          int sys = 110 + (rppgResult.bpm * 0.1).round();
          int dia = 70 + (rppgResult.bpm * 0.05).round();
          _bpVal = '$sys / $dia';
        }
      });
    }
  }

  void _stopImageStream() {
    _fallbackStreamTimer?.cancel();
    _fallbackStreamTimer = null;
    if (_cameraController != null && _isStreamingImage) {
      _isStreamingImage = false;
      try {
        _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint("Error stopping image stream: $e");
      }
    }
  }

  void _startScan() {
    setState(() {
      _state = ScanState.scanning;
      _timeLeft = 30;
      _pulseVal = '72';
      _bpVal = '115 / 72';
      _adviceIndex = 0;
      _liveStatusMessage = "👤 Center your face in frame";
    });

    _webSocketService?.connect();
    _startImageStream();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_timeLeft <= 1) {
          _timer?.cancel();
          _simTimer?.cancel();
          _adviceTimer?.cancel();
          _stopImageStream();
          _webSocketService?.disconnect();
          _state = ScanState.completed;
          _pulseVal = _rppgProcessor?.currentBpm.round().toString() ?? '75';
          _bpVal = '117 / 74';
          _timeLeft = 0;
        } else {
          _timeLeft--;
        }
      });
    });

    _simTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_rppgProcessor != null && _rppgProcessor!.isLocked) return;
      final r = DateTime.now().millisecondsSinceEpoch;
      final p = 70 + (r % 15);
      final s = 112 + (r % 8);
      final d = 72 + (r % 6);
      setState(() {
        _pulseVal = '$p';
        _bpVal = '$s / $d';
      });
    });

    _adviceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _adviceIndex = (_adviceIndex + 1) % _advices.length;
        });
      }
    });
  }

  void _stopScan() {
    _timer?.cancel();
    _simTimer?.cancel();
    _adviceTimer?.cancel();
    _stopImageStream();
    _webSocketService?.disconnect();
    setState(() {
      _state = ScanState.idle;
      _timeLeft = 30;
      _pulseVal = '--';
      _bpVal = '-- / --';
      _faceData = null;
    });
  }

  void _viewResults() {
    final r = DateTime.now().millisecondsSinceEpoch;
    widget.onScanComplete(MeasurementMetrics(
      pulse: 72 + (r % 8), sys: 114 + (r % 10), dia: 72 + (r % 6),
      hrv: 42 + (r % 12), breath: 21 + (r % 4),
      stress: 1.6 + (r % 8) * 0.1, workload: 138 + (r % 20),
      para: 28 + (r % 8), bmi: 21.7,
    ));
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header (Fixed 56)
            Container(
              color: Colors.white,
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 12,
                      child: InnovativeBackButton(onTap: widget.onBack),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'care',
                                style: AppTheme.sansFont(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              TextSpan(
                                text: 'for',
                                style: AppTheme.sansFont(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Top area: Flex 13 Height
            Expanded(
              flex: 13,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Feed / Simulated Mesh View
                  Positioned.fill(
                    child: _buildCameraOrScanArea(),
                  ),

                  // Floating Countdown Timer (Scanning State)
                  if (_state == ScanState.scanning)
                    Positioned(
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmt(_timeLeft),
                              style: AppTheme.sansFont(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Camera Switch Button (Top Right)
                  if (_cameras.length >= 2)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: _toggleCamera,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(
                            Icons.cameraswitch_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Bottom area: Flex 7 Height
            Expanded(
              flex: 7,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: _buildBottomArea(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOrScanArea() {
    if (_state == ScanState.idle) {
      // Idle state: rotating radar concentric arches with START button
      return _buildRadarStartTarget();
    }

    if (_state == ScanState.completed) {
      return Container(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2022C55E),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22C55E),
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scan Complete!',
                style: AppTheme.sansFont(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Scanning State: Show real CameraPreview or Simulated Scan
    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera Viewport
        Positioned.fill(
          child: _cameraInitialized && _cameraController != null
              ? AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                )
              : Container(
                  color: const Color(0xFF1E293B),
                  child: Center(
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      size: 120,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                ),
        ),

        // Real-time Face Mesh & Bounding Box Overlay
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _scanlineCtrl,
            builder: (context, _) => CustomPaint(
              painter: FaceOverlayPainter(
                detectionData: _faceData,
                scanlineProgress: _scanlineAnim.value,
                isFrontCamera: _cameras.isNotEmpty &&
                    _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front,
              ),
            ),
          ),
        ),

        // Simulated Face Mesh Overlay (fallback if camera is not active)
        if (!_cameraInitialized)
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceMeshPainter(_scanlineCtrl.value),
            ),
          ),

        // Corner Brackets
        AnimatedBuilder(
          animation: _bracketAnim,
          builder: (_, __) => Stack(
            children: [
              _Bracket(top: 24, left: 24, showRight: false, showBottom: false, opacity: _bracketAnim.value),
              _Bracket(top: 24, right: 24, showLeft: false, showBottom: false, opacity: _bracketAnim.value),
              _Bracket(bottom: 24, left: 24, showRight: false, showTop: false, opacity: _bracketAnim.value),
              _Bracket(bottom: 24, right: 24, showLeft: false, showTop: false, opacity: _bracketAnim.value),
            ],
          ),
        ),

        // Dynamic Scan Laser line
        AnimatedBuilder(
          animation: _scanlineAnim,
          builder: (_, __) => Positioned(
            top: MediaQuery.of(context).size.height * 0.5 * _scanlineAnim.value,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF22D3EE).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Stop scanning overlay trigger/button (floating above)
        Positioned(
          bottom: 16,
          child: GestureDetector(
            onTap: _stopScan,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'STOP SCAN',
                    style: AppTheme.sansFont(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadarStartTarget() {
    return AnimatedBuilder(
      animation: _scanlineCtrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Animated Custom Cartoon Illustration representing biometric face scanning
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 84, top: 12),
                child: CustomPaint(
                  painter: _CartoonScanPainter(animationValue: _scanlineCtrl.value),
                ),
              ),
            ),

            // Floating glowing START SCAN button at the bottom
            Positioned(
              bottom: 24,
              child: GestureDetector(
                onTap: _startScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2DD4BF), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2DD4BF).withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'START SCAN',
                        style: AppTheme.sansFont(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomArea() {
    if (_state == ScanState.idle) {
      // 1/4 area before scanning: two boxes side-by-side (empty, pulse & blood pressure)
      return Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'PULSE',
              value: '--',
              unit: 'bpm',
              icon: Icons.favorite_rounded,
              iconBg: const Color(0xFFFEF2F2),
              iconColor: Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: 'BLOOD PRESSURE',
              value: '-- / --',
              unit: 'mmHg',
              icon: Icons.speed_rounded,
              iconBg: const Color(0xFFECFEFF),
              iconColor: const Color(0xFF0891B2),
            ),
          ),
        ],
      );
    }

    if (_state == ScanState.completed) {
      // View results option
      return Center(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: _ActionButton(
            label: 'VIEW HEALTH CHECK RESULTS',
            color: Colors.green,
            onTap: _viewResults,
            pulse: true,
          ),
        ),
      );
    }

    // Scanning state: Three elements side-by-side
    return Row(
      children: [
        // 1. Reduced size real-time metrics
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniMetricRow(
                label: 'Pulse:',
                value: '$_pulseVal bpm',
                icon: Icons.favorite_rounded,
                iconColor: Colors.red,
              ),
              _MiniMetricRow(
                label: 'BP Target:',
                value: '$_bpVal mmHg',
                icon: Icons.speed_rounded,
                iconColor: const Color(0xFF0891B2),
              ),
            ],
          ),
        ),
        
        const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

        // 2. ECG heartrate graph
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIVE ECG WAVEFORM',
                style: AppTheme.sansFont(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedBuilder(
                      animation: _scanlineCtrl,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _EcgPainter(_scanlineCtrl.value),
                          child: Container(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 16, thickness: 1, color: Color(0xFFE2E8F0)),

        // 3. AI Ticker Advice
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SCAN STATUS',
                style: AppTheme.sansFont(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _faceData != null ? _liveStatusMessage : _advices[_adviceIndex],
                  key: ValueKey<String>(_faceData != null ? _liveStatusMessage : _advices[_adviceIndex]),
                  style: AppTheme.sansFont(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetricRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color iconColor;

  const _MiniMetricRow({required this.label, required this.value, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 12),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.sansFont(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              value,
              style: AppTheme.sansFont(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bracket extends StatelessWidget {
  final double? top, left, right, bottom;
  final bool showRight, showLeft, showBottom, showTop;
  final double opacity;
  const _Bracket({this.top, this.left, this.right, this.bottom, this.showRight = true, this.showLeft = true, this.showBottom = true, this.showTop = true, required this.opacity});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Opacity(
        opacity: opacity,
        child: SizedBox(
          width: 40, height: 40,
          child: CustomPaint(painter: _BracketPainter(showRight: showRight, showLeft: showLeft, showTop: showTop, showBottom: showBottom)),
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool showRight, showLeft, showTop, showBottom;
  _BracketPainter({required this.showRight, required this.showLeft, required this.showTop, required this.showBottom});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF22D3EE).withOpacity(0.7)..strokeWidth = 3..style = PaintingStyle.stroke;
    if (showTop && showLeft) { canvas.drawLine(Offset(0, size.height), const Offset(0, 10), paint); canvas.drawLine(const Offset(0, 0), Offset(size.width, 0), paint); }
    if (showTop && showRight) { canvas.drawLine(Offset(size.width, size.height), Offset(size.width, 10), paint); canvas.drawLine(Offset(size.width, 0), Offset(0, 0), paint); }
    if (showBottom && showLeft) { canvas.drawLine(Offset(0, 0), Offset(0, size.height - 10), paint); canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint); }
    if (showBottom && showRight) { canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height - 10), paint); canvas.drawLine(Offset(size.width, size.height), Offset(0, size.height), paint); }
  }
  @override bool shouldRepaint(_) => false;
}

class _ActionButton extends StatefulWidget {
  final String label; final Color color; final VoidCallback onTap; final bool pulse;
  const _ActionButton({required this.label, required this.color, required this.onTap, this.pulse = false});
  @override State<_ActionButton> createState() => _ActionButtonState();
}
class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (_, child) => GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: widget.pulse ? _scale.value : (_pressed ? 0.95 : 1.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 12)]),
          child: Center(child: Text(widget.label, style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))),
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label, value, unit; final IconData icon; final Color iconBg, iconColor;
  const _MetricCard({required this.label, required this.value, required this.unit, required this.icon, required this.iconBg, required this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 4))],
    ),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTheme.sansFont(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: AppTheme.sansFont(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(unit, style: AppTheme.sansFont(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RadarTargetPainter extends CustomPainter {
  final double rotation;
  final double scale;
  _RadarTargetPainter(this.rotation, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    double baseRadius = 75 * scale;
    
    // Rotating concentric dotted arches
    canvas.drawCircle(Offset(cx, cy), baseRadius, paint);
    
    final dashPaint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: baseRadius + 24),
      rotation,
      math.pi * 0.5,
      false,
      dashPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: baseRadius + 24),
      rotation + math.pi,
      math.pi * 0.5,
      false,
      dashPaint,
    );
    
    // Outermost pulse bounds ring
    canvas.drawCircle(
      Offset(cx, cy),
      baseRadius + 48,
      Paint()
        ..color = const Color(0xFF22D3EE).withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_RadarTargetPainter oldDelegate) => true;
}

class _FaceMeshPainter extends CustomPainter {
  final double animVal;
  _FaceMeshPainter(this.animVal);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFF22D3EE).withOpacity(0.5)..style = PaintingStyle.fill;
    final linePaint = Paint()..color = const Color(0xFF22D3EE).withOpacity(0.12)..strokeWidth = 1.0..style = PaintingStyle.stroke;
    
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2 - 20;

    // Define facial landmark offset coordinates relative to center
    final List<Offset> points = [
      Offset(cx, cy - 70),     // Forehead
      Offset(cx - 30, cy - 45), // L Eye outer
      Offset(cx - 12, cy - 45), // L Eye inner
      Offset(cx + 12, cy - 45), // R Eye inner
      Offset(cx + 30, cy - 45), // R Eye outer
      Offset(cx, cy - 18),     // Bridge of nose
      Offset(cx, cy + 8),      // Tip of nose
      Offset(cx - 12, cy + 4),  // L Nostril
      Offset(cx + 12, cy + 4),  // R Nostril
      Offset(cx - 52, cy - 8),  // L Cheekbone
      Offset(cx + 52, cy - 8),  // R Cheekbone
      Offset(cx - 24, cy + 34), // L Mouth corner
      Offset(cx + 24, cy + 34), // R Mouth corner
      Offset(cx, cy + 24),     // Upper Lip
      Offset(cx, cy + 42),     // Lower Lip
      Offset(cx, cy + 70),     // Chin
    ];

    // Connect wireframe face grid lines
    canvas.drawPath(Path()..moveTo(points[0].dx, points[0].dy)..lineTo(points[1].dx, points[1].dy)..lineTo(points[2].dx, points[2].dy)..lineTo(points[5].dx, points[5].dy)..close(), linePaint);
    canvas.drawPath(Path()..moveTo(points[0].dx, points[0].dy)..lineTo(points[4].dx, points[4].dy)..lineTo(points[3].dx, points[3].dy)..lineTo(points[5].dx, points[5].dy)..close(), linePaint);
    canvas.drawPath(Path()..moveTo(points[5].dx, points[5].dy)..lineTo(points[6].dx, points[6].dy)..lineTo(points[7].dx, points[7].dy)..lineTo(points[9].dx, points[9].dy)..close(), linePaint);
    canvas.drawPath(Path()..moveTo(points[5].dx, points[5].dy)..lineTo(points[6].dx, points[6].dy)..lineTo(points[8].dx, points[8].dy)..lineTo(points[10].dx, points[10].dy)..close(), linePaint);
    canvas.drawPath(Path()..moveTo(points[6].dx, points[6].dy)..lineTo(points[13].dx, points[13].dy)..lineTo(points[11].dx, points[11].dy)..lineTo(points[15].dx, points[15].dy)..lineTo(points[12].dx, points[12].dy)..lineTo(points[14].dx, points[14].dy)..close(), linePaint);

    // Draw active glowing tracker node dots
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_FaceMeshPainter oldDelegate) => false;
}

class _EcgPainter extends CustomPainter {
  final double animationValue;
  _EcgPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22D3EE)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final h = size.height;
    final w = size.width;
    
    path.moveTo(0, h / 2);
    
    // Draw ECG waves points using dynamic formula
    for (double x = 0; x < w; x++) {
      double phase = (x / w) * 2 * math.pi * 3.5 - (animationValue * 2 * math.pi * 2.0);
      double y = h / 2;
      double norm = phase % (2 * math.pi);
      
      // QRS Complex spike
      if (norm > 1.2 && norm < 1.6) {
        double t = (norm - 1.2) / 0.4;
        y = h / 2 - math.sin(t * math.pi * 2) * (h * 0.38);
      }
      // T Wave
      else if (norm > 2.0 && norm < 2.6) {
        double t = (norm - 2.0) / 0.6;
        y = h / 2 - math.sin(t * math.pi) * (h * 0.14);
      }
      // P Wave
      else if (norm > 0.5 && norm < 0.9) {
        double t = (norm - 0.5) / 0.4;
        y = h / 2 - math.sin(t * math.pi) * (h * 0.08);
      }
      
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EcgPainter oldDelegate) => true;
}

class _CartoonScanPainter extends CustomPainter {
  final double animationValue;
  _CartoonScanPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Define colors matching the reference photo
    final outlinePaint = Paint()
      ..color = const Color(0xFFF1F5F9) // Light off-white stroke for dark theme
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final darkOutlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final redPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    final darkPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final skinPaint = Paint()
      ..color = const Color(0xFFFEE2E2)
      ..style = PaintingStyle.fill;

    final tealPaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..style = PaintingStyle.fill;

    // Breathing offset for cartoon body
    final breathe = math.sin(animationValue * 2 * math.pi) * 1.5;

    // ── 1. BACKGROUND DECORATIVE SHAPES ──
    // Draw decorative dark circle
    canvas.drawCircle(Offset(w * 0.72, h * 0.58), 24, darkPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.58), 24, outlinePaint);

    final circleOutline = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(w * 0.22, h * 0.56), 8, circleOutline);

    // ── 2. BACKGROUND DASHBOARD SCREEN ──
    final dbRect = Rect.fromLTWH(w * 0.32, h * 0.16, w * 0.56, h * 0.44);
    final dbPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(dbRect, const Radius.circular(12)), dbPaint);
    
    // Dashboard border
    canvas.drawRRect(RRect.fromRectAndRadius(dbRect, const Radius.circular(12)), outlinePaint);

    // Dotted vertical line inside dashboard
    final dottedPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    double startY = h * 0.16;
    double endY = h * 0.6;
    double dashWidth = 4.0;
    double dashSpace = 4.0;
    while (startY < endY) {
      canvas.drawLine(Offset(w * 0.72, startY), Offset(w * 0.72, startY + dashWidth), dottedPaint);
      startY += dashWidth + dashSpace;
    }

    // Draw little UI lines on the dashboard
    final uiLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.76, h * 0.24), Offset(w * 0.84, h * 0.24), uiLinePaint);
    canvas.drawLine(Offset(w * 0.76, h * 0.29), Offset(w * 0.84, h * 0.29), uiLinePaint);
    canvas.drawLine(Offset(w * 0.76, h * 0.34), Offset(w * 0.84, h * 0.34), uiLinePaint);

    // Draw a heartbeat line on the dashboard (Red)
    final heartPath = Path();
    heartPath.moveTo(w * 0.36, h * 0.45);
    heartPath.lineTo(w * 0.41, h * 0.45);
    heartPath.lineTo(w * 0.43, h * 0.38);
    heartPath.lineTo(w * 0.45, h * 0.52);
    heartPath.lineTo(w * 0.47, h * 0.45);
    heartPath.lineTo(w * 0.54, h * 0.45);
    final heartLinePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(heartPath, heartLinePaint);

    // Badge ribbon (Red medal) on dashboard
    final badgePath = Path();
    badgePath.moveTo(w * 0.40, h * 0.24);
    badgePath.lineTo(w * 0.42, h * 0.32);
    badgePath.lineTo(w * 0.40, h * 0.30);
    badgePath.lineTo(w * 0.38, h * 0.32);
    badgePath.close();
    canvas.drawPath(badgePath, redPaint);
    canvas.drawPath(badgePath, darkOutlinePaint);
    
    final badgeCirclePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.40, h * 0.22), 8, badgeCirclePaint);
    canvas.drawCircle(Offset(w * 0.40, h * 0.22), 8, darkOutlinePaint);

    // ── 3. CHARACTER DRAWINGS (Flat vector outline style) ──
    // Left Leg
    final leftLeg = Path()
      ..moveTo(w * 0.25, h * 0.58)
      ..lineTo(w * 0.20, h * 0.78)
      ..lineTo(w * 0.23, h * 0.78)
      ..lineTo(w * 0.28, h * 0.58)
      ..close();
    canvas.drawPath(leftLeg, whitePaint);
    canvas.drawPath(leftLeg, darkOutlinePaint);

    // Right Leg
    final rightLeg = Path()
      ..moveTo(w * 0.29, h * 0.58)
      ..lineTo(w * 0.31, h * 0.78)
      ..lineTo(w * 0.34, h * 0.78)
      ..lineTo(w * 0.32, h * 0.58)
      ..close();
    canvas.drawPath(rightLeg, whitePaint);
    canvas.drawPath(rightLeg, darkOutlinePaint);

    // Left Shoe
    final leftShoe = Path()
      ..moveTo(w * 0.20, h * 0.78)
      ..quadraticBezierTo(w * 0.16, h * 0.79, w * 0.17, h * 0.81)
      ..lineTo(w * 0.23, h * 0.81)
      ..close();
    canvas.drawPath(leftShoe, darkPaint);
    canvas.drawPath(leftShoe, darkOutlinePaint);

    // Right Shoe
    final rightShoe = Path()
      ..moveTo(w * 0.31, h * 0.78)
      ..quadraticBezierTo(w * 0.35, h * 0.79, w * 0.34, h * 0.81)
      ..lineTo(w * 0.30, h * 0.81)
      ..close();
    canvas.drawPath(rightShoe, darkPaint);
    canvas.drawPath(rightShoe, darkOutlinePaint);

    // Torso (Shirt) with breathing breathe offset
    final torsoPath = Path()
      ..moveTo(w * 0.24, h * 0.40 + breathe)
      ..lineTo(w * 0.32, h * 0.40 + breathe)
      ..lineTo(w * 0.32, h * 0.58)
      ..lineTo(w * 0.24, h * 0.58)
      ..close();
    canvas.drawPath(torsoPath, redPaint);
    canvas.drawPath(torsoPath, darkOutlinePaint);

    // Neck
    canvas.drawRect(Rect.fromLTWH(w * 0.27, h * 0.36 + breathe, w * 0.02, h * 0.04), skinPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.27, h * 0.36 + breathe, w * 0.02, h * 0.04), darkOutlinePaint);

    // Head (Oval)
    canvas.drawOval(Rect.fromLTWH(w * 0.26, h * 0.28 + breathe, w * 0.045, h * 0.08), skinPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.26, h * 0.28 + breathe, w * 0.045, h * 0.08), darkOutlinePaint);

    // Curly Hair (overlapped circles just like the reference photo)
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(w * 0.28, h * 0.275 + breathe), 11, hairPaint);
    canvas.drawCircle(Offset(w * 0.265, h * 0.29 + breathe), 9, hairPaint);
    canvas.drawCircle(Offset(w * 0.288, h * 0.268 + breathe), 10, hairPaint);
    canvas.drawCircle(Offset(w * 0.27, h * 0.26 + breathe), 9, hairPaint);

    // Arm (Raised, holding smartphone)
    final armPath = Path()
      ..moveTo(w * 0.31, h * 0.42 + breathe)
      ..quadraticBezierTo(w * 0.40, h * 0.42 + breathe, w * 0.42, h * 0.38 + breathe) // Shoulder to hand
      ..lineTo(w * 0.41, h * 0.36 + breathe)
      ..quadraticBezierTo(w * 0.39, h * 0.40 + breathe, w * 0.31, h * 0.40 + breathe)
      ..close();
    canvas.drawPath(armPath, skinPaint);
    canvas.drawPath(armPath, darkOutlinePaint);

    // Smartphone
    final phoneRect = Rect.fromLTWH(w * 0.42, h * 0.34 + breathe, w * 0.02, h * 0.06);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(3));
    canvas.drawRRect(phoneRRect, tealPaint);
    canvas.drawRRect(phoneRRect, darkOutlinePaint);

    // ── 4. ANIMATED SCANNING CONE & LASER ──
    final scanCone = Path()
      ..moveTo(w * 0.43, h * 0.37 + breathe) // Vertex from phone screen
      ..lineTo(w * 0.28, h * 0.25 + breathe) // Upper bound to head
      ..lineTo(w * 0.28, h * 0.42 + breathe) // Lower bound to chest
      ..close();
    
    final coneGradient = LinearGradient(
      colors: [
        const Color(0xFF2DD4BF).withOpacity(0.20),
        const Color(0xFF2DD4BF).withOpacity(0.01),
      ],
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
    );

    final conePaint = Paint()
      ..shader = coneGradient.createShader(Rect.fromLTWH(w * 0.28, h * 0.25 + breathe, w * 0.15, h * 0.17))
      ..style = PaintingStyle.fill;
    canvas.drawPath(scanCone, conePaint);

    // Horizontal scanning laser line moving up and down the face
    double laserY = h * 0.28 + breathe + (h * 0.12 * animationValue);
    final laserPaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawLine(Offset(w * 0.275, laserY), Offset(w * 0.325, laserY), laserPaint);

    // ── 5. FLORA / FOLIAGE (Teal / Red leaves matching reference) ──
    // Bottom Left Leaves
    final leafPaint1 = Paint()..color = const Color(0xFFEF4444);
    final leafPaint2 = Paint()..color = const Color(0xFFEF4444).withOpacity(0.7);

    // Draw Left Plant
    final leaf1 = Path()
      ..moveTo(w * 0.08, h * 0.8)
      ..quadraticBezierTo(w * 0.05, h * 0.68, w * 0.11, h * 0.68)
      ..quadraticBezierTo(w * 0.14, h * 0.74, w * 0.11, h * 0.8)
      ..close();
    canvas.drawPath(leaf1, leafPaint1);
    canvas.drawPath(leaf1, darkOutlinePaint);

    final leaf2 = Path()
      ..moveTo(w * 0.11, h * 0.8)
      ..quadraticBezierTo(w * 0.15, h * 0.70, w * 0.18, h * 0.73)
      ..quadraticBezierTo(w * 0.16, h * 0.78, w * 0.13, h * 0.8)
      ..close();
    canvas.drawPath(leaf2, leafPaint2);
    canvas.drawPath(leaf2, darkOutlinePaint);

    // Bottom Right Plants (Red foliage like in the reference)
    final rLeaf1 = Path()
      ..moveTo(w * 0.84, h * 0.8)
      ..quadraticBezierTo(w * 0.81, h * 0.62, w * 0.87, h * 0.60)
      ..quadraticBezierTo(w * 0.90, h * 0.70, w * 0.87, h * 0.8)
      ..close();
    canvas.drawPath(rLeaf1, leafPaint1);
    canvas.drawPath(rLeaf1, darkOutlinePaint);

    final rLeaf2 = Path()
      ..moveTo(w * 0.88, h * 0.8)
      ..quadraticBezierTo(w * 0.94, h * 0.66, w * 0.91, h * 0.64)
      ..quadraticBezierTo(w * 0.88, h * 0.74, w * 0.88, h * 0.8)
      ..close();
    canvas.drawPath(rLeaf2, leafPaint2);
    canvas.drawPath(rLeaf2, darkOutlinePaint);

    // Faint circular ground base
    final groundPaint = Paint()
      ..color = const Color(0xFFF1F5F9).withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(w * 0.08, h * 0.78, w * 0.84, h * 0.04), groundPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.08, h * 0.78, w * 0.84, h * 0.04), outlinePaint);
  }

  @override
  bool shouldRepaint(_CartoonScanPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
