import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/face_detector_service.dart';

class FaceOverlayPainter extends CustomPainter {
  final FaceDetectionData? detectionData;
  final double scanlineProgress;
  final bool isFrontCamera;

  FaceOverlayPainter({
    required this.detectionData,
    required this.scanlineProgress,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detectionData == null || !detectionData!.hasFace) {
      _drawGuideOval(canvas, size, const Color(0xFF64748B), "POSITION FACE IN FRAME");
      return;
    }

    final data = detectionData!;
    final bbox = data.boundingBox;
    final imgSize = data.imageSize;

    if (bbox == null || imgSize.width == 0 || imgSize.height == 0) {
      _drawGuideOval(canvas, size, const Color(0xFF64748B), "ALIGNING FACE");
      return;
    }

    // Determine scale factors to map camera image coordinates to Canvas screen size
    final double scaleX = size.width / imgSize.width;
    final double scaleY = size.height / imgSize.height;

    // Adjust for front camera mirroring if needed
    double left = isFrontCamera ? (imgSize.width - bbox.right) * scaleX : bbox.left * scaleX;
    double top = bbox.top * scaleY;
    double right = isFrontCamera ? (imgSize.width - bbox.left) * scaleX : bbox.right * scaleX;
    double bottom = bbox.bottom * scaleY;

    final scaledBBox = Rect.fromLTRB(left, top, right, bottom);

    // Color theme based on alignment status
    final Color mainColor = _getColorForStatus(data.status);

    // 1. Draw Face Bounding Box with rounded corners and subtle fill
    final RRect rrect = RRect.fromRectAndRadius(scaledBBox, const Radius.circular(20));
    final Paint fillPaint = Paint()
      ..color = mainColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    final Paint borderPaint = Paint()
      ..color = mainColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // 2. Draw Corner Brackets around bounding box
    _drawCornerBrackets(canvas, scaledBBox, mainColor);

    // 3. Draw Contour Points / Face Mesh Nodes
    if (data.landmarks.isNotEmpty) {
      final Paint landmarkPaint = Paint()
        ..color = mainColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      for (final pt in data.landmarks) {
        final double x = isFrontCamera ? (imgSize.width - pt.dx) * scaleX : pt.dx * scaleX;
        final double y = pt.dy * scaleY;
        canvas.drawCircle(Offset(x, y), 1.8, landmarkPaint);
      }
    }

    // 4. Draw Animated Scan Laser inside face bounding box
    final double laserY = scaledBBox.top + (scaledBBox.height * scanlineProgress);
    final Paint laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          mainColor.withOpacity(0.9),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTRB(scaledBBox.left, laserY - 2, scaledBBox.right, laserY + 2));

    canvas.drawLine(
      Offset(scaledBBox.left + 8, laserY),
      Offset(scaledBBox.right - 8, laserY),
      laserPaint..strokeWidth = 3.0,
    );
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 24.0;

    // Top-Left
    canvas.drawLine(Offset(rect.left, rect.top + cornerLength), Offset(rect.left, rect.top), paint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), paint);

    // Top-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right, rect.top), paint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom), paint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), paint);

    // Bottom-Right
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right, rect.bottom), paint);
    canvas.drawLine(Offset(rect.right, rect.bottom - cornerLength), Offset(rect.right, rect.bottom), paint);
  }

  void _drawGuideOval(Canvas canvas, Size size, Color color, String label) {
    final center = Offset(size.width / 2, size.height * 0.42);
    final width = size.width * 0.65;
    final height = size.height * 0.45;
    final rect = Rect.fromCenter(center: center, width: width, height: height);

    final Paint paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final Path dashPath = Path();
    for (double i = 0; i < 360; i += 12) {
      final rad = i * (3.14159 / 180);
      final nextRad = (i + 6) * (3.14159 / 180);
      final x1 = center.dx + (width / 2) * math.cos(rad);
      final y1 = center.dy + (height / 2) * math.sin(rad);
      final x2 = center.dx + (width / 2) * math.cos(nextRad);
      final y2 = center.dy + (height / 2) * math.sin(nextRad);
      dashPath.moveTo(x1, y1);
      dashPath.lineTo(x2, y2);
    }
    canvas.drawPath(dashPath, paint);
  }

  Color _getColorForStatus(FaceAlignmentStatus status) {
    switch (status) {
      case FaceAlignmentStatus.ok:
        return const Color(0xFF22D3EE); // Cyan
      case FaceAlignmentStatus.centerFace:
      case FaceAlignmentStatus.holdSteady:
        return const Color(0xFFF59E0B); // Amber
      case FaceAlignmentStatus.tooClose:
      case FaceAlignmentStatus.tooFar:
      case FaceAlignmentStatus.noFace:
      default:
        return const Color(0xFFEF4444); // Red
    }
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.detectionData != detectionData ||
        oldDelegate.scanlineProgress != scanlineProgress ||
        oldDelegate.isFrontCamera != isFrontCamera;
  }
}
