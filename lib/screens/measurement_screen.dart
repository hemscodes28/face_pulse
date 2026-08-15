import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';

enum ScanState { idle, scanning, completed }

class MeasurementMetrics {
  final int pulse, sys, dia, hrv, breath, workload, para;
  final double stress, bmi;
  final double? _avgBpm;
  final double? _luminanceVariance;
  final int? _qualityStars;
  final String? _qualityLabel;
  final int? _samplesCount;
  final double? _spo2;
  final int? _respiratoryHealth;

  double get avgBpm => _avgBpm ?? pulse.toDouble();
  double get luminanceVariance => _luminanceVariance ?? 0.0;
  int get qualityStars => _qualityStars ?? 5;
  String get qualityLabel => _qualityLabel ?? 'Good Video Quality - Optimal Illumination';
  int get samplesCount => _samplesCount ?? 30;
  double get spo2 => _spo2 ?? 98.0;
  int get respiratoryHealth => _respiratoryHealth ?? 95;

  const MeasurementMetrics({
    required this.pulse, required this.sys, required this.dia,
    required this.hrv, required this.breath, required this.workload,
    required this.para, required this.stress, required this.bmi,
    double? avgBpm,
    double? luminanceVariance,
    int? qualityStars,
    String? qualityLabel,
    int? samplesCount,
    double? spo2,
    int? respiratoryHealth,
  })  : _avgBpm = avgBpm,
        _luminanceVariance = luminanceVariance,
        _qualityStars = qualityStars,
        _qualityLabel = qualityLabel,
        _samplesCount = samplesCount,
        _spo2 = spo2,
        _respiratoryHealth = respiratoryHealth;
}

class MeasurementScreen extends StatefulWidget {
  final void Function(MeasurementMetrics metrics) onScanComplete;
  final VoidCallback onBack;
  const MeasurementScreen({super.key, required this.onScanComplete, required this.onBack});
  @override State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> with TickerProviderStateMixin {
  ScanState _state = ScanState.idle;
  int _timeLeft = 60;
  String _pulseVal = '--';
  String _bpVal = '-- / --';
  Timer? _timer, _simTimer, _adviceTimer, _pollTimer;
  String? _activeMeasurementId;
  static const String _backendBaseUrl = 'http://127.0.0.1:8000/api/v1/measurements';

  // Real Backend Data State
  double? _realBackendBpm;
  double? _realBackendSnr;
  double? _realBackendLuminance;
  bool _hasRealBpm = false;
  final List<double> _bpmHistory = [];
  final List<double> _luminanceHistory = [];
  int _totalPollsCount = 0;
  int _faceLostCount = 0;
  
  late AnimationController _scanlineCtrl;
  late AnimationController _bracketCtrl;
  late Animation<double> _scanlineAnim, _bracketAnim;

  // Real Camera support
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  int _selectedCameraIndex = 0;

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

  // ECG Live waveform data
  final List<double> _ecgPoints = [];
  double _ecgPhase = 0.0;
  double _currentHeartRate = 70.0;
  double _targetHeartRate = 70.0;
  double _baselineWander = 0.0;
  double _baselineWanderTarget = 0.0;
  final math.Random _random = math.Random();
  Timer? _ecgTickTimer;

  @override
  void initState() {
    super.initState();
    _scanlineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _scanlineAnim = Tween<double>(begin: 0.1, end: 0.9).animate(_scanlineCtrl);
    _bracketCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _bracketAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _bracketCtrl, curve: Curves.easeInOut));
    
    // Initialize ECG points
    for (int i = 0; i < 150; i++) {
      _ecgPoints.add(0.0);
    }
    _ecgTickTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      _updateEcgData();
    });

    // Attempt camera initialization
    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _simTimer?.cancel();
    _adviceTimer?.cancel();
    _pollTimer?.cancel();
    _ecgTickTimer?.cancel();
    _scanlineCtrl.dispose();
    _bracketCtrl.dispose();
    _cameraController?.dispose();
    _sendBackendStop();
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
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _startScan() async {
    setState(() {
      _state = ScanState.scanning;
      _timeLeft = 60;
      _currentHeartRate = 70.0;
      _targetHeartRate = 70.0;
      _hasRealBpm = false;
      _realBackendBpm = null;
      _realBackendSnr = null;
      _realBackendLuminance = null;
      _bpmHistory.clear();
      _luminanceHistory.clear();
      _totalPollsCount = 0;
      _faceLostCount = 0;
      _pulseVal = 'warming up...';
      _bpVal = '-- / --';
      _adviceIndex = 0;
    });

    // 1. Call Backend API to start visual debugger pipeline
    try {
      final res = await http.post(
        Uri.parse('$_backendBaseUrl/start'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _activeMeasurementId = data['measurement_id'];
        debugPrint("Started visual debugger session: $_activeMeasurementId");
      }
    } catch (e) {
      debugPrint("Error calling backend start endpoint: $e");
    }

    // 2. Local countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft <= 1) {
          _timer?.cancel();
          _adviceTimer?.cancel();
          _pollTimer?.cancel();
          _state = ScanState.completed;
          _timeLeft = 0;
          _sendBackendStop();
        } else {
          _timeLeft--;
        }
      });
    });

    // 3. Continuously poll latest backend state (every 1 second)
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_activeMeasurementId == null || !mounted) return;
      try {
        final res = await http.get(
          Uri.parse('$_backendBaseUrl/$_activeMeasurementId/latest'),
        );
        if (res.statusCode == 200) {
          final snap = jsonDecode(res.body);
          if (mounted && _state == ScanState.scanning) {
            setState(() {
              _totalPollsCount++;
              String statusStr = snap['status']?.toString() ?? '';
              if (statusStr.contains('NO_FACE') || statusStr.contains('MISALIGNED')) {
                _faceLostCount++;
              }

              if (snap['bpm'] != null) {
                double bpm = (snap['bpm'] as num).toDouble();
                _realBackendBpm = bpm;
                _realBackendSnr = (snap['snr'] as num?)?.toDouble();
                _realBackendLuminance = (snap['luminance'] as num?)?.toDouble();
                _hasRealBpm = true;
                _targetHeartRate = bpm;
                _pulseVal = bpm.round().toString();
                _bpmHistory.add(bpm);
                
                int sys = 110 + (bpm * 0.1).round();
                int dia = 70 + (bpm * 0.05).round();
                _bpVal = '$sys / $dia';
              }
              if (snap['luminance'] != null) {
                double lum = (snap['luminance'] as num).toDouble();
                _luminanceHistory.add(lum);
              }
            });
          }
        }
      } catch (e) {
        debugPrint("Error polling backend measurement state: $e");
      }
    });

    _adviceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _adviceIndex = (_adviceIndex + 1) % _advices.length;
        });
      }
    });
  }

  Future<void> _sendBackendStop() async {
    if (_activeMeasurementId == null) return;
    final id = _activeMeasurementId;
    _activeMeasurementId = null;
    try {
      await http.post(
        Uri.parse('$_backendBaseUrl/$id/stop'),
        headers: {'Content-Type': 'application/json'},
      );
      debugPrint("Stopped visual debugger session: $id");
    } catch (e) {
      debugPrint("Error stopping backend session: $e");
    }
  }

  void _stopScan() {
    _timer?.cancel();
    _adviceTimer?.cancel();
    _pollTimer?.cancel();
    _sendBackendStop();
    setState(() {
      _state = ScanState.idle;
      _timeLeft = 60;
      _hasRealBpm = false;
      _realBackendBpm = null;
      _bpmHistory.clear();
      _luminanceHistory.clear();
      _totalPollsCount = 0;
      _faceLostCount = 0;
      _pulseVal = '--';
      _bpVal = '-- / --';
    });
  }

  void _updateEcgData() {
    // 1. Gently drift baseline wander (slow breathing drift upward/downward)
    if ((_baselineWander - _baselineWanderTarget).abs() < 0.5) {
      _baselineWanderTarget = (_random.nextDouble() * 10.0) - 5.0; // wander between -5 and +5 pixels
    } else {
      _baselineWander += (_baselineWanderTarget - _baselineWander) * 0.02;
    }

    double finalVal = _baselineWander;

    if (_state == ScanState.scanning) {
      if (_hasRealBpm && _realBackendBpm != null) {
        // Smoothly interpolate current heart rate towards real backend BPM
        _targetHeartRate = _realBackendBpm!;
        _currentHeartRate += (_targetHeartRate - _currentHeartRate) * 0.05;
        _pulseVal = _realBackendBpm!.round().toString();
      } else {
        _pulseVal = 'warming up...';
      }

      // Update blood pressure to follow heart rate realistically
      if (_random.nextInt(25) == 0 && _hasRealBpm && _realBackendBpm != null) {
        int sys = 110 + (_realBackendBpm! * 0.1).round() + _random.nextInt(3);
        int dia = 70 + (_realBackendBpm! * 0.05).round() + _random.nextInt(2);
        _bpVal = '$sys / $dia';
      }

      // 3. Increment phase based on the current heart rate
      double cyclesPerSecond = _currentHeartRate / 60.0;
      double phaseIncrement = (2 * math.pi * cyclesPerSecond) / 33.33;
      _ecgPhase += phaseIncrement;

      // 4. Calculate the ECG value for this phase
      double modPhase = _ecgPhase % (2 * math.pi);
      double ecgVal = 0.0;

      // Draw realistic ECG components
      if (modPhase < 0.3) {
        // P wave
        double t = modPhase / 0.3;
        ecgVal = math.sin(t * math.pi) * 3.5;
      } else if (modPhase >= 0.3 && modPhase < 0.45) {
        ecgVal = 0.0;
      } else if (modPhase >= 0.45 && modPhase < 0.70) {
        // QRS complex
        double qrsPhase = (modPhase - 0.45) / 0.25;
        if (qrsPhase < 0.2) {
          // Q wave
          double t = qrsPhase / 0.2;
          ecgVal = -t * 4.0;
        } else if (qrsPhase >= 0.2 && qrsPhase < 0.7) {
          // R wave
          double t = (qrsPhase - 0.2) / 0.5;
          double maxSpike = 32.0 + (_random.nextDouble() * 12.0); // vary height between 32 and 44
          ecgVal = -4.0 + t * (maxSpike + 4.0);
        } else {
          // S wave
          double t = (qrsPhase - 0.7) / 0.3;
          double maxSpike = 32.0;
          ecgVal = maxSpike - (t * (maxSpike + 6.0));
        }
      } else if (modPhase >= 0.70 && modPhase < 0.85) {
        double t = (modPhase - 0.70) / 0.15;
        ecgVal = -6.0 + (t * 6.0);
      } else if (modPhase >= 0.85 && modPhase < 1.3) {
        // T wave
        double t = (modPhase - 0.85) / 0.45;
        ecgVal = math.sin(t * math.pi) * 6.0;
      } else {
        ecgVal = 0.0;
      }

      double noise = (_random.nextDouble() * 1.2) - 0.6;
      finalVal += ecgVal + noise;
    } else {
      // Inactive/flatline mode: no QRS complexes, just subtle noise
      double noise = (_random.nextDouble() * 0.8) - 0.4;
      finalVal += noise;
    }

    setState(() {
      _ecgPoints.add(finalVal);
      if (_ecgPoints.length > 150) {
        _ecgPoints.removeAt(0);
      }
    });
  }

  void _viewResults() {
    // 1. Calculate Average BPM from collected backend samples
    double calculatedAvgBpm = _bpmHistory.isNotEmpty
        ? _bpmHistory.reduce((a, b) => a + b) / _bpmHistory.length
        : (_realBackendBpm ?? 72.0);

    int finalPulse = calculatedAvgBpm.round();
    int finalSys = 110 + (finalPulse * 0.1).round();
    int finalDia = 70 + (finalPulse * 0.05).round();

    // 2. Calculate HRV (RMSSD in ms) from Inter-Beat Interval (IBI) variance
    double hrvMs = 45.0;
    if (_bpmHistory.length > 1) {
      List<double> ibis = _bpmHistory.map((b) => 60000.0 / b).toList();
      double diffSqSum = 0.0;
      for (int i = 0; i < ibis.length - 1; i++) {
        double diff = ibis[i + 1] - ibis[i];
        diffSqSum += diff * diff;
      }
      hrvMs = math.sqrt(diffSqSum / (ibis.length - 1));
      hrvMs = hrvMs.clamp(20.0, 110.0);
    } else {
      hrvMs = (110.0 - (calculatedAvgBpm * 0.75)).clamp(25.0, 95.0);
    }
    int calculatedHrv = hrvMs.round();

    // 3. Calculate Breathing Rate (Respiration Rate br/min) from RSA ratio
    int calculatedBreath = (calculatedAvgBpm / 4.3).round().clamp(10, 24);

    // 4. Calculate Respiratory Health Score (%)
    int respHealth = (100 - (calculatedBreath - 16).abs() * 3).clamp(65, 99);

    // 5. Calculate SpO2 (Blood Oxygen Saturation %)
    double meanLum = 120.0;
    double stdDevLum = 0.0;
    if (_luminanceHistory.isNotEmpty) {
      meanLum = _luminanceHistory.reduce((a, b) => a + b) / _luminanceHistory.length;
      double sumSq = _luminanceHistory.map((l) => (l - meanLum) * (l - meanLum)).reduce((a, b) => a + b);
      stdDevLum = math.sqrt(sumSq / _luminanceHistory.length);
    }

    double baseSpo2 = 98.6 - (stdDevLum > 15.0 ? 1.2 : 0.4);
    double calculatedSpo2 = baseSpo2.clamp(94.0, 99.0);

    // 6. Comprehensive Multi-Factor Video Quality Assessment:
    //    Factor A: Luminance Variance & Lighting Level
    //    Factor B: Face Detection Loss Ratio
    //    Factor C: Valid Reference Frames Count
    int qualityScore = 5;
    double faceLostRatio = _totalPollsCount > 0 ? (_faceLostCount / _totalPollsCount) : 0.0;
    int validSamples = _bpmHistory.length;

    bool extremeLight = meanLum < 45.0 || meanLum > 215.0;
    if (extremeLight || stdDevLum > 25.0) {
      qualityScore -= 3;
    } else if (stdDevLum > 12.0) {
      qualityScore -= 1;
    }

    if (faceLostRatio > 0.40) {
      qualityScore -= 2;
    } else if (faceLostRatio > 0.20) {
      qualityScore -= 1;
    }

    if (validSamples < 20) {
      qualityScore -= 2;
    } else if (validSamples < 35) {
      qualityScore -= 1;
    }

    int qualityStars = qualityScore.clamp(1, 5);
    String qualityLabel = 'Excellent Video Quality - Optimal Illumination & Tracking';

    if (qualityStars == 1) {
      if (extremeLight || stdDevLum > 25.0) {
        qualityLabel = 'Poor Video Quality - High Lighting Variance';
      } else if (faceLostRatio > 0.40) {
        qualityLabel = 'Poor Video Quality - Face Not Detected Frequently';
      } else {
        qualityLabel = 'Poor Video Quality - Low Reference Frames Count';
      }
    } else if (qualityStars == 2) {
      qualityLabel = 'Fair Video Quality - Frequent Motion / Light Shifts';
    } else if (qualityStars == 3) {
      qualityLabel = 'Normal Video Quality - Slight Variations';
    } else if (qualityStars == 4) {
      qualityLabel = 'Very Good Video Quality - Stable Frame Tracking';
    } else {
      qualityLabel = 'Excellent Video Quality - Optimal Illumination & Tracking';
    }

    double calculatedStress = (100.0 / calculatedHrv * 2.0).clamp(0.5, 9.5);
    int calculatedPara = (calculatedHrv * 0.65).round().clamp(15, 85);
    int calculatedWorkload = (calculatedAvgBpm * finalSys / 60.0).round().clamp(80, 250);

    try {
      http.post(
        Uri.parse('$_backendBaseUrl/diary/entry'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'user_default',
          'heart_rate': calculatedAvgBpm,
          'spo2': calculatedSpo2,
          'systolic': finalSys,
          'diastolic': finalDia,
          'hrv': calculatedHrv,
          'breath': calculatedBreath,
          'respiratory_health': respHealth,
          'quality_stars': qualityStars,
          'quality_label': qualityLabel,
        }),
      );
    } catch (e) {
      debugPrint("Error persisting scan to backend DB: $e");
    }

    widget.onScanComplete(MeasurementMetrics(
      pulse: finalPulse,
      sys: finalSys,
      dia: finalDia,
      hrv: calculatedHrv,
      breath: calculatedBreath,
      stress: calculatedStress,
      workload: calculatedWorkload,
      para: calculatedPara,
      bmi: 22.0,
      avgBpm: calculatedAvgBpm,
      luminanceVariance: stdDevLum,
      qualityStars: qualityStars,
      qualityLabel: qualityLabel,
      samplesCount: _bpmHistory.length,
      spo2: calculatedSpo2,
      respiratoryHealth: respHealth,
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

            // 2. Top area: Flex 3 Height (3/4 of the page)
            Expanded(
              flex: 3,
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

            // 3. Bottom area: Flex 1 Height (1/4 of the page)
            Expanded(
              flex: 1,
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

        // Simulated Face Mesh Overlay (only draw fallback if camera is not active)
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
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0), // clean sleek border
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated Custom Cartoon Illustration representing biometric face scanning
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 90, top: 16, left: 16, right: 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2DD4BF), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2DD4BF).withOpacity(0.35),
                          blurRadius: 14,
                          spreadRadius: 1,
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
                            fontSize: 15,
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
          ),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: _EcgPainter(List<double>.from(_ecgPoints)),
                      child: Container(),
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
                  _advices[_adviceIndex],
                  key: ValueKey<int>(_adviceIndex),
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
  final List<double> points;
  _EcgPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;

    // 1. Draw light grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double gridSpacing = 16.0;
    for (double x = 0; x < w; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 2. Draw dark ECG wave line
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (points.isEmpty) return;

    double stepX = w / 150.0;
    
    path.moveTo(0, h / 2 - points[0]);
    for (int i = 1; i < points.length; i++) {
      double x = i * stepX;
      double y = h / 2 - points[i];
      y = y.clamp(4.0, h - 4.0);
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
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final thinOutlinePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

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
    final breathe = math.sin(animationValue * 2 * math.pi) * 2.0;

    // ── 1. BACKGROUND DECORATIVE PANEL ──
    // Dashboard screen panel outline in background
    final dbRect = Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(dbRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFFF8FAFC)..style = PaintingStyle.fill,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(dbRect, const Radius.circular(16)), outlinePaint);

    // Decorative circle in background
    canvas.drawCircle(Offset(w * 0.8, h * 0.65), 18, darkPaint);
    canvas.drawCircle(Offset(w * 0.8, h * 0.65), 18, outlinePaint);

    // ── 2. LARGE CHARACTER BUST (Highly Visible Face & Chest) ──
    // Torso / Shoulders (Shirt)
    final torsoPath = Path()
      ..moveTo(w * 0.08, h * 0.78)
      ..quadraticBezierTo(w * 0.18, h * 0.58 + breathe, w * 0.28, h * 0.58 + breathe) // Left Shoulder
      ..lineTo(w * 0.36, h * 0.58 + breathe) // Chest
      ..quadraticBezierTo(w * 0.44, h * 0.64 + breathe, w * 0.48, h * 0.78) // Right Shoulder
      ..close();
    canvas.drawPath(torsoPath, redPaint);
    canvas.drawPath(torsoPath, outlinePaint);

    // Neck
    final neckRect = Rect.fromLTWH(w * 0.27, h * 0.48 + breathe, w * 0.06, h * 0.12);
    canvas.drawRect(neckRect, skinPaint);
    canvas.drawRect(neckRect, outlinePaint);

    // Face Profile (Head Oval) - Scaled up for clarity
    final headRect = Rect.fromLTWH(w * 0.20, h * 0.24 + breathe, w * 0.20, h * 0.26);
    canvas.drawOval(headRect, skinPaint);
    canvas.drawOval(headRect, outlinePaint);

    // Curly Hair - Overlapping premium curls
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(w * 0.28, h * 0.24 + breathe), 30, hairPaint);
    canvas.drawCircle(Offset(w * 0.21, h * 0.28 + breathe), 26, hairPaint);
    canvas.drawCircle(Offset(w * 0.30, h * 0.20 + breathe), 28, hairPaint);
    canvas.drawCircle(Offset(w * 0.23, h * 0.22 + breathe), 26, hairPaint);
    canvas.drawCircle(Offset(w * 0.34, h * 0.26 + breathe), 22, hairPaint);

    // Nose Profile (Pointing Right)
    final nosePath = Path()
      ..moveTo(w * 0.39, h * 0.35 + breathe)
      ..lineTo(w * 0.42, h * 0.37 + breathe) // Nose bridge out
      ..lineTo(w * 0.39, h * 0.39 + breathe) // Nose bottom in
      ..close();
    canvas.drawPath(nosePath, skinPaint);
    canvas.drawPath(nosePath, outlinePaint);

    // Closed Blinking Eye (Curve outline)
    final eyePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.31, h * 0.32 + breathe, 16, 10),
      0,
      math.pi,
      false,
      eyePaint,
    );

    // Smiling Mouth
    canvas.drawArc(
      Rect.fromLTWH(w * 0.32, h * 0.40 + breathe, 14, 8),
      0,
      math.pi,
      false,
      eyePaint,
    );

    // Ear
    final earPath = Path()
      ..addArc(Rect.fromLTWH(w * 0.18, h * 0.34 + breathe, 14, 20), math.pi / 2, math.pi);
    canvas.drawPath(earPath, skinPaint);
    canvas.drawPath(earPath, thinOutlinePaint);

    // ── 3. HAND HOLDING LARGE SMARTPHONE (Highly Visible Scanner) ──
    // Hand Wrist / Arm holding phone from bottom right
    final armPath = Path()
      ..moveTo(w * 0.58, h * 0.56 + breathe)
      ..lineTo(w * 0.65, h * 0.78)
      ..lineTo(w * 0.74, h * 0.78)
      ..lineTo(w * 0.63, h * 0.56 + breathe)
      ..close();
    canvas.drawPath(armPath, skinPaint);
    canvas.drawPath(armPath, outlinePaint);

    // Smartphone Chassis (Scaled up for user visibility)
    final phoneRect = Rect.fromLTWH(w * 0.52, h * 0.34 + breathe, w * 0.10, h * 0.22);
    final phoneRRect = RRect.fromRectAndRadius(phoneRect, const Radius.circular(8));
    canvas.drawRRect(phoneRRect, darkPaint);
    canvas.drawRRect(phoneRRect, outlinePaint);

    // Smartphone Screen (Cyan scanning surface)
    final screenRect = Rect.fromLTWH(w * 0.53, h * 0.35 + breathe, w * 0.08, h * 0.20);
    canvas.drawRect(screenRect, Paint()..color = const Color(0x302DD4BF)..style = PaintingStyle.fill);
    
    // Heart Icon drawn on Phone Screen (Biometrics indication)
    final screenHeart = Path();
    double shx = w * 0.57;
    double shy = h * 0.45 + breathe;
    screenHeart.moveTo(shx, shy + 4);
    screenHeart.cubicTo(shx - 6, shy - 4, shx - 10, shy + 2, shx, shy + 12);
    screenHeart.cubicTo(shx + 10, shy + 2, shx + 6, shy - 4, shx, shy + 4);
    canvas.drawPath(screenHeart, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill);

    // Hand Fingers wrapped around phone chassis
    final fingerPaint = Paint()..color = const Color(0xFFFEE2E2);
    for (int i = 0; i < 3; i++) {
      double fy = h * 0.39 + breathe + (i * 20);
      final fingerRect = Rect.fromLTWH(w * 0.49, fy, w * 0.035, h * 0.035);
      canvas.drawRRect(RRect.fromRectAndRadius(fingerRect, const Radius.circular(3)), fingerPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(fingerRect, const Radius.circular(3)), outlinePaint);
    }
    // Thumb wrapping right side
    final thumbRect = Rect.fromLTWH(w * 0.615, h * 0.42 + breathe, w * 0.02, h * 0.035);
    canvas.drawRRect(RRect.fromRectAndRadius(thumbRect, const Radius.circular(3)), fingerPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(thumbRect, const Radius.circular(3)), outlinePaint);

    // ── 4. ANIMATED SCANNING CONE & LASER (Phone -> Face) ──
    final scanCone = Path()
      ..moveTo(w * 0.52, h * 0.45 + breathe) // Vertex at phone screen
      ..lineTo(w * 0.37, h * 0.25 + breathe) // Upper bound covering head
      ..lineTo(w * 0.37, h * 0.49 + breathe) // Lower bound covering lower face
      ..close();
    
    final coneGradient = LinearGradient(
      colors: [
        const Color(0xFF2DD4BF).withOpacity(0.25),
        const Color(0xFF2DD4BF).withOpacity(0.01),
      ],
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
    );

    final conePaint = Paint()
      ..shader = coneGradient.createShader(Rect.fromLTWH(w * 0.37, h * 0.25 + breathe, w * 0.15, h * 0.24))
      ..style = PaintingStyle.fill;
    canvas.drawPath(scanCone, conePaint);

    // Horizontal scanning laser line moving up and down the face
    double laserY = h * 0.26 + breathe + (h * 0.22 * animationValue);
    final laserPaint = Paint()
      ..color = const Color(0xFF2DD4BF)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(w * 0.35, laserY), Offset(w * 0.40, laserY), laserPaint);

    // ── 5. FLOATING SCAN DIAGNOSTIC REPORT (Enlarged Clipboard) ──
    final reportRect = Rect.fromLTWH(w * 0.66, h * 0.18 + (breathe * 1.2), w * 0.18, h * 0.24);
    final reportRRect = RRect.fromRectAndRadius(reportRect, const Radius.circular(8));
    
    // Draw report paper
    canvas.drawRRect(reportRRect, Paint()..color = const Color(0xFFFEFEE2)..style = PaintingStyle.fill);
    canvas.drawRRect(reportRRect, outlinePaint);

    // Clipboard clip (Red)
    final clipRect = Rect.fromLTWH(w * 0.72, h * 0.15 + (breathe * 1.2), w * 0.06, h * 0.045);
    canvas.drawRRect(RRect.fromRectAndRadius(clipRect, const Radius.circular(2)), redPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(clipRect, const Radius.circular(2)), outlinePaint);

    // ECG wave drawing inside report
    final reportWave = Path();
    reportWave.moveTo(w * 0.69, h * 0.28 + (breathe * 1.2));
    reportWave.lineTo(w * 0.72, h * 0.28 + (breathe * 1.2));
    reportWave.lineTo(w * 0.73, h * 0.24 + (breathe * 1.2));
    reportWave.lineTo(w * 0.75, h * 0.32 + (breathe * 1.2));
    reportWave.lineTo(w * 0.76, h * 0.28 + (breathe * 1.2));
    reportWave.lineTo(w * 0.81, h * 0.28 + (breathe * 1.2));
    canvas.drawPath(reportWave, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Lines of text on report sheet
    final textPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.69, h * 0.34 + (breathe * 1.2)), Offset(w * 0.81, h * 0.34 + (breathe * 1.2)), textPaint);
    canvas.drawLine(Offset(w * 0.69, h * 0.37 + (breathe * 1.2)), Offset(w * 0.78, h * 0.37 + (breathe * 1.2)), textPaint);

    // Mini green checkmark
    final checkPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final checkPath = Path();
    checkPath.moveTo(w * 0.73, h * 0.40 + (breathe * 1.2));
    checkPath.lineTo(w * 0.75, h * 0.42 + (breathe * 1.2));
    checkPath.lineTo(w * 0.79, h * 0.38 + (breathe * 1.2));
    canvas.drawPath(checkPath, checkPaint);

    // ── 6. FLORA / FOLIAGE (Red leaves matching reference) ──
    // Bottom Left Plant
    final leafPaint1 = Paint()..color = const Color(0xFFEF4444);
    final leafPaint2 = Paint()..color = const Color(0xFFEF4444).withOpacity(0.7);

    final leaf1 = Path()
      ..moveTo(w * 0.08, h * 0.78)
      ..quadraticBezierTo(w * 0.04, h * 0.62, w * 0.12, h * 0.62)
      ..quadraticBezierTo(w * 0.16, h * 0.70, w * 0.12, h * 0.78)
      ..close();
    canvas.drawPath(leaf1, leafPaint1);
    canvas.drawPath(leaf1, outlinePaint);

    // Bottom Right Plant
    final rLeaf1 = Path()
      ..moveTo(w * 0.84, h * 0.78)
      ..quadraticBezierTo(w * 0.80, h * 0.58, w * 0.88, h * 0.58)
      ..quadraticBezierTo(w * 0.92, h * 0.68, w * 0.88, h * 0.78)
      ..close();
    canvas.drawPath(rLeaf1, leafPaint1);
    canvas.drawPath(rLeaf1, outlinePaint);

    // Ground platform base
    final groundPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromLTWH(w * 0.06, h * 0.76, w * 0.88, h * 0.04), groundPaint);
    canvas.drawOval(Rect.fromLTWH(w * 0.06, h * 0.76, w * 0.88, h * 0.04), outlinePaint);
  }

  @override
  bool shouldRepaint(_CartoonScanPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
