import 'dart:async';
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

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _typing = false;
  late List<_Message> _msgs;

  @override
  void initState() {
    super.initState();
    _msgs = [
      _Message(id: '1', isUser: false, text: "Hello! I'm your Shen AI Health Assistant. How can I help you understand your biometrics today?", timestamp: '9:41 AM'),
    ];
    if (widget.initialMessage != null) {
      Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _send(widget.initialMessage!);
        }
      });
    } else {
      _msgs.addAll([
        _Message(id: '2', isUser: true, text: "Can you explain my recent HRV reading? It was lower than usual.", timestamp: '9:42 AM'),
        _Message(id: '3', isUser: false, text: "Certainly. Heart Rate Variability (HRV) measures the variation in time between each heartbeat. A lower HRV can sometimes indicate stress, fatigue, or recovery needs.", timestamp: '9:42 AM',
          dataCard: {'label': 'LATEST HRV', 'value': widget.latestHrv, 'unit': 'ms', 'type': widget.latestHrv < 50 ? 'down' : 'normal'}),
        _Message(id: '4', isUser: false, text: "Given it dropped slightly, you might want to focus on rest today. Would you like some guided breathing exercises to help improve it?", timestamp: '9:42 AM'),
      ]);
    }
  }

  @override void dispose() { _ctrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final now = TimeOfDay.now();
    final ts = '${now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period.name.toUpperCase()}';
    setState(() {
      _msgs.add(_Message(id: '${DateTime.now().millisecondsSinceEpoch}', isUser: true, text: text, timestamp: ts));
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
      setState(() {
        _typing = false;
        _msgs.add(_Message(id: '${DateTime.now().millisecondsSinceEpoch}', isUser: false, text: reply, timestamp: ts, dataCard: card));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Header
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 12,
                    child: InnovativeBackButton(onTap: widget.onBack),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'care',
                              style: AppTheme.sansFont(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            TextSpan(
                              text: 'for',
                              style: AppTheme.sansFont(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    child: CircleAvatar(radius: 16, backgroundColor: const Color(0xFF2DD4BF), child: const Icon(Icons.person, color: Colors.white, size: 18)),
                  ),
                ],
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _msgs.length + (_typing ? 1 : 0) + 1,
              itemBuilder: (_, i) {
                if (i == 0) return Center(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('TODAY, 9:41 AM', style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 2))));
                final msgIndex = i - 1;
                if (msgIndex == _msgs.length && _typing) {
                  return _TypingIndicator();
                }
                if (msgIndex >= _msgs.length) return const SizedBox.shrink();
                return _MessageBubble(msg: _msgs[msgIndex]);
              },
            ),
          ),

          // Suggested actions
          Container(
            color: Colors.white.withOpacity(0.95),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                _SuggestChip('Yes, show me exercises', () => _send('Yes, show me exercises')),
                const SizedBox(width: 8),
                _SuggestChip('What is my BMI?', () => _send('What is my BMI?')),
                const SizedBox(width: 8),
                _SuggestChip('How to lower blood pressure?', () => _send('How to lower blood pressure?')),
              ]),
            ),
          ),

          // Input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(bottom: 84 + MediaQuery.of(context).padding.bottom),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF3F4F6)), child: const Icon(Icons.menu, size: 20, color: Color(0xFF6B7280))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF3F4F6))),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      child: TextField(
                        controller: _ctrl,
                        style: GoogleFonts.hankenGrotesk(fontSize: 14, color: const Color(0xFF374151)),
                        decoration: InputDecoration(
                          hintText: 'Ask about your health...',
                          hintStyle: GoogleFonts.hankenGrotesk(fontSize: 14, color: const Color(0xFF9CA3AF)),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_ctrl.text),
                    child: Container(width: 40, height: 40, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2DD4BF)), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE0F2FE), child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF0EA5E9))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2DD4BF) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                    ),
                    boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.text, style: GoogleFonts.hankenGrotesk(fontSize: 14, color: isUser ? Colors.white : const Color(0xFF1F2937), height: 1.5)),
                      if (msg.dataCard != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(msg.dataCard!['label'], style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 0.8)),
                                const SizedBox(height: 2),
                                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                                  Text('${msg.dataCard!['value']}', style: GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                                  if ((msg.dataCard!['unit'] as String).isNotEmpty) ...[const SizedBox(width: 2), Text(msg.dataCard!['unit'], style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF)))],
                                ]),
                              ]),
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: msg.dataCard!['type'] == 'down' ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                                  border: Border.all(color: msg.dataCard!['type'] == 'down' ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
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
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 16, backgroundColor: const Color(0xFFF3F4F6), child: const Icon(Icons.person, size: 16, color: Color(0xFF6B7280))),
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
      CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE0F2FE), child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF0EA5E9))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)]),
        child: Row(children: List.generate(3, (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(shape: BoxShape.circle, color: Color.lerp(const Color(0xFFD1D5DB), const Color(0xFF9CA3AF), _anims[i].value))),
        ))),
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
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF4B5563))),
    ),
  );
}
