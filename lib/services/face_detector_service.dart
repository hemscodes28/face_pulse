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
  late final FaceDetector _faceDetector;
  bool _isProcessing = false;

  FaceDetectorService() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }

  bool get isProcessing => _isProcessing;

  Future<FaceDetectionData?> processCameraImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) async {
    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      final inputImage = _bytesToInputImage(
        image: image,
        sensorOrientation: sensorOrientation,
        lensDirection: lensDirection,
      );

      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      final faces = await _faceDetector.processImage(inputImage);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      if (faces.isEmpty) {
        _isProcessing = false;
        return FaceDetectionData(
          hasFace: false,
          status: FaceAlignmentStatus.noFace,
          statusMessage: "👤 Position your face in frame",
          imageSize: imageSize,
        );
      }

      final face = faces.first;
      final bbox = face.boundingBox;
      final points = <Offset>[];

      // Collect contour & landmark points
      for (final contour in face.contours.values) {
        if (contour != null) {
          for (final point in contour.points) {
            points.add(Offset(point.x.toDouble(), point.y.toDouble()));
          }
        }
      }

      // Check alignment & coverage gates
      final frameArea = imageSize.width * imageSize.height;
      final faceArea = bbox.width * bbox.height;
      final coverage = faceArea / frameArea;

      final centerX = bbox.center.dx / imageSize.width;
      final centerY = bbox.center.dy / imageSize.height;
      final offsetX = (centerX - 0.5).abs();
      final offsetY = (centerY - 0.5).abs();

      FaceAlignmentStatus status = FaceAlignmentStatus.ok;
      String message = "⚡ Face mesh locked • Reading pulse";

      if (coverage < 0.05) {
        status = FaceAlignmentStatus.tooFar;
        message = "🔍 Move closer to camera";
      } else if (coverage > 0.65) {
        status = FaceAlignmentStatus.tooClose;
        message = "↔️ Move slightly back";
      } else if (offsetX > 0.25 || offsetY > 0.25) {
        status = FaceAlignmentStatus.centerFace;
        message = "🎯 Center your face in guide circle";
      } else if ((face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 20) ||
                 (face.headEulerAngleX != null && face.headEulerAngleX!.abs() > 20)) {
        status = FaceAlignmentStatus.holdSteady;
        message = "🧘 Look directly at camera & hold steady";
      }

      _isProcessing = false;
      return FaceDetectionData(
        hasFace: true,
        boundingBox: bbox,
        landmarks: points,
        headEulerAngleX: face.headEulerAngleX,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
        status: status,
        statusMessage: message,
        imageSize: imageSize,
      );
    } catch (e) {
      debugPrint("FaceDetectorService error: $e");
      _isProcessing = false;
      return null;
    }
  }

  InputImage? _bytesToInputImage({
    required CameraImage image,
    required int sensorOrientation,
    required CameraLensDirection lensDirection,
  }) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

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
    _faceDetector.close();
  }
}
