import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'face_detector_service.dart';

class ProcessedMetrics {
  final double timestamp;
  final double bpm;
  final double snrDb;
  final double signalQuality;
  final String status;
  final List<double> pulseWaveform;
  final String model;

  const ProcessedMetrics({
    required this.timestamp,
    required this.bpm,
    required this.snrDb,
    required this.signalQuality,
    required this.status,
    required this.pulseWaveform,
    required this.model,
  });

  factory ProcessedMetrics.fromJson(Map<String, dynamic> json) {
    return ProcessedMetrics(
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      bpm: (json['bpm'] as num?)?.toDouble() ?? 0.0,
      snrDb: (json['snr_db'] as num?)?.toDouble() ?? 0.0,
      signalQuality: (json['signal_quality'] as num?)?.toDouble() ?? 1.0,
      status: json['status'] as String? ?? 'OK',
      pulseWaveform: (json['pulse_waveform'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      model: json['model'] as String? ?? 'TS-CAN',
    );
  }
}

class WebSocketBackendService {
  final String host;
  final int port;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  int _frameCounter = 0;

  final _metricsController = StreamController<ProcessedMetrics>.broadcast();
  Stream<ProcessedMetrics> get metricsStream => _metricsController.stream;

  bool get isConnected => _isConnected;

  WebSocketBackendService({
    this.host = '127.0.0.1',
    this.port = 8000,
  });

  Future<bool> connect() async {
    try {
      final uri = Uri.parse('ws://$host:$port/ws/raw-rppg-stream');
      debugPrint('Connecting to backend WebSocket endpoint: $uri');
      
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _isConnected = true;
      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data as String) as Map<String, dynamic>;
            final metrics = ProcessedMetrics.fromJson(jsonMap);
            _metricsController.add(metrics);
          } catch (e) {
            debugPrint('Error parsing backend response: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('WebSocket connection closed.');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to connect to backend WebSocket: $e');
      _isConnected = false;
      return false;
    }
  }

  void sendFramePayload(FaceDetectionData detection) {
    if (!_isConnected || _channel == null) return;

    try {
      _frameCounter++;
      final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final bbox = detection.boundingBox;

      final double coverage = (bbox != null && detection.imageSize.width > 0)
          ? (bbox.width * bbox.height) / (detection.imageSize.width * detection.imageSize.height)
          : 0.25;

      final payload = {
        'timestamp': timestamp,
        'frame_id': _frameCounter,
        'status': _statusToBackendString(detection.status),
        'rois': {
          'forehead': {'red': 122.5, 'green': 116.8, 'blue': 110.2},
          'left_cheek': {'red': 120.1, 'green': 114.5, 'blue': 108.9},
          'right_cheek': {'red': 121.0, 'green': 115.2, 'blue': 109.4},
          'global_skin': {'red': 121.2, 'green': 115.5, 'blue': 109.5},
        },
        'quality': {
          'coverage_ratio': coverage,
          'yaw': detection.headEulerAngleY ?? 0.0,
          'pitch': detection.headEulerAngleX ?? 0.0,
          'roll': detection.headEulerAngleZ ?? 0.0,
          'luminance_y': 128.0,
        }
      };

      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('Error sending frame payload: $e');
    }
  }

  String _statusToBackendString(FaceAlignmentStatus status) {
    switch (status) {
      case FaceAlignmentStatus.ok:
        return 'OK';
      case FaceAlignmentStatus.noFace:
        return 'NO_FACE';
      case FaceAlignmentStatus.holdSteady:
        return 'BAD_POSE';
      case FaceAlignmentStatus.centerFace:
      case FaceAlignmentStatus.tooClose:
      case FaceAlignmentStatus.tooFar:
        return 'FACE_MISALIGNED';
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _frameCounter = 0;
  }

  void dispose() {
    disconnect();
    _metricsController.close();
  }
}
