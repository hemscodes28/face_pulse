import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';
import 'measurement_screen.dart'; // To access MeasurementMetrics
import '../components/wavy_bottom_nav_bar.dart';

class DiaryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final List<MeasurementMetrics> scanHistory;
  final VoidCallback onNavigateToHome;
  final VoidCallback onStartScan;
  final Function(String? message) onNavigateToChat;
  final VoidCallback onNavigateToProfile;

  const DiaryScreen({
    super.key,
    required this.onBack,
    required this.scanHistory,
    required this.onNavigateToHome,
    required this.onStartScan,
    required this.onNavigateToChat,
    required this.onNavigateToProfile,
  });

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String _timePeriod = 'Week'; // 'Week' or 'Month'

  late DateTime _currentCalendarMonth;
  List<MeasurementMetrics> _dbScanHistory = [];
  bool _isLoadingHistory = true;
  static const String _backendBaseUrl = 'http://127.0.0.1:8000/api/v1/diary';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentCalendarMonth = DateTime(now.year, now.month, 1);
    _fetchDbDiaryHistory();
  }

  Future<void> _fetchDbDiaryHistory() async {
    try {
      final res = await http.get(Uri.parse('$_backendBaseUrl/history?user_id=user_default'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List measurements = data['measurements'] ?? [];
        final List<MeasurementMetrics> fetched = [];
        for (final m in measurements) {
          double bpm = (m['heart_rate'] as num?)?.toDouble() ?? 72.0;
          double spo2 = (m['spo2'] as num?)?.toDouble() ?? 98.0;
          int sys = (m['systolic'] as num?)?.toInt() ?? 120;
          int dia = (m['diastolic'] as num?)?.toInt() ?? 80;
          int hrv = (m['hrv'] as num?)?.toInt() ?? 48;
          int breath = (m['breath'] as num?)?.toInt() ?? 16;
          int respHealth = (m['respiratory_health'] as num?)?.toInt() ?? 95;
          int stars = (m['quality_stars'] as num?)?.toInt() ?? 5;
          String label = m['quality_label'] ?? 'Good Video Quality';

          fetched.add(MeasurementMetrics(
            pulse: bpm.round(),
            sys: sys,
            dia: dia,
            hrv: hrv,
            breath: breath,
            stress: 1.5,
            workload: 130,
            para: 30,
            bmi: 22.0,
            avgBpm: bpm,
            qualityStars: stars,
            qualityLabel: label,
            spo2: spo2,
            respiratoryHealth: respHealth,
          ));
        }
        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _dbScanHistory = fetched;
            _isLoadingHistory = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching DB diary history: $e");
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // Get month abbreviation name
  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'Aug';
  }

  String _formatDate() {
    final now = DateTime.now();
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[now.weekday % 7];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  // Check if a specific date has any scans in history
  bool _hasScanDataForDate(int year, int month, int day) {
    final history = _effectiveHistory;
    final now = DateTime.now();
    for (int i = 0; i < history.length; i++) {
      DateTime dt;
      if (i == 0) {
        dt = DateTime(now.year, now.month, (now.day - 6).clamp(1, 28));
      } else if (i == 1) {
        dt = DateTime(now.year, now.month, (now.day - 2).clamp(1, 28));
      } else if (i == 2) {
        dt = DateTime(now.year, now.month, now.day);
      } else {
        dt = DateTime.now();
      }
      if (dt.year == year && dt.month == month && dt.day == day) {
        return true;
      }
    }
    return false;
  }

  List<MeasurementMetrics> get _effectiveHistory {
    List<MeasurementMetrics> list = [];
    list.addAll(_dbScanHistory);
    for (final scan in widget.scanHistory) {
      if (!list.contains(scan)) {
        list.add(scan);
      }
    }
    return list;
  }

  // Retrieve the latest scanning output metrics (last scan received by user)
  MeasurementMetrics get _latestScan {
    if (widget.scanHistory.isNotEmpty) {
      return widget.scanHistory.last;
    }
    if (_dbScanHistory.isNotEmpty) {
      return _dbScanHistory.last;
    }
    return const MeasurementMetrics(
      pulse: 75, sys: 117, dia: 74, hrv: 48,
      breath: 16, stress: 1.5, workload: 130, para: 30, bmi: 22.0,
      avgBpm: 75.0, spo2: 98.0, respiratoryHealth: 95,
    );
  }

  // Retrieve the trend history data list
  List<double> _getTrendValues(String metric, String period) {
    int count = period == 'Week' ? 7 : 30;
    List<double> vals = [];
    final history = _effectiveHistory;

    for (final scan in history) {
      if (metric == 'pulse') vals.add(scan.avgBpm);
      else if (metric == 'hrv') vals.add(scan.hrv.toDouble());
      else if (metric == 'breath') vals.add(scan.breath.toDouble());
      else if (metric == 'spo2') vals.add(scan.spo2);
      else if (metric == 'sys') vals.add(scan.sys.toDouble());
      else if (metric == 'dia') vals.add(scan.dia.toDouble());
    }

    if (vals.length > count) {
      vals = vals.sublist(vals.length - count);
    }

    return vals;
  }

  void _prevMonth() {
    setState(() {
      _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentCalendarMonth = DateTime(_currentCalendarMonth.year, _currentCalendarMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Header Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Container(
              height: 56,
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
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: InnovativeBackButton(onTap: widget.onBack),
                    ),
                  ),
                  Center(
                    child: Text(
                      'Health Diary',
                      style: AppTheme.sansFont(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Daily Health Log banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x04000000),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Health Log',
                              style: AppTheme.sansFont(
                                fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tracking health trend analysis',
                              style: AppTheme.sansFont(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        // Date Pill (Dashboard Style)
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
                  const SizedBox(height: 16),

                  // 3. Static Date Info Cards (Day, Month, Year)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDateCard('Day', '${DateTime.now().day}'),
                      _buildDateCard('Month', _getMonthAbbr(DateTime.now().month)),
                      _buildDateCard('Year', '${DateTime.now().year}'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Premium Calendar Card (Month switches working <> now)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 22),
                              color: const Color(0xFF0F172A),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              '${_getMonthName(_currentCalendarMonth.month)} ${_currentCalendarMonth.year}',
                              style: AppTheme.sansFont(
                                fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 22),
                              color: const Color(0xFF0F172A),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Day Headers
                        Row(
                          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                              .map((d) => Expanded(
                                    child: Center(
                                      child: Text(
                                        d,
                                        style: AppTheme.sansFont(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF94A3B8),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        // Interactive Calendar Rows (Showschecked checkmarks/roundings for scans)
                        ..._buildCalendarRows(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. "Recent Scan Results" header with week/month timeframe selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Scan Results',
                            style: AppTheme.sansFont(
                              fontSize: 16,
                                fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Analysis based on scans',
                            style: AppTheme.sansFont(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      // Timeframe Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _buildPeriodOption('Week'),
                            _buildPeriodOption('Month'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 6. Dynamic Metric Trend Cards (Linked to DB Scan Outcomes)
                  // 1) Pulse / Heart Rate Card
                  _buildTrendCard(
                    title: 'HEART RATE (PULSE)',
                    value: '${_latestScan.avgBpm.round()}',
                    unit: 'bpm',
                    status: 'Normal',
                    statusColor: const Color(0xFF10B981),
                    icon: Icons.favorite_rounded,
                    lineColor: const Color(0xFFEF4444),
                    points: _getTrendValues('pulse', _timePeriod),
                  ),
                  const SizedBox(height: 16),

                  // 2) HRV Card
                  _buildTrendCard(
                    title: 'HEART RATE VARIABILITY (HRV)',
                    value: '${_latestScan.hrv}',
                    unit: 'ms',
                    status: 'Optimal',
                    statusColor: const Color(0xFF10B981),
                    icon: Icons.monitor_heart_rounded,
                    lineColor: const Color(0xFF8B5CF6),
                    points: _getTrendValues('hrv', _timePeriod),
                  ),
                  const SizedBox(height: 16),

                  // 3) Breathing Rate Card
                  _buildTrendCard(
                    title: 'BREATHING RATE',
                    value: '${_latestScan.breath}',
                    unit: 'br/m',
                    status: 'Healthy',
                    statusColor: const Color(0xFF10B981),
                    icon: Icons.air_rounded,
                    lineColor: const Color(0xFF3B82F6),
                    points: _getTrendValues('breath', _timePeriod),
                  ),
                  const SizedBox(height: 16),

                  // 4) SpO2 Oxygen Level Card
                  _buildTrendCard(
                    title: 'OXYGEN SATURATION (SPO2)',
                    value: _latestScan.spo2.toStringAsFixed(1),
                    unit: '%',
                    status: 'Optimal',
                    statusColor: const Color(0xFF10B981),
                    icon: Icons.opacity_rounded,
                    lineColor: const Color(0xFF10B981),
                    points: _getTrendValues('spo2', _timePeriod),
                    minVal: 90.0,
                    maxVal: 100.0,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: WavyBottomNavBar(
        currentIndex: 1,
        onTap: (i) {
          if (i == 0) widget.onNavigateToHome();
          if (i == 1) {}
          if (i == 2) widget.onStartScan();
          if (i == 3) widget.onNavigateToChat(null);
          if (i == 4) widget.onNavigateToProfile();
        },
      ),
    );
  }

  Widget _buildDateCard(String label, String value) {
    return Container(
      width: 90,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0A5C5A), width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTheme.sansFont(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0A5C5A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.sansFont(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String period) {
    final isSelected = _timePeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _timePeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D4ED8) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          period,
          style: AppTheme.sansFont(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF1D4ED8),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendCard({
    required String title,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required IconData icon,
    required Color lineColor,
    required List<double> points,
    List<double>? pointsDiastolic,
    double? minVal,
    double? maxVal,
  }) {
    if (points.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x03000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: lineColor.withOpacity(0.5), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: AppTheme.sansFont(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'No Data',
                    style: AppTheme.sansFont(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Icon(Icons.show_chart_rounded, size: 36, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Text(
              'No $title scans in DB yet',
              style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 4),
            Text(
              'Perform a 60s face scan to record your $_timePeriod data into the DB.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onStartScan,
              icon: const Icon(Icons.videocam_rounded, size: 14),
              label: Text('Start Vital Check', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    double calcMin = minVal ?? points.reduce(math.min);
    double calcMax = maxVal ?? points.reduce(math.max);
    if (pointsDiastolic != null && pointsDiastolic.isNotEmpty) {
      calcMin = math.min(calcMin, pointsDiastolic.reduce(math.min));
      calcMax = math.max(calcMax, pointsDiastolic.reduce(math.max));
    }
    double delta = calcMax - calcMin > 0 ? calcMax - calcMin : 1.0;
    calcMin -= delta * 0.1;
    calcMax += delta * 0.1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x03000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: lineColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTheme.sansFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: AppTheme.sansFont(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTheme.sansFont(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: AppTheme.sansFont(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: CustomPaint(
              painter: _TrendLinePainter(
                values: points,
                valuesDiastolic: pointsDiastolic,
                lineColor: lineColor,
                fillGradientColor: lineColor,
                minVal: calcMin,
                maxVal: calcMax,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _getXAxisLabels(),
          ),
        ],
      ),
    );
  }

  List<Widget> _getXAxisLabels() {
    if (_timePeriod == 'Week') {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map((day) => Text(
                day,
                style: AppTheme.sansFont(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
              ))
          .toList();
    } else {
      return ['Day 1', 'Day 10', 'Day 20', 'Day 30']
          .map((day) => Text(
                day,
                style: AppTheme.sansFont(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
              ))
          .toList();
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return 'August';
  }

  List<Widget> _buildCalendarRows() {
    final year = _currentCalendarMonth.year;
    final month = _currentCalendarMonth.month;
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final startOffset = firstWeekday - 1;
    
    final totalCells = ((startOffset + daysInMonth) / 7).ceil() * 7;
    final List<int?> days = List.generate(totalCells, (index) {
      int dayIndex = index - startOffset + 1;
      if (dayIndex >= 1 && dayIndex <= daysInMonth) {
        return dayIndex;
      }
      return null;
    });
    
    final rows = <Widget>[];
    int rowCount = (days.length / 7).ceil();
    for (int r = 0; r < rowCount; r++) {
      rows.add(Row(
        children: List.generate(7, (c) {
          final day = days[r * 7 + c];
          if (day == null) return const Expanded(child: SizedBox(height: 36));
          
          bool hasData = _hasScanDataForDate(year, month, day);

          return Expanded(
            child: Container(
              height: 36,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: hasData ? const Color(0xFFEFF6FF) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: AppTheme.sansFont(
                      fontSize: 12,
                      fontWeight: hasData ? FontWeight.w800 : FontWeight.w600,
                      color: hasData ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                    ),
                  ),
                  if (hasData)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ));
      if (r < rowCount - 1) rows.add(const SizedBox(height: 4));
    }
    return rows;
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<double> values;
  final List<double>? valuesDiastolic; // for BP diastolic values
  final Color lineColor;
  final Color fillGradientColor;
  final double minVal;
  final double maxVal;

  _TrendLinePainter({
    required this.values,
    this.valuesDiastolic,
    required this.lineColor,
    required this.fillGradientColor,
    required this.minVal,
    required this.maxVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    
    final w = size.width;
    final h = size.height;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;
    
    canvas.drawLine(Offset(0, 0), Offset(w, 0), gridPaint);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gridPaint);
    canvas.drawLine(Offset(0, h), Offset(w, h), gridPaint);

    final double stepX = w / (values.length - 1);
    final range = maxVal - minVal > 0 ? maxVal - minVal : 1.0;

    double getX(int i) => i * stepX;
    double getY(double val) {
      double pct = (val - minVal) / range;
      pct = pct.clamp(0.08, 0.92);
      return h - (pct * h);
    }

    // 1. Draw Systolic / Primary Wave
    _drawCurve(canvas, w, h, values, getX, getY, lineColor, fillGradientColor);

    // 2. Draw Diastolic Wave if BP
    if (valuesDiastolic != null) {
      _drawCurve(canvas, w, h, valuesDiastolic!, getX, getY, const Color(0xFFF87171), const Color(0xFFF87171));
    }
  }

  void _drawCurve(
    Canvas canvas,
    double w,
    double h,
    List<double> data,
    double Function(int) getX,
    double Function(double) getY,
    Color strokeColor,
    Color fillColor,
  ) {
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(getX(0), getY(data[0]));
    fillPath.moveTo(getX(0), h);
    fillPath.lineTo(getX(0), getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      double x = getX(i);
      double y = getY(data[i]);
      linePath.lineTo(x, y);
      fillPath.lineTo(x, y);
    }
    fillPath.lineTo(getX(data.length - 1), h);
    fillPath.close();

    // Draw area gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [fillColor.withOpacity(0.12), fillColor.withOpacity(0.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw main line path
    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw dots at key nodes for short counts (Week view)
    if (data.length <= 10) {
      final dotOuterPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.fill;
      final dotInnerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      for (int i = 0; i < data.length; i++) {
        Offset pt = Offset(getX(i), getY(data[i]));
        canvas.drawCircle(pt, 5.0, dotOuterPaint);
        canvas.drawCircle(pt, 2.5, dotInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendLinePainter oldDelegate) => true;
}
