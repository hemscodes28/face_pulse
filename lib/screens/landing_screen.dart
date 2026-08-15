import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onConnect;
  final bool showIntro;
  final VoidCallback onIntroComplete;

  const LandingScreen({
    super.key,
    required this.onLogin,
    required this.onConnect,
    this.showIntro = true,
    required this.onIntroComplete,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with TickerProviderStateMixin {
  // View states: 'INTRO', 'TRANSITIONING', 'DASHBOARD'
  String _viewState = 'INTRO';
  Timer? _introTimer;

  // Controllers for breathing button glow
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Controller for smooth simultaneous crossfade transition
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _viewState = widget.showIntro ? 'INTRO' : 'DASHBOARD';

    // Breathing glow animation for the Connect button
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Crossfade transition animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    if (widget.showIntro) {
      _fadeController.value = 0.0;
      // Auto-transition after 3 seconds
      _introTimer = Timer(const Duration(seconds: 3), () {
        _startTransition();
      });
    } else {
      _fadeController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startTransition() {
    if (_viewState != 'INTRO') return;

    setState(() {
      _viewState = 'TRANSITIONING';
    });

    _fadeController.forward().then((_) {
      if (mounted) {
        setState(() {
          _viewState = 'DASHBOARD';
        });
        widget.onIntroComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── DASHBOARD LAYER (Fades in) ──
          if (_viewState == 'DASHBOARD' || _viewState == 'TRANSITIONING')
            FadeTransition(
              opacity: _fadeAnimation,
              child: _buildDashboard(),
            ),

          // ── INTRO LAYER (Fades out) ──
          if (_viewState == 'INTRO' || _viewState == 'TRANSITIONING')
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
              child: _buildIntro(),
            ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      color: const Color(0xFF0D2E27), // brand-forest green
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _startTransition,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Text(
                  'SKIP',
                  style: AppTheme.sansFont(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

            // Tagline Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'carefor',
                    style: AppTheme.serifFont(
                      fontSize: 24,
                      fontWeight: FontWeight.normal,
                      color: const Color(0xFFFAF6F0).withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Healthcare is complex. The experience around it shouldn\'t be.',
                    style: AppTheme.serifFont(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFFAF6F0),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Footer Loading Line (pulsing decoration)
            Container(
              width: 140,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 70,
                  height: 2,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF6F0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Stack(
      children: [
        // Ambient Waves Background (Live, real biometrics and suitable for UI)
        const Positioned.fill(
          child: _AmbientWavesBackground(),
        ),

        // Main Dashboard Layout
        Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'care',
                            style: AppTheme.sansFont(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          TextSpan(
                            text: 'for',
                            style: AppTheme.sansFont(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: widget.onLogin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        side: const BorderSide(color: AppTheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: AppTheme.sansFont(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Body Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Typography
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'The team\n',
                            style: AppTheme.sansFont(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: AppTheme.textLight,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: 'healthcare\n',
                            style: AppTheme.sansFont(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: 'needed.',
                            style: AppTheme.sansFont(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estimate pulse and blood pressure instantly with a simple camera scan.',
                      style: AppTheme.sansFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMedium,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Features list
                    _buildFeatureCard('01', 'AI Face Scanning'),
                    const SizedBox(height: 10),
                    _buildFeatureCard('02', 'Biometric Logs'),
                    const SizedBox(height: 10),
                    _buildFeatureCard('03', 'Interactive Assistant'),
                  ],
                ),
              ),
            ),

            // Call to Action Footer
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 40),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      // Calculate dynamic breathing glow shadow
                      double elevation = 6.0 + (_glowAnimation.value * 2.0);
                      double blurRadius = 24.0 + (_glowAnimation.value * 12.0);
                      double spreadRadius = 0.0 + (_glowAnimation.value * 6.0);
                      Color glowColor = AppTheme.primary.withOpacity(0.35 + (_glowAnimation.value * 0.20));

                      return Container(
                        height: 56,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor,
                              blurRadius: blurRadius,
                              spreadRadius: spreadRadius,
                              offset: Offset(0, elevation),
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: ElevatedButton(
                      onPressed: widget.onConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Connect with us',
                            style: AppTheme.sansFont(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CLINICAL EVALUATION GATEWAY • SECURE VERSION',
                    style: AppTheme.sansFont(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String stepNumber, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline.withOpacity(0.8)),
      ),
      child: Row(
        children: [
          Text(
            stepNumber,
            style: AppTheme.sansFont(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            text,
            style: AppTheme.sansFont(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ── VIDEO BACKGROUND PLAYER GRAPHIC ──
class _VideoBackground extends StatefulWidget {
  const _VideoBackground();
  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260328_105406_16f4600d-7a92-4292-b96e-b19156c7830a.mp4'),
    );

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0);
        _controller.play();
      }
    }).catchError((e) {
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const _AmbientWavesBackground();
    }
    if (!_initialized) {
      return const SizedBox.shrink();
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

// ── AMBIENT SINE WAVE BACKGROUND GRAPHIC (FALLBACK) ──
class _AmbientWavesBackground extends StatefulWidget {
  const _AmbientWavesBackground();
  @override
  State<_AmbientWavesBackground> createState() => _AmbientWavesBackgroundState();
}

class _AmbientWavesBackgroundState extends State<_AmbientWavesBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _SineWavePainter(animationValue: _ctrl.value),
        );
      },
    );
  }
}

class _SineWavePainter extends CustomPainter {
  final double animationValue;
  _SineWavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft Ambient Breathing Aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2DD4BF).withOpacity(0.06 + math.sin(animationValue * 2 * math.pi) * 0.02),
          const Color(0xFF0EA5E9).withOpacity(0.01),
          Colors.transparent,
        ],
        center: Alignment.center,
        radius: 1.2,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), auraPaint);

    // 2. Layered Sine Waves (Bottom portion)
    final wave1Paint = Paint()
      ..color = const Color(0xFF2DD4BF).withOpacity(0.05) // Soft Teal
      ..style = PaintingStyle.fill;

    final wave2Paint = Paint()
      ..color = const Color(0xFF0EA5E9).withOpacity(0.04) // Soft Cyan/Blue
      ..style = PaintingStyle.fill;

    // Draw Wave 1 (Fill)
    final path1 = Path();
    path1.moveTo(0, size.height * 0.7);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.7 +
          math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 30 +
          math.cos((x / size.width * 4 * math.pi) - (animationValue * 2 * math.pi)) * 12;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, wave1Paint);

    // Draw Wave 2 (Fill)
    final path2 = Path();
    path2.moveTo(0, size.height * 0.76);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.76 +
          math.cos((x / size.width * 2.5 * math.pi) - (animationValue * 2 * math.pi)) * 36 +
          math.sin((x / size.width * 5 * math.pi) + (animationValue * 2 * math.pi)) * 15;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, wave2Paint);

    // 3. Heartbeat Pulse Line (Active, scrolling across screen)
    final pulsePaint = Paint()
      ..color = const Color(0xFF0D9488).withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pulsePath = Path();
    pulsePath.moveTo(0, size.height * 0.73);
    for (double x = 0; x <= size.width; x++) {
      // Create a localized heartbeat QRS pulse repeating along the width
      double relativeX = (x / size.width * 3.0) + (animationValue * 1.5);
      double phase = relativeX - relativeX.floor(); // 0 to 1
      double pulseY = 0.0;
      if (phase > 0.4 && phase < 0.6) {
        // Draw the QRS spike
        double t = (phase - 0.4) / 0.2; // 0 to 1
        if (t < 0.2) {
          pulseY = -15 * (t / 0.2); // Q dip
        } else if (t < 0.5) {
          pulseY = -15 + 65 * ((t - 0.2) / 0.3); // R peak
        } else if (t < 0.8) {
          pulseY = 50 - 60 * ((t - 0.5) / 0.3); // S dip
        } else {
          pulseY = -10 + 10 * ((t - 0.8) / 0.2); // return to base
        }
      } else if (phase > 0.7 && phase < 0.85) {
        // T wave (gentle bump)
        double t = (phase - 0.7) / 0.15;
        pulseY = math.sin(t * math.pi) * 8;
      }
      // Add general ambient waves outside the pulse
      double finalY = size.height * 0.73 - pulseY +
          math.sin((x / size.width * 6 * math.pi) + (animationValue * 2 * math.pi)) * 8;
      pulsePath.lineTo(x, finalY);
    }
    canvas.drawPath(pulsePath, pulsePaint);

    // 4. Floating Biotech Nodes (Pulsing and drifting)
    final nodePaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    final nodes = [
      _NodeConfig(0.2, 0.3, 4.0, const Color(0xFF2DD4BF)),
      _NodeConfig(0.7, 0.4, 5.0, const Color(0xFF0EA5E9)),
      _NodeConfig(0.45, 0.5, 3.0, const Color(0xFF0EA5E9)),
      _NodeConfig(0.85, 0.25, 4.5, const Color(0xFF2DD4BF)),
      _NodeConfig(0.15, 0.65, 3.5, const Color(0xFF2DD4BF)),
    ];

    for (var node in nodes) {
      double angle = animationValue * 2 * math.pi + (node.xRatio * 10);
      double dx = size.width * node.xRatio + math.sin(angle) * 15;
      double dy = size.height * node.yRatio + math.cos(angle * 1.5) * 20;
      double pulse = 1.0 + math.sin(animationValue * 4 * math.pi + (node.xRatio * 5)) * 0.25;

      // Glow circle
      glowPaint.color = node.color.withOpacity(0.08 * pulse);
      canvas.drawCircle(Offset(dx, dy), node.radius * 2.8 * pulse, glowPaint);

      // Core circle
      nodePaint.color = node.color.withOpacity(0.4 * pulse);
      canvas.drawCircle(Offset(dx, dy), node.radius * pulse, nodePaint);

      // Draw faint connections to nearby nodes or waves
      final linePaint = Paint()
        ..color = node.color.withOpacity(0.06)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(dx, dy), Offset(dx, size.height * 0.73), linePaint);
    }
  }

  @override
  bool shouldRepaint(_SineWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _NodeConfig {
  final double xRatio;
  final double yRatio;
  final double radius;
  final Color color;
  _NodeConfig(this.xRatio, this.yRatio, this.radius, this.color);
}
