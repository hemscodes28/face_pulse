import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── GLASSMORPHIC WAVY BOTTOM NAVIGATION BAR ──
class WavyBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const WavyBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 90,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Glassmorphic Background Wave
          Positioned.fill(
            child: ClipPath(
              clipper: _NavbarWaveClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.65),
                        Colors.white.withOpacity(0.35),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Painters for borders
          Positioned.fill(
            child: CustomPaint(
              painter: _NavbarWavePainter(),
            ),
          ),

          // 3. Navigation Bar Icons
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            top: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WavyNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _WavyNavItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Diary',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                
                // Spacer for the center floating button
                const SizedBox(width: 72),
                
                _WavyNavItem(
                  icon: Icons.forum_rounded,
                  label: 'Chatbot',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
                _WavyNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),

          // 4. Floating Center Button inside the wave peak
          Positioned(
            top: 2,
            left: width / 2 - 28,
            child: _FloatingMeasureButton(
              onTap: () => onTap(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavyNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _WavyNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF0066CC);
    final inactiveColor = const Color(0xFF64748B);
    
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 12 : 8,
                vertical: isActive ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive ? const Color(0x180066CC) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? const Color(0x300066CC) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 22 : 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTheme.sansFont(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingMeasureButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FloatingMeasureButton({required this.onTap});

  @override
  State<_FloatingMeasureButton> createState() => _FloatingMeasureButtonState();
}

class _FloatingMeasureButtonState extends State<_FloatingMeasureButton> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4, end: 12).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2DD4BF), Color(0xFF0066CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2DD4BF).withOpacity(0.4),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 3,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: const Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ── CUSTOM CLIPPER FOR WAVY BOTTOM NAVBAR ──
class _NavbarWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    path.moveTo(0, 20);
    path.lineTo(w * 0.36, 20);
    
    // Wave raise
    path.cubicTo(
      w * 0.43, 20,
      w * 0.45, 0,
      w * 0.50, 0,
    );
    // Wave fall
    path.cubicTo(
      w * 0.55, 0,
      w * 0.57, 20,
      w * 0.64, 20,
    );
    
    path.lineTo(w, 20);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ── CUSTOM PAINTER FOR WAVY OUTLINES ──
class _NavbarWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw top flat sides, left, bottom, and right edges in soft white/translucent border
    final outlinePath = Path();
    // Top-Left side
    outlinePath.moveTo(0, 20);
    outlinePath.lineTo(w * 0.36, 20);
    
    // Top-Right side
    outlinePath.moveTo(w * 0.64, 20);
    outlinePath.lineTo(w, 20);
    
    // Right side down
    outlinePath.lineTo(w, h);
    
    // Bottom side left
    outlinePath.lineTo(0, h);
    
    // Left side up
    outlinePath.lineTo(0, 20);

    borderPaint.color = Colors.white.withOpacity(0.70);
    canvas.drawPath(outlinePath, borderPaint);

    // Also draw a dark/gray shadow border underneath for depth
    final shadowBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withOpacity(0.06);
    
    final shadowPath = Path();
    shadowPath.moveTo(w * 0.64, 20);
    shadowPath.lineTo(w, 20);
    shadowPath.lineTo(w, h);
    shadowPath.lineTo(0, h);
    shadowPath.lineTo(0, 20);
    shadowPath.lineTo(w * 0.36, 20);
    canvas.drawPath(shadowPath, shadowBorderPaint);

    // 2. Draw blue highlighted border for the center wave dome
    final centerPath = Path();
    centerPath.moveTo(w * 0.36, 20);
    centerPath.cubicTo(
      w * 0.43, 20,
      w * 0.45, 0,
      w * 0.50, 0,
    );
    centerPath.cubicTo(
      w * 0.55, 0,
      w * 0.57, 20,
      w * 0.64, 20,
    );
    
    borderPaint.color = const Color(0xFF0066CC);
    borderPaint.strokeWidth = 2.0;
    canvas.drawPath(centerPath, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
