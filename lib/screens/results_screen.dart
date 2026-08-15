import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'measurement_screen.dart';
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatelessWidget {
  final MeasurementMetrics metrics;
  final VoidCallback onFinish;
  final VoidCallback onMeasureAgain;

  const ResultsScreen({super.key, required this.metrics, required this.onFinish, required this.onMeasureAgain});

  @override
  Widget build(BuildContext context) {
    final int stars = metrics.qualityStars;
    final String label = metrics.qualityLabel;
    final double displayAvgBpm = metrics.avgBpm;
    final int samples = metrics.samplesCount;

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
                    child: InnovativeBackButton(onTap: onFinish),
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
                ],
              ),
            ),
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                children: [
                  Text('Health Check Results', style: GoogleFonts.hankenGrotesk(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: stars >= 4
                          ? const Color(0xFFF0FDF4)
                          : (stars >= 3 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: stars >= 4
                            ? const Color(0xFFBBF7D0)
                            : (stars >= 3 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...List.generate(5, (index) => Icon(
                          Icons.star,
                          color: index < stars
                              ? (stars >= 4
                                  ? Colors.green
                                  : (stars >= 3 ? Colors.amber : Colors.red))
                              : const Color(0xFFE5E7EB),
                          size: 18,
                        )),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: stars >= 4
                                ? Colors.green.shade800
                                : (stars >= 3 ? Colors.amber.shade900 : Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ResultCard(
                    title: 'Pulse (HR)', subtitle: 'Average heartbeats per minute during scan.',
                    iconBg: const Color(0xFFFEF2F2), icon: Icons.favorite, iconColor: Colors.red,
                    child: Column(children: [
                      _BigValue(value: displayAvgBpm.toStringAsFixed(1), unit: 'bpm (avg)'),
                      const SizedBox(height: 4),
                      Text('Samples recorded: $samples', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 12),
                      _Gauge(value: (displayAvgBpm - 30) / 210, labels: const ['30', '60', '100', '240']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Blood Pressure', subtitle: '',
                    iconBg: const Color(0xFFECFEFF), icon: Icons.speed, iconColor: const Color(0xFF0891B2),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${metrics.sys}', style: GoogleFonts.hankenGrotesk(fontSize: 40, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                          Text(' / ', style: GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFFD1D5DB))),
                          Text('${metrics.dia}', style: GoogleFonts.hankenGrotesk(fontSize: 40, fontWeight: FontWeight.w700, color: const Color(0xFF0891B2))),
                          const SizedBox(width: 4),
                          Text('mmHg', style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LabeledGauge(label: 'Systolic', value: (metrics.sys - 90) / 80, labels: const ['90', '120', '170']),
                      const SizedBox(height: 12),
                      _LabeledGauge(label: 'Diastolic', value: (metrics.dia - 60) / 40, labels: const ['60', '70', '100']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'HRV (Heart Rate Var)', subtitle: 'Variation in time between heartbeats.',
                    iconBg: const Color(0xFFF5F3FF), icon: Icons.monitor_heart, iconColor: Colors.purple,
                    child: Center(child: Container(
                      width: 112, height: 112,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.purple.shade100, width: 4), color: Colors.purple.shade50.withOpacity(0.2)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${metrics.hrv}', style: GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                        Text('ms', style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.purple, letterSpacing: 1)),
                      ]),
                    )),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Breathing Rate', subtitle: 'Average breaths per minute derived from pulse RSA.',
                    iconBg: const Color(0xFFEFF6FF), icon: Icons.air, iconColor: const Color(0xFF3B82F6),
                    child: Column(children: [
                      _BigValue(value: '${metrics.breath}', unit: 'br/m', valueColor: const Color(0xFF3B82F6)),
                      const SizedBox(height: 12),
                      _Gauge(value: (metrics.breath - 4) / 34, labels: const ['4', '12', '20', '38']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'SpO2 (Blood Oxygen)', subtitle: 'Estimated blood oxygen saturation.',
                    iconBg: const Color(0xFFE0F2FE), icon: Icons.water_drop, iconColor: const Color(0xFF0284C7),
                    child: Column(children: [
                      _BigValue(value: metrics.spo2.toStringAsFixed(1), unit: '%', valueColor: const Color(0xFF0284C7)),
                      const SizedBox(height: 12),
                      _Gauge(value: (metrics.spo2 - 90.0) / 10.0, labels: const ['90%', '95%', '100%']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Respiratory Health', subtitle: 'Airway stability & respiration efficiency.',
                    iconBg: const Color(0xFFECFDF5), icon: Icons.health_and_safety, iconColor: const Color(0xFF10B981),
                    child: Column(children: [
                      _BigValue(value: '${metrics.respiratoryHealth}', unit: '% score', valueColor: const Color(0xFF10B981)),
                      const SizedBox(height: 12),
                      _Gauge(value: metrics.respiratoryHealth / 100.0, labels: const ['60%', '80%', '100%']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Stress Index', subtitle: 'Autonomic stress indicator.',
                    iconBg: const Color(0xFFFFF7ED), icon: Icons.show_chart, iconColor: Colors.orange,
                    child: Column(children: [
                      _BigValue(value: metrics.stress.toStringAsFixed(1), unit: ''),
                      const SizedBox(height: 12),
                      _Gauge(value: metrics.stress / 10, labels: const ['0', '4', '10']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Cardiac Workload', subtitle: 'Heart effort to pump blood.',
                    iconBg: const Color(0xFFF0FDFA), icon: Icons.monitor_heart_outlined, iconColor: const Color(0xFF0D9488),
                    child: Column(children: [
                      _BigValue(value: '${metrics.workload}', unit: 'mmHg/s'),
                      const SizedBox(height: 12),
                      _Gauge(value: (metrics.workload - 45) / 635, labels: const ['45', '90', '216', '680']),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'Parasympathetic Activity', subtitle: 'Stress recovery & relaxation.',
                    iconBg: const Color(0xFFF0FDF4), icon: Icons.percent, iconColor: Colors.green,
                    child: Center(child: Container(
                      width: 112, height: 112,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.green.shade100, width: 4), color: Colors.green.shade50.withOpacity(0.2)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${metrics.para}', style: GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                        Text('%', style: GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green, letterSpacing: 1)),
                      ]),
                    )),
                  ),
                  const SizedBox(height: 16),
                  _ResultCard(
                    title: 'BMI Classification', subtitle: 'Body Mass Index ratio.',
                    iconBg: const Color(0xFFF9FAFB), icon: Icons.scale, iconColor: const Color(0xFF6B7280),
                    child: Column(children: [
                      Text('Normal range (${metrics.bmi})', style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green)),
                      const SizedBox(height: 12),
                      _BmiTrack(value: 0.33),
                    ]),
                  ),
                  const SizedBox(height: 32),
                  // Primary & Secondary Action Buttons
                  _GradientButton(label: 'Show Dashboard', onTap: onFinish),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onMeasureAgain,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      side: const BorderSide(color: Color(0xFF0077CC), width: 1.5),
                    ),
                    child: Text(
                      'Measure Again',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0077CC),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'These results are for general wellness and self-awareness purposes only. This product is not a medical device and does not support clinical decisions, diagnosis, or treatment.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(fontSize: 10, color: const Color(0xFF9CA3AF), height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title, subtitle; final Color iconBg, iconColor; final IconData icon; final Widget child;
  const _ResultCard({required this.title, required this.subtitle, required this.iconBg, required this.icon, required this.iconColor, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF3F4F6)), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)]),
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.hankenGrotesk(fontSize: 11, color: const Color(0xFF9CA3AF), height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

class _BigValue extends StatelessWidget {
  final String value, unit; final Color? valueColor;
  const _BigValue({required this.value, required this.unit, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(value, style: GoogleFonts.hankenGrotesk(fontSize: 48, fontWeight: FontWeight.w700, color: valueColor ?? const Color(0xFF111827))),
      if (unit.isNotEmpty) ...[const SizedBox(width: 4), Text(unit, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 1))],
    ],
  );
}

class _Gauge extends StatelessWidget {
  final double value; final List<String> labels;
  const _Gauge({required this.value, required this.labels});
  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(
      height: 8,
      child: Stack(children: [
        Container(decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4))),
        FractionallySizedBox(widthFactor: value.clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: const Color(0xFF22D3EE), borderRadius: BorderRadius.circular(4)))),
        Align(
          alignment: Alignment(value.clamp(0.0, 1.0) * 2 - 1, 0),
          child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Color(0x3322D3EE), blurRadius: 6)])),
        ),
      ]),
    ),
    const SizedBox(height: 6),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((l) => Text(l, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF)))).toList(),
    ),
  ]);
}

class _LabeledGauge extends StatelessWidget {
  final String label; final double value; final List<String> labels;
  const _LabeledGauge({required this.label, required this.value, required this.labels});
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 64, child: Text(label, textAlign: TextAlign.right, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF6B7280), letterSpacing: 0.5))),
    const SizedBox(width: 12),
    Expanded(child: _Gauge(value: value, labels: labels)),
  ]);
}

class _BmiTrack extends StatelessWidget {
  final double value;
  const _BmiTrack({required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: Stack(children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444)]),
        ),
      ),
      Align(
        alignment: Alignment(value * 2 - 1, 0),
        child: Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4)])),
      ),
    ]),
  );
}

class _GradientButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56, width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006BD6), Color(0xFF00A8E8)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x33006BD6), blurRadius: 12)],
      ),
      child: Center(child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))),
    ),
  );
}

class TextButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const TextButton({super.key, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0077CC))),
    ),
  );
}
