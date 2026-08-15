import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../components/innovative_back_button.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback onSignIn;
  final VoidCallback onNavigateToSignUp;
  final VoidCallback onBack;

  const SignInScreen({
    super.key,
    required this.onSignIn,
    required this.onNavigateToSignUp,
    required this.onBack,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'hemkumarr2803@gmail.com');
  final _passwordController = TextEditingController(text: 'hem@1234');

  bool _showPassword = false;
  bool _isLoading = false;
  String? _focusedField;

  // Background orbs animation controllers
  late AnimationController _orbController;
  // Button breathing glow controllers
  late AnimationController _glowController;
  // Pulsing heart logo controller
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
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      List<String> loginEndpoints = [
        'http://192.168.10.133:8000/api/v1/auth/login',
        'http://127.0.0.1:8000/api/v1/auth/login',
        'http://10.0.2.2:8000/api/v1/auth/login',
        'http://localhost:8000/api/v1/auth/login',
      ];

      bool success = false;
      String errorMsg = 'Invalid email or password.';

      for (final endpoint in loginEndpoints) {
        try {
          final res = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            }),
          ).timeout(const Duration(seconds: 4));

          if (res.statusCode == 200) {
            success = true;
            break;
          } else {
            final errBody = jsonDecode(res.body);
            errorMsg = errBody['detail'] ?? 'Login failed';
          }
        } catch (e) {
          debugPrint('Login error at $endpoint: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful! Welcome back.'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSignIn();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Media queries for screen sizing
    final size = MediaQuery.of(context).size;

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
                    top: -40 + (22 * math.sin(angle)),
                    right: -40 + (18 * math.cos(angle)),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                  // Orb 2
                  Positioned(
                    top: (size.height / 2) + (16 * math.cos(angle)),
                    left: -80 + (20 * math.sin(angle)),
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2FD9F4).withOpacity(0.10),
                      ),
                    ),
                  ),
                  // Orb 3
                  Positioned(
                    bottom: 80 + (20 * math.sin(angle + 1.0)),
                    right: -20 + (10 * math.cos(angle + 1.0)),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF22D3EE).withOpacity(0.12),
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
                      const SizedBox(height: 32),

                      // Heart Icon + Heading
                      Column(
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse ring
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 80 + (_pulseController.value * 28),
                                      height: 80 + (_pulseController.value * 28),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: AppTheme.primary.withOpacity(0.3 * (1.0 - _pulseController.value)),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Core logo box
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.primary, Color(0xFF00ACC1)],
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
                                    Icons.monitor_heart,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Welcome back',
                            style: AppTheme.sansFont(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue your health journey',
                            style: AppTheme.sansFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

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
                              // Email Input
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

                              // Password Input
                              Focus(
                                onFocusChange: (hasFocus) {
                                  setState(() {
                                    _focusedField = hasFocus ? 'password' : null;
                                  });
                                },
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
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
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Forgot Password Link
                              Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Text(
                                    'Forgot password?',
                                    style: AppTheme.sansFont(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Submit Button with Breathing Glow
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
                                  onPressed: _isLoading ? null : _handleSubmit,
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
                                              'Signing in...',
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
                                              'Sign In',
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

                              // Google Login Button
                              OutlinedButton(
                                onPressed: widget.onSignIn,
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

                      // Toggle Link to SignUp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account? ',
                            style: AppTheme.sansFont(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onNavigateToSignUp,
                            child: Text(
                              'Sign Up',
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


