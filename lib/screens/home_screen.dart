import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../constants/quotes.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onStartScan;
  final Function(String? message) onNavigateToChat;
  final VoidCallback onNavigateToDiary;
  final VoidCallback onNavigateToProfile;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onStartScan,
    required this.onNavigateToChat,
    required this.onNavigateToDiary,
    required this.onNavigateToProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    // Choose a random quote from the 100 quotes list
    final random = Random();
    if (wellnessQuotes.isNotEmpty) {
      _currentQuote = wellnessQuotes[random.nextInt(wellnessQuotes.length)];
    } else {
      _currentQuote = "Listen to your rhythm.";
    }
  }

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    // now.weekday is 1 (Monday) to 7 (Sunday)
    final weekday = weekdays[now.weekday % 7];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'care',
                          style: AppTheme.sansFont(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        TextSpan(
                          text: 'for',
                          style: AppTheme.sansFont(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 110), // Padding bottom to avoid overlaying floating navbar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Welcome Card Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFF8FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${widget.userName}',
                                style: AppTheme.sansFont(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote_rounded, color: AppTheme.primary, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _currentQuote,
                                      style: AppTheme.sansFont(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMedium,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Color(0xFF1D4ED8), size: 12),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(),
                                style: AppTheme.sansFont(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Premium Scanning target card
                  _AnimatedScannerCard(onStartScan: widget.onStartScan),

                  const SizedBox(height: 28),

                  // 3. "Explore Your Wellbeing" Section
                  Text(
                    'Explore Your Wellbeing',
                    style: AppTheme.sansFont(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Horizontal Scrollable wellbeing suggestions
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _QuestionCard(
                          text: 'How does stress affect my blood pressure?',
                          icon: Icons.speed_rounded,
                          onTap: () => widget.onNavigateToChat('How does stress affect my blood pressure?'),
                        ),
                        const SizedBox(width: 12),
                        _QuestionCard(
                          text: 'What is a healthy heart rate range?',
                          icon: Icons.monitor_heart_rounded,
                          onTap: () => widget.onNavigateToChat('What is a healthy heart rate range?'),
                        ),
                        const SizedBox(width: 12),
                        _QuestionCard(
                          text: 'Why does my HRV change during sleep?',
                          icon: Icons.bedtime_rounded,
                          onTap: () => widget.onNavigateToChat('Why does my HRV change during sleep?'),
                        ),
                        const SizedBox(width: 12),
                        _QuestionCard(
                          text: 'How can I improve my cardiovascular resilience?',
                          icon: Icons.fitness_center_rounded,
                          onTap: () => widget.onNavigateToChat('How can I improve my cardiovascular resilience?'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true, // Allows navbar to render with transparent background filter
      bottomNavigationBar: _WavyBottomNavBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) widget.onNavigateToDiary();
          if (i == 2) widget.onStartScan();
          if (i == 3) widget.onNavigateToChat(null);
          if (i == 4) widget.onNavigateToProfile();
        },
      ),
    );
  }
}

// ── HIGH-TECH ANIMATED SCANNER CARD ──
class _AnimatedScannerCard extends StatefulWidget {
  final VoidCallback onStartScan;
  const _AnimatedScannerCard({required this.onStartScan});

  @override
  State<_AnimatedScannerCard> createState() => _AnimatedScannerCardState();
}

class _AnimatedScannerCardState extends State<_AnimatedScannerCard> with TickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseScaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDFA), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCCFBF1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2DD4BF).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Measure your pulse & blood pressure with AI face scanning.',
            textAlign: TextAlign.center,
            style: AppTheme.sansFont(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          
          // Technical circular scanner
          ScaleTransition(
            scale: _pulseScaleAnimation,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2DD4BF).withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(170, 170),
                      painter: _GridPainter(),
                    ),
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0x182DD4BF),
                      child: Icon(Icons.face_retouching_natural_rounded, size: 36, color: AppTheme.primary),
                    ),
                    AnimatedBuilder(
                      animation: _scanLineAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 170 * _scanLineAnimation.value,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2DD4BF),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2DD4BF).withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1.5,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _PulseWaveIndicator(),
          const SizedBox(height: 24),
          _StartScanButton(onPressed: widget.onStartScan),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;
    
    for (double i = 20; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 20; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ── BIOMETRIC WAVE INDICATOR ──
class _PulseWaveIndicator extends StatefulWidget {
  const _PulseWaveIndicator();
  @override
  State<_PulseWaveIndicator> createState() => _PulseWaveIndicatorState();
}
class _PulseWaveIndicatorState extends State<_PulseWaveIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) {
          const heights = [12.0, 20.0, 32.0, 20.0, 12.0];
          return Container(
            width: 4, height: heights[i] * _anim.value,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: const Color(0xFF2DD4BF), borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

// ── GLOWING SCAN BUTTON ──
class _StartScanButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _StartScanButton({required this.onPressed});
  @override
  State<_StartScanButton> createState() => _StartScanButtonState();
}
class _StartScanButtonState extends State<_StartScanButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;
  bool _pressed = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.0, end: 8.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onPressed(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: double.infinity, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0066CC), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0x660066CC), blurRadius: _glow.value + 8, spreadRadius: _glow.value / 2)],
            ),
            child: Center(
              child: Text(
                'START CAMERA SCAN', 
                style: AppTheme.sansFont(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)
              )
            ),
          ),
        ),
      ),
    );
  }
}

// ── INTERACTIVE WELLBEING QUESTION CARD ──
class _QuestionCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _QuestionCard({required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2, // Stable constant border
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: const Color(0x100066CC),
            highlightColor: const Color(0x050066CC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Icon badge
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF64748B),
                      size: 18,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Question text
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sansFont(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                        height: 1.3,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Bottom prompt hint
                  Row(
                    children: [
                      Text(
                        'Tap to ask',
                        style: AppTheme.sansFont(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0066CC),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF0066CC),
                        size: 10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── GLASSMORPHIC WAVY BOTTOM NAVIGATION BAR ──
class _WavyBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _WavyBottomNavBar({required this.currentIndex, required this.onTap});

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
                        Colors.white.withOpacity(0.40),
                        Colors.white.withOpacity(0.20),
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
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw subtle white highlighted border for flat sides
    final sidePath = Path();
    sidePath.moveTo(0, 20);
    sidePath.lineTo(w * 0.36, 20);
    borderPaint.color = Colors.white.withOpacity(0.65);
    canvas.drawPath(sidePath, borderPaint);

    final rightPath = Path();
    rightPath.moveTo(w * 0.64, 20);
    rightPath.lineTo(w, 20);
    canvas.drawPath(rightPath, borderPaint);

    // Draw blue highlighted border for the center wave dome
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
