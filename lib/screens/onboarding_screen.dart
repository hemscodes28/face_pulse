import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../components/innovative_back_button.dart';

class OnboardingScreen extends StatefulWidget {
  final Function(Map<String, dynamic> profile) onComplete;
  final VoidCallback onBack;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  int _step = 0;
  bool _animating = false;

  // Background orbs controller
  late AnimationController _orbController;
  // Button breathing glow controller
  late AnimationController _glowController;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 1: Personal (DOB & Gender) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late int _dobDay;
  late int _dobMonth;
  late int _dobYear;
  String? _dobEditField; // 'day', 'year', or null
  final _dayInputController = TextEditingController();
  final _yearInputController = TextEditingController();
  String _gender = '';

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 2: Body (Height & Weight) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightFocusNode = FocusNode();
  final _weightFocusNode = FocusNode();
  bool _heightHovered = false;
  bool _weightHovered = false;
  double? _bmi;

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 3: Medical (Blood Group) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _bloodGroup = '';

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'Aâˆ’', 'B+', 'Bâˆ’', 'AB+', 'ABâˆ’', 'O+', 'Oâˆ’'];
  final List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    
    // Initialize DOB state to today's date dynamically
    final now = DateTime.now();
    _dobDay = now.day;
    _dobMonth = now.month;
    _dobYear = now.year;

    _orbController = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    // Listeners for focus transitions to hide cm/kg labels
    _heightFocusNode.addListener(() => setState(() {}));
    _weightFocusNode.addListener(() => setState(() {}));

    // Listeners for height and weight to calculate BMI
    _heightController.addListener(_calculateBmi);
    _weightController.addListener(_calculateBmi);
  }

  @override
  void dispose() {
    _orbController.dispose();
    _glowController.dispose();
    _nameFocusDispose();
    super.dispose();
  }

  void _nameFocusDispose() {
    _heightFocusNode.dispose();
    _weightFocusNode.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dayInputController.dispose();
    _yearInputController.dispose();
  }

  int? get _age {
    final today = DateTime.now();
    final birth = DateTime(_dobYear, _dobMonth, _dobDay);
    int age = today.year - birth.year;
    if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return (age >= 0 && age < 130) ? age : null;
  }

  void _calculateBmi() {
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);
    if (h != null && w != null && h > 0 && w > 0) {
      final hm = h / 100.0;
      setState(() {
        _bmi = double.parse((w / (hm * hm)).toStringAsFixed(1));
      });
    } else {
      setState(() {
        _bmi = null;
      });
    }
  }

  Map<String, dynamic> _getBmiCategory(double bmi) {
    if (bmi < 18.5) {
      return {'label': 'Underweight', 'color': Colors.orange, 'bg': const Color(0xFFFEF3C7)};
    } else if (bmi < 25.0) {
      return {'label': 'Healthy', 'color': Colors.green, 'bg': const Color(0xFFDCFCE7)};
    } else if (bmi < 30.0) {
      return {'label': 'Overweight', 'color': Colors.orange.shade700, 'bg': const Color(0xFFFFEDD5)};
    } else {
      return {'label': 'Obese', 'color': Colors.red, 'bg': const Color(0xFFFEE2E2)};
    }
  }

  void _goNext() {
    if (_animating) return;
    setState(() {
      _animating = true;
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() {
          _step++;
          _animating = false;
        });
      }
    });
  }

  void _goBack() {
    if (_animating) return;
    setState(() {
      _animating = true;
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() {
          _step--;
          _animating = false;
        });
      }
    });
  }

  void _handleFinish() {
    widget.onComplete({
      'dob': '$_dobDay/$_dobMonth/$_dobYear',
      'age': _age ?? 0,
      'gender': _gender,
      'heightCm': double.tryParse(_heightController.text) ?? 0.0,
      'weightKg': double.tryParse(_weightController.text) ?? 0.0,
      'bmi': _bmi ?? 0.0,
      'bloodGroup': _bloodGroup,
    });
  }

  bool _canAdvance() {
    if (_step == 0) return _age != null && _gender.isNotEmpty;
    if (_step == 1) {
      final h = double.tryParse(_heightController.text);
      final w = double.tryParse(_weightController.text);
      return h != null && w != null && h > 0 && w > 0;
    }
    if (_step == 2) return _bloodGroup.isNotEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // â”€â”€ Background Orbs â”€â”€
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              final angle = _orbController.value * 2 * math.pi;
              return Stack(
                children: [
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
                  Positioned(
                    bottom: 120 + (20 * math.cos(angle)),
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
                ],
              );
            },
          ),

          // â”€â”€ Scrollable Body Content â”€â”€
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // â”€â”€ Step Progress Indicator â”€â”€
                            _buildStepProgress(),

                            const SizedBox(height: 24),

                            // â”€â”€ Active Step Card â”€â”€
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              child: Container(
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
                                child: _buildStepContent(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // â”€â”€ Bottom Fixed Action Buttons â”€â”€
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32, top: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              final elevation = 6.0 + (_glowController.value * 2.0);
                              final blurRadius = 24.0 + (_glowController.value * 12.0);
                              final spreadRadius = 0.0 + (_glowController.value * 6.0);
                              final glowColor = _canAdvance()
                                  ? AppTheme.primary.withOpacity(0.35 + (_glowController.value * 0.20))
                                  : Colors.transparent;

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
                              onPressed: _canAdvance()
                                  ? (_step < 2 ? _goNext : _handleFinish)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                disabledBackgroundColor: AppTheme.primary.withOpacity(0.40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _step < 2 ? 'Continue' : 'Start my journey',
                                    style: AppTheme.sansFont(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _step < 2 ? Icons.arrow_forward : Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_step > 0) ...[
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _goBack,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                side: const BorderSide(color: AppTheme.outline, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.arrow_back, color: AppTheme.textMedium, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Back',
                                    style: AppTheme.sansFont(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: InnovativeBackButton(
              onTap: () {
                if (_step > 0) {
                  _goBack();
                } else {
                  widget.onBack();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    final List<Map<String, dynamic>> steps = [
      {'icon': Icons.person, 'label': 'About you'},
      {'icon': Icons.straighten, 'label': 'Body'},
      {'icon': Icons.water_drop, 'label': 'Medical'},
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(steps.length, (i) {
            final isCompleted = i < _step;
            final isActive = i == _step;
            
            Color circleBg = const Color(0xFFE2E8F0);
            Border? circleBorder;
            Color iconColor = const Color(0xFF94A3B8);

            if (isCompleted) {
              circleBg = const Color(0xFF1E3A5F);
              iconColor = Colors.white;
            } else if (isActive) {
              circleBg = const Color(0xFFECFEFF);
              circleBorder = Border.all(color: AppTheme.primary, width: 2);
              iconColor = AppTheme.primary;
            }

            return Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 32 : 28,
                  height: isActive ? 32 : 28,
                  decoration: BoxDecoration(
                    color: circleBg,
                    border: circleBorder,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [const BoxShadow(color: Color(0x2E006877), spreadRadius: 4)]
                        : null,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : steps[i]['icon'],
                    color: iconColor,
                    size: 14,
                  ),
                ),
                if (i < steps.length - 1)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 32,
                    height: 2,
                    color: i < _step ? AppTheme.primary : const Color(0xFFE2E8F0),
                  ),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(
          'STEP ${_step + 1} OF ${steps.length}',
          style: AppTheme.sansFont(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _step == 0
              ? 'Tell us about yourself'
              : _step == 1
                  ? 'Your body measurements'
                  : 'Medical details',
          style: AppTheme.sansFont(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox();
    }
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 0: Personal â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE OF BIRTH',
          style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMedium, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),

        // Drum Steppers Row
        Row(
          children: [
            Expanded(child: _buildDayStepper()),
            const SizedBox(width: 10),
            Expanded(child: _buildMonthStepper()),
            const SizedBox(width: 10),
            Expanded(child: _buildYearStepper()),
          ],
        ),

        // Live Age Card
        if (_age != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary.withOpacity(0.08), const Color(0xFFECFEFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.38),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cake, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR AGE',
                      style: AppTheme.sansFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_age ',
                            style: AppTheme.sansFont(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary),
                          ),
                          TextSpan(
                            text: 'years old',
                            style: AppTheme.sansFont(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMedium),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        Text(
          'GENDER',
          style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMedium, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),

        Row(
          children: _genders.map((g) {
            final isSelected = _gender == g;
            final IconData icon = g == 'Male' ? Icons.male : g == 'Female' ? Icons.female : Icons.person_outline;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => setState(() => _gender = g),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : AppTheme.outline,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textLight, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          g,
                          style: AppTheme.sansFont(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.primary : AppTheme.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDayStepper() {
    final isEditing = _dobEditField == 'day';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEditing || _dobDay != 0 ? AppTheme.primary : AppTheme.outline, width: 2),
      ),
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_less, size: 20),
            onPressed: () => setState(() {
              _dobDay = (_dobDay % 31) + 1;
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: isEditing
                ? TextFormField(
                    initialValue: _dobDay.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: AppTheme.sansFont(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onFieldSubmitted: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 1 && parsed <= 31) {
                        setState(() {
                          _dobDay = parsed;
                          _dobEditField = null;
                        });
                      } else {
                        setState(() {
                          _dobEditField = null;
                        });
                      }
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _dobEditField = 'day'),
                    child: Text(
                      _dobDay.toString().padLeft(2, '0'),
                      style: AppTheme.sansFont(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
          ),
          Text(
            'Day',
            style: AppTheme.sansFont(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
          ),
          IconButton(
            icon: const Icon(Icons.expand_more, size: 20),
            onPressed: () => setState(() {
              _dobDay = _dobDay - 1 < 1 ? 31 : _dobDay - 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStepper() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_less, size: 20),
            onPressed: () => setState(() {
              _dobMonth = (_dobMonth % 12) + 1;
            }),
          ),
          Text(
            _months[_dobMonth - 1],
            style: AppTheme.sansFont(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          Text(
            'Month',
            style: AppTheme.sansFont(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
          ),
          IconButton(
            icon: const Icon(Icons.expand_more, size: 20),
            onPressed: () => setState(() {
              _dobMonth = _dobMonth - 1 < 1 ? 12 : _dobMonth - 1;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildYearStepper() {
    final isEditing = _dobEditField == 'year';
    final currentYear = DateTime.now().year;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isEditing || _dobYear != 0 ? AppTheme.primary : AppTheme.outline, width: 2),
      ),
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.expand_less, size: 20),
            onPressed: () => setState(() {
              _dobYear = math.min(_dobYear + 1, currentYear);
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: isEditing
                ? TextFormField(
                    initialValue: _dobYear.toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: AppTheme.sansFont(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    onFieldSubmitted: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= currentYear - 120 && parsed <= currentYear) {
                        setState(() {
                          _dobYear = parsed;
                          _dobEditField = null;
                        });
                      } else {
                        setState(() {
                          _dobEditField = null;
                        });
                      }
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _dobEditField = 'year'),
                    child: Text(
                      _dobYear.toString(),
                      style: AppTheme.sansFont(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
          ),
          Text(
            'Year',
            style: AppTheme.sansFont(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.8),
          ),
          IconButton(
            icon: const Icon(Icons.expand_more, size: 20),
            onPressed: () => setState(() {
              _dobYear = math.max(_dobYear - 1, currentYear - 120);
            }),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 1: Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep1() {
    final showCm = !_heightFocusNode.hasFocus && !_heightHovered;
    final showKg = !_weightFocusNode.hasFocus && !_weightHovered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Height Input
        MouseRegion(
          onEnter: (_) => setState(() => _heightHovered = true),
          onExit: (_) => setState(() => _heightHovered = false),
          child: Focus(
            onFocusChange: (hasFocus) => setState(() {}),
            child: TextFormField(
              controller: _heightController,
              focusNode: _heightFocusNode,
              keyboardType: TextInputType.number,
              style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: AppTheme.inputDecoration(
                labelText: 'Height',
                prefixIcon: Icons.height,
                isFocused: _heightFocusNode.hasFocus,
                suffixIcon: showCm
                    ? const Align(
                        widthFactor: 1.0,
                        alignment: Alignment.center,
                        child: Text('cm', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    : null,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Weight Input
        MouseRegion(
          onEnter: (_) => setState(() => _weightHovered = true),
          onExit: (_) => setState(() => _weightHovered = false),
          child: Focus(
            onFocusChange: (hasFocus) => setState(() {}),
            child: TextFormField(
              controller: _weightController,
              focusNode: _weightFocusNode,
              keyboardType: TextInputType.number,
              style: AppTheme.sansFont(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: AppTheme.inputDecoration(
                labelText: 'Weight',
                prefixIcon: Icons.monitor_weight_outlined,
                isFocused: _weightFocusNode.hasFocus,
                suffixIcon: showKg
                    ? const Align(
                        widthFactor: 1.0,
                        alignment: Alignment.center,
                        child: Text('kg', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    : null,
              ),
            ),
          ),
        ),

        // Dynamic BMI Gauge Card
        if (_bmi != null) ...[
          const SizedBox(height: 20),
          _buildBmiCard(),
        ],
      ],
    );
  }

  Widget _buildBmiCard() {
    final cat = _getBmiCategory(_bmi!);
    final double bmiVal = _bmi!;
    final double pct = math.min(math.max((bmiVal - 10) / 35.0, 0.0), 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cat['bg'] as Color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (cat['color'] as Color).withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMI SCORE',
                    style: AppTheme.sansFont(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMedium, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bmi.toString(),
                    style: AppTheme.sansFont(fontSize: 28, fontWeight: FontWeight.w800, color: cat['color'] as Color),
                  ),
                ],
              ),
              Chip(
                label: Text(
                  cat['label'] as String,
                  style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: cat['color'] as Color,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal gauge slider
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              color: Colors.black.withOpacity(0.08),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cat['color'] as Color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['10', '18.5', '25', '30', '45'].map((v) {
              return Text(v, style: AppTheme.sansFont(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.textMedium));
            }).toList(),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ STEP 2: Medical â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'BLOOD GROUP',
          style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMedium, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),

        // Grid selection
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: _bloodGroups.length,
          itemBuilder: (context, idx) {
            final bg = _bloodGroups[idx];
            final isSelected = _bloodGroup == bg;
            return InkWell(
              onTap: () => setState(() => _bloodGroup = bg),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.outline,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  bg,
                  style: AppTheme.sansFont(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ),
            );
          },
        ),

        if (_bloodGroup.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSummaryCard(),
        ],
      ],
    );
  }

  Widget _buildSummaryCard() {
    final cat = _bmi != null ? _getBmiCategory(_bmi!) : null;
    final List<Map<String, dynamic>> summaryData = [
      {'icon': Icons.cake, 'label': 'Date of Birth', 'value': '$_dobDay/$_dobMonth/$_dobYear'},
      {'icon': Icons.person, 'label': 'Age', 'value': _age != null ? '$_age years' : 'â€”'},
      {'icon': Icons.wc, 'label': 'Gender', 'value': _gender},
      {'icon': Icons.height, 'label': 'Height', 'value': '${_heightController.text} cm'},
      {'icon': Icons.monitor_weight_outlined, 'label': 'Weight', 'value': '${_weightController.text} kg'},
      {'icon': Icons.speed, 'label': 'BMI', 'value': _bmi != null ? '$_bmi â€“ ${cat?['label']}' : 'â€”'},
      {'icon': Icons.water_drop, 'label': 'Blood Group', 'value': _bloodGroup},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PROFILE SUMMARY',
            style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1.0),
          ),
          const SizedBox(height: 12),
          Column(
            children: summaryData.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(item['icon'] as IconData, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        item['label'] as String,
                        style: AppTheme.sansFont(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMedium),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item['value'] as String,
                        style: AppTheme.sansFont(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

