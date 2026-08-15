import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/innovative_back_button.dart';
import '../components/wavy_bottom_nav_bar.dart';

class _Message {
  final String id, text, timestamp;
  final bool isUser;
  final Map<String, dynamic>? dataCard;
  const _Message({required this.id, required this.text, required this.timestamp, required this.isUser, this.dataCard});
}

class ChatScreen extends StatefulWidget {
  final VoidCallback onBack;
  final int latestHrv;
  final double latestBmi;
  final String? initialMessage;
  final VoidCallback onNavigateToHome;
  final VoidCallback onNavigateToDiary;
  final VoidCallback onStartScan;
  final VoidCallback onNavigateToProfile;

  const ChatScreen({
    super.key,
    required this.onBack,
    this.latestHrv = 48,
    this.latestBmi = 21.7,
    this.initialMessage,
    required this.onNavigateToHome,
    required this.onNavigateToDiary,
    required this.onStartScan,
    required this.onNavigateToProfile,
  });
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatSession {
  final String id;
  String title;
  final String subtitle;
  final IconData icon;
  final List<_Message> messages;

  _ChatSession({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.messages,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _typing = false;
  
  late List<_Message> _msgs;
  String? _activeSessionId;
  late List<_ChatSession> _sessions;

  // Static lifecycle persistence fields
  static List<_ChatSession>? _persistedSessions;
  static String? _persistedActiveSessionId;
  static List<_Message>? _persistedMsgs;

  @override
  void initState() {
    super.initState();
    
    // Initialize persisted state if first entry
    if (_persistedSessions == null) {
      _persistedSessions = [
        _ChatSession(
          id: 'hrv',
          title: 'HRV Recovery Discussion',
          subtitle: 'Explored low HRV values',
          icon: Icons.favorite_rounded,
          messages: [
            _Message(id: 'h1', isUser: true, text: "Can you explain my recent HRV reading?", timestamp: '10:15 AM'),
            _Message(id: 'h2', isUser: false, text: "Heart Rate Variability (HRV) measures the variation in time between each heartbeat. Your latest reading is 48ms, which is slightly low. Focus on rest today.", timestamp: '10:15 AM',
              dataCard: {'label': 'LATEST HRV', 'value': widget.latestHrv, 'unit': 'ms', 'type': 'down'}),
          ],
        ),
        _ChatSession(
          id: 'bmi',
          title: 'BMI Normal Ranges',
          subtitle: 'Checked healthy limits',
          icon: Icons.scale_rounded,
          messages: [
            _Message(id: 'm1', isUser: true, text: "What is my BMI and is it healthy?", timestamp: 'Yesterday'),
            _Message(id: 'm2', isUser: false, text: "Your BMI is ${widget.latestBmi}, which is in the healthy Normal Range. Keep maintaining your active lifestyle!", timestamp: 'Yesterday',
              dataCard: {'label': 'YOUR BMI', 'value': widget.latestBmi, 'unit': '', 'type': 'normal'}),
          ],
        ),
        _ChatSession(
          id: 'bp',
          title: 'Lowering Blood Pressure',
          subtitle: 'Dietary and exercise tips',
          icon: Icons.heart_broken_rounded,
          messages: [
            _Message(id: 'b1', isUser: true, text: "How to lower blood pressure?", timestamp: '2 days ago'),
            _Message(id: 'b2', isUser: false, text: "To maintain healthy blood pressure, engage in regular cardiovascular exercise, reduce sodium intake, and manage stress.", timestamp: '2 days ago',
              dataCard: {'label': 'BP TARGET', 'value': '120/80', 'unit': 'mmHg', 'type': 'normal'}),
          ],
        ),
        _ChatSession(
          id: 'breath',
          title: 'Daily Breathing Routine',
          subtitle: 'Learned box breathing technique',
          icon: Icons.air_rounded,
          messages: [
            _Message(id: 'br1', isUser: true, text: "Show me breathing exercises", timestamp: '3 days ago'),
            _Message(id: 'br2', isUser: false, text: "Box Breathing exercise:\n1. Inhale for 4 seconds.\n2. Hold for 4 seconds.\n3. Exhale for 4 seconds.\n4. Hold for 4 seconds.\nRepeat to calm your nervous system.", timestamp: '3 days ago'),
          ],
        ),
      ];
      _persistedMsgs = [];
      _persistedActiveSessionId = null;
    }

    _sessions = _persistedSessions!;
    _msgs = _persistedMsgs!;
    _activeSessionId = _persistedActiveSessionId;
    
    // If navigated with a pre-defined prompt, execute it immediately
    if (widget.initialMessage != null) {
      Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _send(widget.initialMessage!);
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final now = TimeOfDay.now();
    final ts = '${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period.name.toUpperCase()}';
    
    // Create new session if no active session
    if (_activeSessionId == null) {
      final newId = '${DateTime.now().millisecondsSinceEpoch}';
      String title = text.length > 22 ? '${text.substring(0, 20)}...' : text;
      final newSession = _ChatSession(
        id: newId,
        title: title,
        subtitle: 'Active Chat',
        icon: Icons.chat_bubble_rounded,
        messages: [],
      );
      setState(() {
        _sessions.insert(0, newSession);
        _activeSessionId = newId;
        _persistedActiveSessionId = newId;
      });
    }

    final userMsg = _Message(id: '${DateTime.now().millisecondsSinceEpoch}', isUser: true, text: text, timestamp: ts);
    
    setState(() {
      _msgs.add(userMsg);
      final currentSession = _sessions.firstWhere((s) => s.id == _activeSessionId);
      currentSession.messages.add(userMsg);
      _ctrl.clear();
      _typing = true;
    });
    _scrollToBottom();
    
    Timer(const Duration(milliseconds: 1500), () {
      final norm = text.toLowerCase();
      String reply = "I hear you. Regular checkups and rest are key to keeping your metrics in check.";
      Map<String, dynamic>? card;
      if (norm.contains('exercise') || norm.contains('yes')) {
        reply = "Box Breathing exercise:\n1. Inhale slowly through your nose for 4 seconds.\n2. Hold your breath for 4 seconds.\n3. Exhale fully for 4 seconds.\n4. Hold for 4 seconds.\nRepeat 4 times to calm your nervous system.";
      } else if (norm.contains('bmi')) {
        reply = "Your BMI is currently ${widget.latestBmi}, which is in the healthy Normal Range.";
        card = {'label': 'YOUR BMI', 'value': widget.latestBmi, 'unit': '', 'type': 'normal'};
      } else if (norm.contains('blood pressure') || norm.contains('pressure') || norm.contains('lower')) {
        reply = "To maintain healthy blood pressure:\n• Eat whole grains, fruits, and vegetables.\n• Reduce sodium intake.\n• Engage in daily walking.\n• Manage stress through meditation.";
        card = {'label': 'BP TARGET', 'value': '120/80', 'unit': 'mmHg', 'type': 'normal'};
      }
      
      final botMsg = _Message(id: '${DateTime.now().millisecondsSinceEpoch}', isUser: false, text: reply, timestamp: ts, dataCard: card);
      
      setState(() {
        _typing = false;
        _msgs.add(botMsg);
        final currentSession = _sessions.firstWhere((s) => s.id == _activeSessionId);
        currentSession.messages.add(botMsg);
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _loadHistorySession(String id) {
    setState(() {
      _activeSessionId = id;
      _persistedActiveSessionId = id;
      final session = _sessions.firstWhere((s) => s.id == id);
      _msgs.clear();
      _msgs.addAll(session.messages);
    });
    _scrollToBottom();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 120),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4BF).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF0D9488),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Start a conversation with Healio",
            style: AppTheme.sansFont(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Ask health questions, check biometric analysis, or get recovery advice instantly.",
              textAlign: TextAlign.center,
              style: AppTheme.sansFont(
                fontSize: 12,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2DD4BF).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2DD4BF), size: 18),
        ),
        title: Text(
          title,
          style: AppTheme.sansFont(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.sansFont(
            fontSize: 10,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      endDrawer: Drawer(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent History',
                      style: AppTheme.sansFont(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, idx) {
                          final session = _sessions[idx];
                          return _buildHistoryItem(
                            title: session.title,
                            subtitle: session.subtitle,
                            icon: session.icon,
                            onTap: () {
                              _loadHistorySession(session.id);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Center Fixed Background Image
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(
                  'chatbot_bg.jpg',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 2. Light Theme Gradient Overlay for blending
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEFF6FF).withOpacity(0.70),
                    Colors.white.withOpacity(0.78),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 3. UI Content
          Positioned.fill(
            child: Column(
              children: [
                // Header (Glassmorphic)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: Colors.white.withOpacity(0.65),
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 12,
                              child: GestureDetector(
                                onTap: widget.onBack,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.55),
                                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                                  ),
                                  child: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1E293B), size: 20),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Hea',
                                        style: AppTheme.sansFont(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F766E),
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'lio',
                                        style: AppTheme.sansFont(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF2DD4BF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              right: 16,
                              child: GestureDetector(
                                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.55),
                                    border: Border.all(color: Colors.white.withOpacity(0.8)),
                                  ),
                                  child: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B), size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _msgs.isEmpty ? 1 : _msgs.length + (_typing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (_msgs.isEmpty) {
                        return _buildEmptyState();
                      }
                      final msgIndex = i;
                      if (msgIndex == _msgs.length && _typing) {
                        return _TypingIndicator();
                      }
                      if (msgIndex >= _msgs.length) return const SizedBox.shrink();
                      return _MessageBubble(msg: _msgs[msgIndex]);
                    },
                  ),
                ),

                // Suggested actions (show only when chat is empty to start thread)
                if (_msgs.isEmpty)
                  ClipRect(
                    child: Container(
                      color: Colors.transparent,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(children: [
                          _SuggestChip('Yes, show me exercises', () => _send('Yes, show me exercises')),
                          const SizedBox(width: 8),
                          _SuggestChip('What is my BMI?', () => _send('What is my BMI?')),
                          const SizedBox(width: 8),
                          _SuggestChip('How to lower blood pressure?', () => _send('How to lower blood pressure?')),
                        ]),
                      ),
                    ),
                  ),

                // Input bar (Glassmorphic small rectangle floating card)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 76 + MediaQuery.of(context).padding.bottom),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2DD4BF),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                style: GoogleFonts.hankenGrotesk(fontSize: 14, color: const Color(0xFF1E293B)),
                                decoration: InputDecoration(
                                  hintText: 'Ask Healio anything...',
                                  hintStyle: GoogleFonts.hankenGrotesk(fontSize: 14, color: const Color(0xFF64748B)),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: _send,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _send(_ctrl.text),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2DD4BF),
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: WavyBottomNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i == 0) widget.onNavigateToHome();
          if (i == 1) widget.onNavigateToDiary();
          if (i == 2) widget.onStartScan();
          if (i == 3) {}
          if (i == 4) widget.onNavigateToProfile();
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final glassBg = isUser 
        ? const Color(0xFF0F766E).withOpacity(0.85)
        : Colors.white.withOpacity(0.84);
    final glassBorder = isUser 
        ? const Color(0xFF2DD4BF).withOpacity(0.3)
        : const Color(0xFF94A3B8).withOpacity(0.4);
    final textColor = isUser 
        ? Colors.white 
        : const Color(0xFF1E293B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE0F2FE).withOpacity(0.7), child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF0EA5E9))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: glassBg,
                        border: Border.all(color: glassBorder, width: 1.0),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                          bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.text, style: GoogleFonts.hankenGrotesk(fontSize: 14, color: textColor, height: 1.5, fontWeight: isUser ? FontWeight.w500 : FontWeight.w600)),
                          if (msg.dataCard != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.8))),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(msg.dataCard!['label'], style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.8)),
                                    const SizedBox(height: 2),
                                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                                      Text('${msg.dataCard!['value']}', style: GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      if ((msg.dataCard!['unit'] as String).isNotEmpty) ...[const SizedBox(width: 2), Text(msg.dataCard!['unit'], style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))],
                                    ]),
                                  ]),
                                  Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: msg.dataCard!['type'] == 'down' ? const Color(0xFFFEF2F2).withOpacity(0.8) : const Color(0xFFF0FDF4).withOpacity(0.8),
                                      border: Border.all(color: msg.dataCard!['type'] == 'down' ? const Color(0xFFFECACA).withOpacity(0.8) : const Color(0xFFBBF7D0).withOpacity(0.8)),
                                    ),
                                    child: Icon(msg.dataCard!['type'] == 'down' ? Icons.trending_down : Icons.trending_flat,
                                      color: msg.dataCard!['type'] == 'down' ? Colors.red : Colors.green, size: 18),
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
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFF3F4F6).withOpacity(0.7), child: const Icon(Icons.person, size: 16, color: Color(0xFF6B7280))),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override State<_TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>> _anims;
  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true));
    _anims = List.generate(3, (i) => CurvedAnimation(parent: _ctrls[i], curve: Curves.easeInOut));
    for (int i = 0; i < 3; i++) Future.delayed(Duration(milliseconds: i * 200), () { if (mounted) _ctrls[i].repeat(reverse: true); });
  }
  @override void dispose() { for (final c in _ctrls) c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(children: [
      CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE0F2FE).withOpacity(0.7), child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF0EA5E9))),
      const SizedBox(width: 8),
      ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.68),
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.0),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Row(children: List.generate(3, (i) => AnimatedBuilder(
              animation: _anims[i],
              builder: (_, __) => Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(shape: BoxShape.circle, color: Color.lerp(const Color(0xFF94A3B8), const Color(0xFF475569), _anims[i].value))),
            ))),
          ),
        ),
      ),
    ]),
  );
}

class _SuggestChip extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SuggestChip(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.48), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white.withOpacity(0.7))
          ),
          child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
        ),
      ),
    ),
  );
}
