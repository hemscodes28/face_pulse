import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/innovative_back_button.dart';

class SignUpScreen extends StatefulWidget {
  final Function(String name) onSignUp;
  final VoidCallback onNavigateToSignIn;
  final VoidCallback onBack;

  const SignUpScreen({
    super.key,
    required this.onSignUp,
    required this.onNavigateToSignIn,
    required this.onBack,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _PasswordStrength {
  final int level;
  final String label;
  final Color color;

  const _PasswordStrength(this.level, this.label, this.color);
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  String? _focusedField;

  // Background orbs animation controllers
  late AnimationController _orbController;
  // Button breathing glow controllers
  late AnimationController _glowController;
  // Pulsing person logo controller
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    // Background orbs slow rotation/drift
    _orbController = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();

    // Button breathing glow
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    // Pulse logo ping animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  _PasswordStrength _getStrength(String pw) {
    if (pw.isEmpty) return const _PasswordStrength(0, '', Colors.transparent);
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    
    if (score == 0) return const _PasswordStrength(0, '', Colors.transparent);
    if (score == 1) return const _PasswordStrength(1, 'Weak', Colors.red);
    if (score == 2) return const _PasswordStrength(2, 'Fair', Colors.orange);
    if (score == 3) return const _PasswordStrength(3, 'Good', Colors.green);
    return const _PasswordStrength(4, 'Strong', AppTheme.primary);
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmController.text) {
        return;
      }
      setState(() {
        _isLoading = true;
      });
      // Simulate network request
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          widget.onSignUp(_nameController.text);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final strength = _getStrength(_passwordController.text);
    final confirmText = _confirmController.text;
    final isMatch = confirmText.isNotEmpty && confirmText == _passwordController.text;
    final isMismatch = confirmText.isNotEmpty && confirmText != _passwordController.text;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // â”€â”€ Animated Background Orbs â”€â”€
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              final angle = _orbController.value * 2 * math.pi;
              return Stack(
                children: [
                  // Orb 1
                  Positioned(
                    top: -30 + (22 * math.sin(angle)),
                    left: -40 + (18 * math.cos(angle)),
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE6F4F8).withOpacity(0.12),
                      ),
                    ),
                  ),
                  // Orb 2
                  Positioned(
                    top: (size.height / 3) + (16 * math.cos(angle)),
                    right: -80 + (20 * math.sin(angle)),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                  // Orb 3
                  Positioned(
                    bottom: 60 + (20 * math.sin(angle + 1.0)),
                    left: 10 + (10 * math.cos(angle + 1.0)),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2FD9F4).withOpacity(0.12),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // â”€â”€ Form Content â”€â”€
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),

                      // Header
                      Column(
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 80 + (_pulseController.value * 28),
                                      height: 80 + (_pulseController.value * 28),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: const Color(0xFF2FD9F4).withOpacity(0.3 * (1.0 - _pulseController.value)),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00ACC1), AppTheme.primary],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.35),
                                        blurRadius: 32,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Create account',
                            style: AppTheme.sansFont(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start your personalised health journey today',
                            style: AppTheme.sansFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Form Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 40,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Full Name field
                              Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {
                                    _focusedField = hasFocus ? 'name' : null;
                                  });
                                },
                                child: TextFormField(
                                  controller: _nameController,
                                  style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: AppTheme.inputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icons.person_outline,
                                    isFocused: _focusedField == 'name',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email field
                              Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {
                                    _focusedField = hasFocus ? 'email' : null;
                                  });
                                },
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: AppTheme.inputDecoration(
                                    labelText: 'Email address',
                                    prefixIcon: Icons.mail_outline,
                                    isFocused: _focusedField == 'email',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {
                                    _focusedField = hasFocus ? 'password' : null;
                                  });
                                },
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
                                  onChanged: (val) => setState(() {}),
                                  style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: AppTheme.inputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icons.lock_outline,
                                    isFocused: _focusedField == 'password',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: AppTheme.textMedium,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showPassword = !_showPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 8) {
                                      return 'Password must be at least 8 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              // Dynamic Password Strength Meter
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(4, (index) {
                                          return Expanded(
                                            child: Container(
                                              height: 4,
                                              margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                                              decoration: BoxDecoration(
                                                color: (index + 1) <= strength.level
                                                    ? strength.color
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        strength.label,
                                        style: AppTheme.sansFont(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: strength.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Confirm Password field
                              Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {
                                    _focusedField = hasFocus ? 'confirm' : null;
                                  });
                                },
                                child: TextFormField(
                                  controller: _confirmController,
                                  obscureText: !_showConfirm,
                                  onChanged: (val) => setState(() {}),
                                  style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    labelText: 'Confirm password',
                                    labelStyle: AppTheme.sansFont(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      color: isMismatch ? Colors.red : (_focusedField == 'confirm' ? AppTheme.primary : AppTheme.textMedium),
                                    ),
                                    floatingLabelStyle: AppTheme.sansFont(
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.bold,
                                      color: isMismatch ? Colors.red : AppTheme.primary,
                                      letterSpacing: 0.08,
                                    ),
                                    prefixIcon: Icon(
                                      isMatch ? Icons.check_circle_outline : isMismatch ? Icons.cancel_outlined : Icons.lock_reset,
                                      color: isMatch ? Colors.green : isMismatch ? Colors.red : (_focusedField == 'confirm' ? AppTheme.primary : AppTheme.textLight),
                                      size: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: AppTheme.textMedium,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _showConfirm = !_showConfirm;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isMatch ? Colors.green.shade400 : isMismatch ? Colors.red.shade400 : AppTheme.outline,
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: isMatch ? Colors.green : isMismatch ? Colors.red : AppTheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 2),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Colors.red, width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Submit button with Breathing Glow
                              AnimatedBuilder(
                                animation: _glowController,
                                builder: (context, child) {
                                  double elevation = 6.0 + (_glowController.value * 2.0);
                                  double blurRadius = 24.0 + (_glowController.value * 12.0);
                                  double spreadRadius = 0.0 + (_glowController.value * 6.0);
                                  Color glowColor = AppTheme.primary.withOpacity(0.35 + (_glowController.value * 0.20));

                                  return Container(
                                    height: 52,
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
                                  onPressed: (_isLoading || isMismatch) ? null : _handleSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Creating account...',
                                              style: AppTheme.sansFont(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Get Started',
                                              style: AppTheme.sansFont(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Divider
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: AppTheme.outline)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      'OR',
                                      style: AppTheme.sansFont(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textLight,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(color: AppTheme.outline)),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Google button
                              OutlinedButton(
                                onPressed: () => widget.onSignUp('Google User'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  side: const BorderSide(color: AppTheme.outline, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                      height: 20,
                                      width: 20,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Continue with Google',
                                      style: AppTheme.sansFont(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Toggle Link to SignIn
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTheme.sansFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onNavigateToSignIn,
                            child: Text(
                              'Sign In',
                              style: AppTheme.sansFont(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: InnovativeBackButton(onTap: widget.onBack),
          ),
        ],
      ),
    );
  }
}


