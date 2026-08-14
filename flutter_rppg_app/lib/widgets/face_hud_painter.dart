import 'dart:math' as math;
import 'package:flutter/material.dart';

/// FaceHudOverlayPainter renders a futuristic computer vision HUD covering
/// forehead and left/right cheek ROIs over a camera or preview canvas.
class FaceHudOverlayPainter extends CustomPainter {
  final List<Offset>? foreheadPoints;
  final List<Offset>? leftCheekPoints;
  final List<Offset>? rightCheekPoints;
  final List<Offset>? faceOvalPoints;
  final double animationProgress; // 0.0 to 1.0 for pulsing & laser scanlines
  final bool isTrackingActive;

  FaceHudOverlayPainter({
    this.foreheadPoints,
    this.leftCheekPoints,
    this.rightCheekPoints,
    this.faceOvalPoints,
    required this.animationProgress,
    this.isTrackingActive = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isTrackingActive) return;

    // Time pulse calculation for semi-transparent alpha glow
    final double pulse = (math.sin(animationProgress * 2 * math.pi) + 1.0) / 2.0;
    final double fillAlpha = 0.20 + 0.10 * pulse;

    // Draw Forehead ROI
    if (foreheadPoints != null && foreheadPoints!.length >= 3) {
      _drawPolygonRoi(
        canvas,
        foreheadPoints!,
        fillColor: const Color(0xFF00E664).withValues(alpha: fillAlpha),
        outlineColor: const Color(0xFF00FFB4),
        nodeColor: const Color(0xFF00FFDC),
        tagLabel: "[ FOREHEAD ROI // 31 PTS ]",
        animationProgress: animationProgress,
      );
    }

    // Draw Left Cheek ROI
    if (leftCheekPoints != null && leftCheekPoints!.length >= 3) {
      _drawPolygonRoi(
        canvas,
        leftCheekPoints!,
        fillColor: const Color(0xFF00C8FF).withValues(alpha: fillAlpha),
        outlineColor: const Color(0xFF50E6FF),
        nodeColor: const Color(0xFF90F5FF),
        tagLabel: "[ LEFT CHEEK // 21 PTS ]",
        animationProgress: animationProgress,
      );
    }

    // Draw Right Cheek ROI
    if (rightCheekPoints != null && rightCheekPoints!.length >= 3) {
      _drawPolygonRoi(
        canvas,
        rightCheekPoints!,
        fillColor: const Color(0xFF00C8FF).withValues(alpha: fillAlpha),
        outlineColor: const Color(0xFF50E6FF),
        nodeColor: const Color(0xFF90F5FF),
        tagLabel: "[ RIGHT CHEEK // 21 PTS ]",
        animationProgress: animationProgress,
      );
    }

    // Draw Face Lock Reticle Frame around face oval
    if (faceOvalPoints != null && faceOvalPoints!.length >= 3) {
      _drawFaceLockReticle(canvas, faceOvalPoints!);
    }
  }

  void _drawPolygonRoi(
    Canvas canvas,
    List<Offset> points, {
    required Color fillColor,
    required Color outlineColor,
    required Color nodeColor,
    required String tagLabel,
    required double animationProgress,
  }) {
    final Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    // 1. Polygon Fill
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Glowing Outline
    final Paint outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, outlinePaint);

    // 3. Landmark Micro Node Dots
    final Paint nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 2.5, nodePaint);
    }

    // 4. Bounding Box & Reticle Corner Brackets
    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    _drawCornerBrackets(canvas, Rect.fromLTRB(minX - 4, minY - 4, maxX + 4, maxY + 4), outlineColor);

    // 5. Dynamic Horizontal Laser Scan Line
    final double scanY = minY + animationProgress * (maxY - minY);
    final Paint laserPaint = Paint()
      ..color = nodeColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(minX, scanY), Offset(maxX, scanY), laserPaint);

    // 6. HUD Tag Label
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: tagLabel,
        style: TextStyle(
          color: nodeColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(minX, minY - 14));
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color, {double bracketLen = 12.0}) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Top-Left
    canvas.drawLine(rect.topLeft, Offset(rect.left + bracketLen, rect.top), paint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + bracketLen), paint);

    // Top-Right
    canvas.drawLine(rect.topRight, Offset(rect.right - bracketLen, rect.top), paint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + bracketLen), paint);

    // Bottom-Left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + bracketLen, rect.bottom), paint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - bracketLen), paint);

    // Bottom-Right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - bracketLen, rect.bottom), paint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - bracketLen), paint);
  }

  void _drawFaceLockReticle(Canvas canvas, List<Offset> points) {
    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    final Rect faceRect = Rect.fromLTRB(minX - 16, minY - 16, maxX + 16, maxY + 16);
    _drawCornerBrackets(canvas, faceRect, const Color(0xFFFFD700), bracketLen: 20.0);
  }

  @override
  bool shouldRepaint(covariant FaceHudOverlayPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.foreheadPoints != foreheadPoints ||
        oldDelegate.leftCheekPoints != leftCheekPoints ||
        oldDelegate.rightCheekPoints != rightCheekPoints;
  }
}
