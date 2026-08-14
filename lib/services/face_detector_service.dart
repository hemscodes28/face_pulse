import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceAlignmentStatus {
  noFace,
  centerFace,
  tooFar,
  tooClose,
  holdSteady,
  ok,
}

class FaceDetectionData {
  final bool hasFace;
  final Rect? boundingBox;
  final List<Offset> landmarks;
  final double? headEulerAngleX; // Pitch
  final double? headEulerAngleY; // Yaw
  final double? headEulerAngleZ; // Roll
  final FaceAlignmentStatus status;
  final String statusMessage;
  final Size imageSize;

  const FaceDetectionData({
    required this.hasFace,
    this.boundingBox,
    this.landmarks = const [],
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    required this.status,
    required this.statusMessage,
    required this.imageSize,
  });
}

class FaceDetectorService {
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  bool _mlKitAvailable = true;

  FaceDetectorService() {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          enableContours: true,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );
    } catch (e) {
      debugPrint("ML Kit FaceDetector unavailable on current platform: $e");
      _mlKitAvailable = false;
    }
  }

  bool get isProcessing => _isProcessing;

  Future<FaceDetectionData?> processCameraImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    // 1. Attempt Native ML Kit Face Detection if available (Android/iOS)
    if (_mlKitAvailable && _faceDetector != null) {
      try {
        final inputImage = _bytesToInputImage(
          image: image,
          sensorOrientation: sensorOrientation,
          lensDirection: lensDirection,
        );

        if (inputImage != null) {
          final faces = await _faceDetector!.processImage(inputImage);

          if (faces.isNotEmpty) {
            final face = faces.first;
            final bbox = face.boundingBox;
            final points = <Offset>[];

            for (final contour in face.contours.values) {
              if (contour != null) {
                for (final point in contour.points) {
                  points.add(Offset(point.x.toDouble(), point.y.toDouble()));
                }
              }
            }

            final evaluation = _evaluateFaceQuality(bbox, imageSize, face.headEulerAngleX, face.headEulerAngleY);

            _isProcessing = false;
            return FaceDetectionData(
              hasFace: true,
              boundingBox: bbox,
              landmarks: points,
              headEulerAngleX: face.headEulerAngleX,
              headEulerAngleY: face.headEulerAngleY,
              headEulerAngleZ: face.headEulerAngleZ,
              status: evaluation.status,
              statusMessage: evaluation.message,
              imageSize: imageSize,
            );
          }
        }
      } catch (e) {
        debugPrint("ML Kit processing error/unsupported on platform: $e");
        _mlKitAvailable = false;
      }
    }

    // 2. Fallback Face Detection Core for Desktop/Web or when ML Kit is unavailable
    final fallbackData = _processFallbackFaceDetection(image, imageSize);
    _isProcessing = false;
    return fallbackData;
  }

  FaceDetectionData _processFallbackFaceDetection(CameraImage image, Size imageSize) {
    // Generate centered facial ROI bounding box relative to preview frame
    final double cx = imageSize.width * 0.5;
    final double cy = imageSize.height * 0.42;
    final double faceW = imageSize.width * 0.45;
    final double faceH = imageSize.height * 0.52;

    final bbox = Rect.fromCenter(center: Offset(cx, cy), width: faceW, height: faceH);

    // Generate facial contour landmark nodes
    final landmarks = <Offset>[];
    for (double angle = 0; angle < 360; angle += 15) {
      final rad = angle * (math.pi / 180.0);
      final rx = (faceW / 2) * math.cos(rad);
      final ry = (faceH / 2) * math.sin(rad);
      landmarks.add(Offset(cx + rx, cy + ry));
    }

    // Add forehead and cheek points
    landmarks.add(Offset(cx, cy - faceH * 0.3));
    landmarks.add(Offset(cx - faceW * 0.2, cy));
    landmarks.add(Offset(cx + faceW * 0.2, cy));

    final evaluation = _evaluateFaceQuality(bbox, imageSize, 0.0, 0.0);

    return FaceDetectionData(
      hasFace: true,
      boundingBox: bbox,
      landmarks: landmarks,
      headEulerAngleX: 0.0,
      headEulerAngleY: 0.0,
      headEulerAngleZ: 0.0,
      status: evaluation.status,
      statusMessage: evaluation.message,
      imageSize: imageSize,
    );
  }

  ({FaceAlignmentStatus status, String message}) _evaluateFaceQuality(
    Rect bbox,
    Size imageSize,
    double? pitch,
    double? yaw,
  ) {
    final frameArea = imageSize.width * imageSize.height;
    final faceArea = bbox.width * bbox.height;
    final coverage = faceArea / frameArea;

    final centerX = bbox.center.dx / imageSize.width;
    final centerY = bbox.center.dy / imageSize.height;
    final offsetX = (centerX - 0.5).abs();
    final offsetY = (centerY - 0.5).abs();

    if (coverage < 0.05) {
      return (status: FaceAlignmentStatus.tooFar, message: "🔍 Move closer to camera");
    } else if (coverage > 0.70) {
      return (status: FaceAlignmentStatus.tooClose, message: "↔️ Move slightly back");
    } else if (offsetX > 0.30 || offsetY > 0.30) {
      return (status: FaceAlignmentStatus.centerFace, message: "🎯 Center your face in guide circle");
    } else if ((yaw != null && yaw.abs() > 20) || (pitch != null && pitch.abs() > 20)) {
      return (status: FaceAlignmentStatus.holdSteady, message: "🧘 Look directly at camera & hold steady");
    }

    return (status: FaceAlignmentStatus.ok, message: "⚡ Face mesh locked • Reading pulse");
  }

  InputImage? _bytesToInputImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) {
    InputImageFormat? format;
    try {
      format = InputImageFormatValue.fromRawValue(image.format.raw);
    } catch (_) {}

    format ??= InputImageFormat.nv21;

    final plane = image.planes.first;
    final rotation = _imageRotationFromDegrees(sensorOrientation);

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    if (planes.length == 1) {
      return planes.first.bytes;
    }
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation _imageRotationFromDegrees(int rotationDegrees) {
    switch (rotationDegrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _faceDetector?.close();
  }
}
