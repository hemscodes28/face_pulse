import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onBack;
  const ProfileScreen({super.key, required this.onSignOut, required this.onBack});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;

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
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                  ]),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile banner
                  Container(
                    color: const Color(0xFFF9FAFB),
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFCCFBF1),
                        child: const Icon(Icons.person, color: Color(0xFF0D9488), size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text('Raj Mohan B', style: GoogleFonts.hankenGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.verified, color: Colors.green, size: 15),
                        const SizedBox(width: 4),
                        Text('Member since Oct 2023', style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF))),
                      ]),
                    ]),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Health Profile
                        _SectionHeader('HEALTH PROFILE'),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 16, crossAxisSpacing: 16,
                          childAspectRatio: 2.0,
                          children: const [
                            _ProfileInfoCard(label: 'Sex', value: 'Male'),
                            _ProfileInfoCard(label: 'Blood Type', value: 'O+', valueHighlight: '+', highlightColor: Colors.red),
                            _ProfileInfoCard(label: 'Height', value: '180', unit: 'cm'),
                            _ProfileInfoCard(label: 'Weight', value: '75', unit: 'kg'),
                          ],
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader('APP SETTINGS'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8)]),
                          child: Column(children: [
                            // Notifications toggle
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFECFEFF)), child: const Icon(Icons.notifications, color: Color(0xFF0891B2), size: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('Notifications', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                                    Text('Alerts & weekly reports', style: GoogleFonts.hankenGrotesk(fontSize: 10, color: const Color(0xFF9CA3AF))),
                                  ])),
                                  Switch(
                                    value: _notifications,
                                    onChanged: (v) => setState(() => _notifications = v),
                                    activeThumbColor: const Color(0xFF2DD4BF),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF9FAFB)),
                            // Units
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFECFEFF)), child: const Icon(Icons.straighten, color: Color(0xFF0891B2), size: 18)),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Units', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
                                  Text('Metric (cm, kg)', style: GoogleFonts.hankenGrotesk(fontSize: 10, color: const Color(0xFF9CA3AF))),
                                ])),
                                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                              ]),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),
                        _SectionHeader('SUPPORT'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8)]),
                          child: Column(children: [
                            _SupportRow(icon: Icons.help, label: 'Help Center', trailingIcon: Icons.open_in_new),
                            const Divider(height: 1, color: Color(0xFFF9FAFB)),
                            _SupportRow(icon: Icons.description, label: 'Terms of Service', trailingIcon: Icons.open_in_new),
                          ]),
                        ),

                        const SizedBox(height: 24),
                        // Sign out button
                        GestureDetector(
                          onTap: widget.onSignOut,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFECACA))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.logout, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text('Sign Out', style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red)),
                            ]),
                          ),
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
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 1));
}

class _ProfileInfoCard extends StatelessWidget {
  final String label, value; final String? unit, valueHighlight; final Color? highlightColor;
  const _ProfileInfoCard({required this.label, required this.value, this.unit, this.valueHighlight, this.highlightColor});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6)), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6)]),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF9CA3AF), letterSpacing: 0.8)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value, style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937))),
        if (valueHighlight != null) Text(valueHighlight!, style: GoogleFonts.hankenGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: highlightColor ?? const Color(0xFF1F2937))),
        if (unit != null) ...[const SizedBox(width: 2), Text(unit!, style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF)))],
      ]),
    ]),
  );
}

class _SupportRow extends StatelessWidget {
  final IconData icon, trailingIcon; final String label;
  const _SupportRow({required this.icon, required this.label, required this.trailingIcon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF3F4F6)), child: Icon(icon, color: const Color(0xFF6B7280), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151)))),
      Icon(trailingIcon, color: const Color(0xFF9CA3AF), size: 16),
    ]),
  );
}

