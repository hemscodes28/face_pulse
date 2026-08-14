import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// RGB Mean Values payload
class MeasurementRGB {
  final double r;
  final double g;
  final double b;

  MeasurementRGB({
    required this.r,
    required this.g,
    required this.b,
  });

  Map<String, dynamic> toJson() => {
        'r': r,
        'g': g,
        'b': b,
      };
}

/// Signal Metrics payload
class MeasurementSignal {
  final double bpm;
  final double snrDb;
  final MeasurementRGB rgbMean;
  final double luminance;

  MeasurementSignal({
    required this.bpm,
    required this.snrDb,
    required this.rgbMean,
    required this.luminance,
  });

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'snr_db': snrDb,
        'rgb_mean': rgbMean.toJson(),
        'luminance': luminance,
      };
}

/// Structured JSON Measurement Request Payload
class MeasurementRequest {
  final String sessionId;
  final String timestamp;
  final int frameNumber;
  final String status;
  final MeasurementSignal signal;

  MeasurementRequest({
    required this.sessionId,
    required this.timestamp,
    required this.frameNumber,
    required this.status,
    required this.signal,
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'timestamp': timestamp,
        'frame_number': frameNumber,
        'status': status,
        'signal': signal.toJson(),
      };
}

/// Backend HTTP Service for asynchronous measurement JSON push.
class BackendService {
  /// Asynchronously posts a processed measurement payload to FastAPI backend (/api/v1/measurements).
  ///
  /// Safe & non-blocking: Network failures are caught, logged, and return false without stopping camera/measurement pipeline.
  static Future<bool> sendMeasurement(MeasurementRequest measurement) async {
    final String url = "${ApiConfig.baseUrl}${ApiConfig.measurementsEndpoint}";
    final String payloadJson = jsonEncode(measurement.toJson());

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
            },
            body: payloadJson,
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("[BackendService] Pushed measurement frame #${measurement.frameNumber} (BPM: ${measurement.signal.bpm.toStringAsFixed(1)}, SNR: ${measurement.signal.snrDb.toStringAsFixed(1)} dB)");
        return true;
      } else {
        debugPrint("[BackendService] Backend HTTP ${response.statusCode}: ${response.body}");
        return false;
      }
    } catch (e) {
      // Offline / Network Failure handling: log error without crashing or blocking
      debugPrint("[BackendService] Asynchronous measurement POST failed (backend unreachable): $e");
      return false;
    }
  }
}
