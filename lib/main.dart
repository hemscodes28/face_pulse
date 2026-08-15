import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/landing_screen.dart';
import 'screens/signin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/measurement_screen.dart';
import 'screens/results_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const CareForApp());
}

class CareForApp extends StatelessWidget {
  const CareForApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Pulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2DD4BF)),
        textTheme: GoogleFonts.hankenGroteskTextTheme(),
        useMaterial3: true,
      ),
      home: const AppRouter(),
    );
  }
}

enum AppScreen { landing, signIn, signUp, onboarding, home, measurement, results, diary, chat, profile }

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});
  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  AppScreen _screen = AppScreen.landing;
  MeasurementMetrics? _lastMetrics;
  int _latestHrv = 48;
  double _latestBmi = 21.7;
  bool _hasSeenIntro = false;
  String? _initialChatMessage;

  String _userName = 'Hem Kumar';
  final List<MeasurementMetrics> _scanHistory = [];

  void _go(AppScreen screen) => setState(() => _screen = screen);

  @override
  Widget build(BuildContext context) {
    switch (_screen) {
      case AppScreen.landing:
        return LandingScreen(
          onLogin: () => _go(AppScreen.signIn),
          onConnect: () => _go(AppScreen.signUp),
          showIntro: !_hasSeenIntro,
          onIntroComplete: () {
            _hasSeenIntro = true;
          },
        );

      case AppScreen.signIn:
        return SignInScreen(
          onSignIn: () {
            setState(() {
              _scanHistory.clear();
              _userName = 'Hem Kumar';
            });
            _go(AppScreen.home);
          },
          onNavigateToSignUp: () => _go(AppScreen.signUp),
          onBack: () => _go(AppScreen.landing),
        );

      case AppScreen.signUp:
        return SignUpScreen(
          onSignUp: (name) {
            setState(() {
              _scanHistory.clear();
              _userName = name.isNotEmpty ? name : 'Hem Kumar';
            });
            _go(AppScreen.onboarding);
          },
          onNavigateToSignIn: () => _go(AppScreen.signIn),
          onBack: () => _go(AppScreen.landing),
        );

      case AppScreen.onboarding:
        return OnboardingScreen(
          onComplete: (profile) => _go(AppScreen.home),
          onBack: () => _go(AppScreen.landing),
        );

      case AppScreen.home:
        return HomeScreen(
          userName: _userName,
          onStartScan: () => _go(AppScreen.measurement),
          onNavigateToChat: (msg) {
            setState(() {
              _initialChatMessage = msg;
              _screen = AppScreen.chat;
            });
          },
          onNavigateToDiary: () => _go(AppScreen.diary),
          onNavigateToProfile: () => _go(AppScreen.profile),
        );

      case AppScreen.measurement:
        return MeasurementScreen(
          onBack: () => _go(AppScreen.home),
          onScanComplete: (metrics) {
            setState(() {
              _lastMetrics = metrics;
              _scanHistory.add(metrics); // Save the scan metrics to history
              _latestHrv = metrics.hrv;
              _latestBmi = metrics.bmi;
              _screen = AppScreen.results;
            });
          },
        );

      case AppScreen.results:
        return ResultsScreen(
          metrics: _lastMetrics ?? const MeasurementMetrics(
            pulse: 75, sys: 117, dia: 74, hrv: 48,
            breath: 22, stress: 2.0, workload: 145, para: 32, bmi: 21.7,
          ),
          onFinish: () => _go(AppScreen.home),
          onMeasureAgain: () => _go(AppScreen.measurement),
        );

      case AppScreen.diary:
        return DiaryScreen(
          onBack: () => _go(AppScreen.home),
          scanHistory: _scanHistory,
          onNavigateToHome: () => _go(AppScreen.home),
          onStartScan: () => _go(AppScreen.measurement),
          onNavigateToChat: (msg) {
            setState(() {
              _initialChatMessage = msg;
              _screen = AppScreen.chat;
            });
          },
          onNavigateToProfile: () => _go(AppScreen.profile),
        );

      case AppScreen.chat:
        final msg = _initialChatMessage;
        _initialChatMessage = null;
        return ChatScreen(
          onBack: () => _go(AppScreen.home),
          latestHrv: _latestHrv,
          latestBmi: _latestBmi,
          initialMessage: msg,
          onNavigateToHome: () => _go(AppScreen.home),
          onNavigateToDiary: () => _go(AppScreen.diary),
          onStartScan: () => _go(AppScreen.measurement),
          onNavigateToProfile: () => _go(AppScreen.profile),
        );

      case AppScreen.profile:
        return ProfileScreen(
          onBack: () => _go(AppScreen.home),
          onSignOut: () => _go(AppScreen.landing),
          onNavigateToHome: () => _go(AppScreen.home),
          onNavigateToDiary: () => _go(AppScreen.diary),
          onStartScan: () => _go(AppScreen.measurement),
          onNavigateToChat: (msg) {
            setState(() {
              _initialChatMessage = msg;
              _screen = AppScreen.chat;
            });
          },
        );
    }
  }
}
