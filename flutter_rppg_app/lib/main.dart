import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'widgets/face_hud_painter.dart';

void main() {
  runApp(const FacePulseApp());
}

class FacePulseApp extends StatelessWidget {
  const FacePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Pulse - Visual HUD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFB4),
          surface: Color(0xFF121824),
        ),
      ),
      home: const FacePulseHudScreen(),
    );
  }
}

class FacePulseHudScreen extends StatefulWidget {
  const FacePulseHudScreen({super.key});

  @override
  State<FacePulseHudScreen> createState() => _FacePulseHudScreenState();
}

class _FacePulseHudScreenState extends State<FacePulseHudScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _metricsTimer;

  bool _isCameraOn = true;
  double _bpm = 72.4;
  double _snr = 8.2;
  final double _fps = 30.0;
  final String _status = "OK";
  final List<double> _waveform = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Simulate pulse waveform signal
    _metricsTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted || !_isCameraOn) return;
      final double t = timer.tick * 0.033;
      final double pulseVal = 150.0 + 4.0 * math.sin(2.0 * math.pi * 1.2 * t) + 1.2 * math.sin(4.0 * math.pi * 1.2 * t);
      setState(() {
        _waveform.add(pulseVal);
        if (_waveform.length > 100) {
          _waveform.removeAt(0);
        }
        _bpm = 72.0 + 1.5 * math.sin(t * 0.2);
        _snr = 8.0 + 0.5 * math.cos(t * 0.3);
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _metricsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Feed / Camera Simulation Background
            Positioned.fill(
              child: _isCameraOn
                  ? AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: FaceHudOverlayPainter(
                            foreheadPoints: _generateSyntheticForehead(MediaQuery.of(context).size),
                            leftCheekPoints: _generateSyntheticLeftCheek(MediaQuery.of(context).size),
                            rightCheekPoints: _generateSyntheticRightCheek(MediaQuery.of(context).size),
                            faceOvalPoints: _generateSyntheticFaceOval(MediaQuery.of(context).size),
                            animationProgress: _animController.value,
                            isTrackingActive: true,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.85,
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF0B0E14).withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: const Color(0xFF0B0E14),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text("Camera Standby", style: TextStyle(color: Colors.grey, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
            ),

            // 2. Glassmorphic Telemetry Top HUD Dashboard
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTelemetryHud(),
            ),

            // 3. Live Pulse Waveform Mini-Graph (Bottom Right)
            Positioned(
              bottom: 24,
              right: 16,
              child: _buildWaveformGraph(),
            ),

            // 4. Floating Action Controls (Bottom Left)
            Positioned(
              bottom: 24,
              left: 16,
              child: Row(
                children: [
                  FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _isCameraOn = !_isCameraOn;
                      });
                    },
                    backgroundColor: _isCameraOn ? const Color(0xFFFF3B30) : const Color(0xFF00FFB4),
                    icon: Icon(_isCameraOn ? Icons.videocam_off : Icons.videocam, color: Colors.black),
                    label: Text(
                      _isCameraOn ? "STOP CAMERA" : "START CAMERA",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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

  Widget _buildTelemetryHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF121824).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00FFB4).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status Pill
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCameraOn ? const Color(0xFF00FFB4) : Colors.grey,
                  boxShadow: _isCameraOn
                      ? [const BoxShadow(color: Color(0xFF00FFB4), blurRadius: 8)]
                      : [],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "STATUS: $_status",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Text("FPS: ${_fps.toStringAsFixed(1)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),

          // BPM & SNR Metrics
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFFF2D55), size: 20),
              const SizedBox(width: 6),
              Text(
                "${_bpm.toStringAsFixed(1)} BPM",
                style: const TextStyle(color: Color(0xFF00FFB4), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 18),
              Text(
                "SNR: ${_snr.toStringAsFixed(1)} dB",
                style: const TextStyle(color: Color(0xFF90F5FF), fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformGraph() {
    return Container(
      width: 280,
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121824).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00C8FF).withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PULSE WAVEFORM", style: TextStyle(color: Color(0xFF00FFB4), fontSize: 10, fontWeight: FontWeight.bold)),
              Text("POS DSP", style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: WaveformPainter(waveform: _waveform),
            ),
          ),
        ],
      ),
    );
  }

  List<Offset> _generateSyntheticForehead(Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 - 100;
    return [
      Offset(cx - 100, cy - 30),
      Offset(cx - 40, cy - 45),
      Offset(cx + 40, cy - 45),
      Offset(cx + 100, cy - 30),
      Offset(cx + 80, cy + 20),
      Offset(cx - 80, cy + 20),
    ];
  }

  List<Offset> _generateSyntheticLeftCheek(Size size) {
    final double cx = size.width / 2 - 80;
    final double cy = size.height / 2 + 30;
    return [
      Offset(cx - 35, cy - 25),
      Offset(cx + 35, cy - 25),
      Offset(cx + 40, cy + 25),
      Offset(cx - 40, cy + 25),
    ];
  }

  List<Offset> _generateSyntheticRightCheek(Size size) {
    final double cx = size.width / 2 + 80;
    final double cy = size.height / 2 + 30;
    return [
      Offset(cx - 35, cy - 25),
      Offset(cx + 35, cy - 25),
      Offset(cx + 40, cy + 25),
      Offset(cx - 40, cy + 25),
    ];
  }

  List<Offset> _generateSyntheticFaceOval(Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final List<Offset> oval = [];
    for (int i = 0; i < 24; i++) {
      final double angle = i * 2 * math.pi / 24;
      oval.add(Offset(cx + 160 * math.cos(angle), cy + 210 * math.sin(angle)));
    }
    return oval;
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveform;

  WaveformPainter({required this.waveform});

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.length < 2) return;

    final double minV = waveform.reduce(math.min);
    final double maxV = waveform.reduce(math.max);
    final double span = (maxV - minV) > 0.1 ? (maxV - minV) : 1.0;

    final Path path = Path();
    for (int i = 0; i < waveform.length; i++) {
      final double x = i * (size.width / (waveform.length - 1));
      final double normY = (waveform[i] - minV) / span;
      final double y = size.height - (normY * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final Paint linePaint = Paint()
      ..color = const Color(0xFF00FFB4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
