import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/innovative_back_button.dart';

class DiaryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const DiaryScreen({super.key, required this.onBack});
  @override State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  int _selectedDay = 12;

  final Map<int, Map<String, dynamic>> _data = {
    8: {'dateStr': '8/8/2026 13:03', 'pulse': 71, 'hrv': 52, 'breath': 21, 'sys': 114, 'dia': 70},
    12: {'dateStr': '12/8/2026 09:41', 'pulse': 75, 'hrv': 48, 'breath': 24, 'sys': 117, 'dia': 74},
    14: {'dateStr': '14/8/2026 10:15', 'pulse': 78, 'hrv': 45, 'breath': 22, 'sys': 120, 'dia': 76},
  };

  Map<String, dynamic> get _active => _data[_selectedDay] ?? {'dateStr': '$_selectedDay/8/2026 08:30', 'pulse': 72, 'hrv': 50, 'breath': 18, 'sys': 115, 'dia': 72};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
                  Text('Diary', style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Calendar
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.chevron_left, size: 18), color: const Color(0xFF9CA3AF), onPressed: () {}),
                            Text('August 2026', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF374151))),
                            IconButton(icon: const Icon(Icons.chevron_right, size: 18), color: const Color(0xFF9CA3AF), onPressed: () {}),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Day headers
                        Row(
                          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(
                            child: Center(child: Text(d, style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 0.5))),
                          )).toList(),
                        ),
                        const SizedBox(height: 8),
                        // Calendar grid - August 2026 starts on Saturday
                        ..._buildCalendarRows(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reading info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reading taken on: ${_active['dateStr']}', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6B7280))),
                      const Icon(Icons.edit, size: 14, color: Color(0xFF2DD4BF)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Metric cards grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _DiaryCard(label: 'PULSE', value: '${_active['pulse']}', unit: 'bpm', valueColor: const Color(0xFF23B392), icon: Icons.favorite),
                      _DiaryCard(label: 'HRV', value: '${_active['hrv']}', unit: 'ms', valueColor: const Color(0xFF23B392), icon: Icons.monitor_heart),
                      _DiaryCard(label: 'BREATH', value: '${_active['breath']}', unit: 'bpm', valueColor: const Color(0xFFE88C30), icon: Icons.air),
                      _DiaryCard(label: 'SYSTOLIC', sublabel: 'BP', value: '${_active['sys']}', unit: 'mmHg', valueColor: const Color(0xFF1F2937), icon: Icons.speed),
                      _DiaryCard(label: 'DIASTOLIC', sublabel: 'BP', value: '${_active['dia']}', unit: 'mmHg', valueColor: const Color(0xFF1F2937), icon: Icons.speed_outlined),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarRows() {
    // August 2026: starts on Saturday (index 5 in Mon-Sun grid)
    final List<int?> days = [
      null, null, null, null, null, 1, 2,
      3, 4, 5, 6, 7, 8, 9,
      10, 11, 12, 13, 14, 15, 16,
      17, 18, 19, 20, 21, 22, 23,
      24, 25, 26, 27, 28, 29, 30,
      31, null, null, null, null, null, null,
    ];
    final rows = <Widget>[];
    for (int r = 0; r < 6; r++) {
      rows.add(Row(
        children: List.generate(7, (c) {
          final day = days[r * 7 + c];
          if (day == null) return const Expanded(child: SizedBox(height: 36));
          final isSelected = day == _selectedDay;
          final hasDot = _data.containsKey(day);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: Container(
                height: 36,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8E9FD5) : (hasDot ? const Color(0xFFF3F4F6) : Colors.transparent),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('$day', style: GoogleFonts.hankenGrotesk(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF1F2937),
                    )),
                    if (hasDot && !isSelected)
                      Positioned(bottom: 3, child: Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22D3EE)))),
                  ],
                ),
              ),
            ),
          );
        }),
      ));
      if (r < 5) rows.add(const SizedBox(height: 4));
    }
    return rows;
  }
}

class _DiaryCard extends StatelessWidget {
  final String label, value, unit; final String? sublabel; final Color valueColor; final IconData icon;
  const _DiaryCard({required this.label, required this.value, required this.unit, required this.valueColor, required this.icon, this.sublabel});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF3F4F6)), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4)]),
    padding: const EdgeInsets.all(10),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 8, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 0.8)),
              if (sublabel != null) ...[const SizedBox(width: 2), Text(sublabel!, style: GoogleFonts.hankenGrotesk(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.red, letterSpacing: 0.8))],
            ]),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: valueColor)),
                const SizedBox(width: 1),
                Text(unit, style: GoogleFonts.hankenGrotesk(fontSize: 8, fontWeight: FontWeight.w600, color: valueColor)),
              ],
            ),
          ],
        ),
        Positioned(
          right: -4, bottom: -4,
          child: Icon(icon, size: 28, color: const Color(0xFF000000).withOpacity(0.06)),
        ),
      ],
    ),
  );
}
