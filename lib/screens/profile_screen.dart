import 'package:flutter/material.dart';
import '../components/innovative_back_button.dart';
import '../theme/app_theme.dart';
import '../components/wavy_bottom_nav_bar.dart';

class _GuardianMember {
  final String id;
  final String name;
  final String email;
  final String role;
  bool isAccepted;
  final String scanTime;
  final String hr;
  final String hrv;
  final String spo2;
  final String resp;
  final String stress;
  final String statusBadge;
  final String summaryText;

  _GuardianMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isAccepted = false,
    required this.scanTime,
    required this.hr,
    required this.hrv,
    required this.spo2,
    required this.resp,
    required this.stress,
    required this.statusBadge,
    required this.summaryText,
  });
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onBack;
  final VoidCallback onNavigateToHome;
  final VoidCallback onNavigateToDiary;
  final VoidCallback onStartScan;
  final Function(String? message) onNavigateToChat;

  const ProfileScreen({
    super.key,
    required this.onSignOut,
    required this.onBack,
    required this.onNavigateToHome,
    required this.onNavigateToDiary,
    required this.onStartScan,
    required this.onNavigateToChat,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notifications = true;
  final TextEditingController _guardianIdCtrl = TextEditingController();
  bool _isSendingInvite = false;

  final List<String> _presetAvatars = ['Avatar 1', 'Avatar 2', 'Avatar 3', 'Avatar 4'];
  int _avatarPresetIndex = 0;

  // List of Guardians (supports multiple guardians & in-app acceptance state)
  final List<_GuardianMember> _guardians = [
    _GuardianMember(
      id: 'g1',
      name: 'Dr. Sarah Jenkins',
      email: '#CF-G849',
      role: 'Primary Guardian',
      isAccepted: true,
      scanTime: 'Yesterday, 6:15 PM',
      hr: '68 bpm',
      hrv: '55 ms',
      spo2: '99%',
      resp: '14 rpm',
      stress: '12% Low',
      statusBadge: 'Optimal Vitals',
      summaryText:
          'Guardian vitals are operating at peak efficiency with excellent HRV (55ms) and low overall stress levels.',
    ),
  ];

  @override
  void dispose() {
    _guardianIdCtrl.dispose();
    super.dispose();
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Profile Picture',
                    style: AppTheme.sansFont(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _pickerOptionTile(
                    icon: Icons.photo_camera_rounded,
                    label: 'Take Photo',
                    color: const Color(0xFF0EA5E9),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Camera profile photo updated!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _pickerOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gallery photo selected!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  _pickerOptionTile(
                    icon: Icons.face_rounded,
                    label: 'Switch Avatar',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      setState(() {
                        _avatarPresetIndex =
                            (_avatarPresetIndex + 1) % _presetAvatars.length;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Avatar preset changed to Style ${_avatarPresetIndex + 1}!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.sansFont(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _sendGuardianInvite() {
    final guardianIdInput = _guardianIdCtrl.text.trim();
    if (guardianIdInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid enrolled CareFor Guardian ID.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final formattedId = guardianIdInput.startsWith('#')
        ? guardianIdInput.toUpperCase()
        : '#${guardianIdInput.toUpperCase()}';

    if (_guardians.any((g) => g.email.toLowerCase() == formattedId.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This CareFor Guardian ID is already added to your list.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSendingInvite = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        final guardianName = 'Guardian ($formattedId)';

        final newGuardian = _GuardianMember(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          name: guardianName,
          email: formattedId,
          role: 'Secondary Guardian',
          isAccepted: false, // Initially pending in-app acceptance!
          scanTime: 'Today, 8:15 AM',
          hr: '71 bpm',
          hrv: '52 ms',
          spo2: '98%',
          resp: '15 rpm',
          stress: '14% Normal',
          statusBadge: 'Stable Vitals',
          summaryText:
              'Caregiver scan recorded normal heart rate variability and breathing rate.',
        );

        setState(() {
          _isSendingInvite = false;
          _guardians.add(newGuardian);
          _guardianIdCtrl.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'In-App Invite sent to CareFor ID $formattedId! Pending in-app acceptance.'),
            backgroundColor: const Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showSignOutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFECACA), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm Sign Out',
                  style: AppTheme.sansFont(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to log out of your CareFor account? You will need to sign in again to access your biometric health data.',
                  textAlign: TextAlign.center,
                  style: AppTheme.sansFont(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTheme.sansFont(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          widget.onSignOut(); // Trigger logout callback
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Log Out',
                          style: AppTheme.sansFont(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHealthResultsComparisonModal() {
    int selectedMemberIndex = 0; // 0: Raj Mohan (Patient), 1..N: Accepted Guardians

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final acceptedGuardians =
                _guardians.where((g) => g.isAccepted).toList();
            final hasAcceptedGuardians = acceptedGuardians.isNotEmpty;

            // Compute details based on selectedMemberIndex
            final isUser = selectedMemberIndex == 0 || !hasAcceptedGuardians;

            String name, role, time, hr, hrv, spo2, resp, stress, statusBadge, summaryText;

            if (isUser) {
              name = 'Raj Mohan B';
              role = 'Patient';
              time = 'Today, 9:30 AM';
              hr = '72 bpm';
              hrv = '48 ms';
              spo2 = '98%';
              resp = '16 rpm';
              stress = '18% Normal';
              statusBadge = 'Steady Recovery';
              summaryText =
                  'Camera vitals indicate steady physical recovery. Heart Rate Variability (48ms) is slightly low, suggesting extra hydration and an afternoon rest session.';
            } else {
              final guardianIdx = selectedMemberIndex - 1;
              final guardian = acceptedGuardians[guardianIdx < acceptedGuardians.length ? guardianIdx : 0];
              name = guardian.name;
              role = guardian.role;
              time = guardian.scanTime;
              hr = guardian.hr;
              hrv = guardian.hrv;
              spo2 = guardian.spo2;
              resp = guardian.resp;
              stress = guardian.stress;
              statusBadge = guardian.statusBadge;
              summaryText = guardian.summaryText;
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.84,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera Health Results',
                              style: AppTheme.sansFont(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              hasAcceptedGuardians
                                  ? 'Select a member to view detailed camera scan analysis'
                                  : 'Showing your camera health report',
                              style: AppTheme.sansFont(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Member Selection Tabs (only shown if accepted guardians exist)
                  if (hasAcceptedGuardians)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setModalState(() => selectedMemberIndex = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedMemberIndex == 0
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: selectedMemberIndex == 0
                                        ? [
                                            const BoxShadow(
                                              color: Color(0x10000000),
                                              blurRadius: 4,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        size: 16,
                                        color: selectedMemberIndex == 0
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'My Results (You)',
                                        style: AppTheme.sansFont(
                                          fontSize: 12,
                                          fontWeight: selectedMemberIndex == 0
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: selectedMemberIndex == 0
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ...List.generate(acceptedGuardians.length, (idx) {
                                final gIdx = idx + 1;
                                final guardian = acceptedGuardians[idx];
                                return GestureDetector(
                                  onTap: () => setModalState(() => selectedMemberIndex = gIdx),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selectedMemberIndex == gIdx
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: selectedMemberIndex == gIdx
                                          ? [
                                              const BoxShadow(
                                                color: Color(0x10000000),
                                                blurRadius: 4,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.health_and_safety_rounded,
                                          size: 16,
                                          color: selectedMemberIndex == gIdx
                                              ? const Color(0xFF0D9488)
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          guardian.name,
                                          style: AppTheme.sansFont(
                                            fontSize: 12,
                                            fontWeight: selectedMemberIndex == gIdx
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: selectedMemberIndex == gIdx
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Report Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Selected Member Header Banner
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isUser
                                    ? [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]
                                    : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isUser
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isUser
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF10B981),
                                  child: Icon(
                                    isUser
                                        ? Icons.person_rounded
                                        : Icons.health_and_safety_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            name,
                                            style: AppTheme.sansFont(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isUser
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFF059669),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              statusBadge,
                                              style: AppTheme.sansFont(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$role | Scan Recorded: $time',
                                        style: AppTheme.sansFont(
                                          fontSize: 11,
                                          color: const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Vitals Cards Grid
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 2.0,
                            children: [
                              _buildVitalDetailCard(
                                label: 'HEART RATE',
                                value: hr,
                                status: 'Optimal',
                                icon: Icons.favorite_rounded,
                                color: const Color(0xFFEF4444),
                              ),
                              _buildVitalDetailCard(
                                label: 'HRV VARIABILITY',
                                value: hrv,
                                status: isUser ? 'Slightly Low' : 'Optimal',
                                icon: Icons.monitor_heart_rounded,
                                color: const Color(0xFF8B5CF6),
                              ),
                              _buildVitalDetailCard(
                                label: 'OXYGEN (SPO2)',
                                value: spo2,
                                status: 'Optimal',
                                icon: Icons.opacity_rounded,
                                color: const Color(0xFF0EA5E9),
                              ),
                              _buildVitalDetailCard(
                                label: 'RESPIRATION',
                                value: resp,
                                status: 'Normal',
                                icon: Icons.air_rounded,
                                color: const Color(0xFF10B981),
                              ),
                              _buildVitalDetailCard(
                                label: 'STRESS INDEX',
                                value: stress,
                                status: 'Relaxed',
                                icon: Icons.psychology_rounded,
                                color: const Color(0xFFF59E0B),
                              ),
                              _buildVitalDetailCard(
                                label: 'CAMERA SCAN FIT',
                                value: '100% Valid',
                                status: 'Passed',
                                icon: Icons.camera_front_rounded,
                                color: const Color(0xFF0D9488),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // AI Analysis Summary
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded,
                                        color: Color(0xFF0D9488), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'SCAN ANALYSIS SUMMARY',
                                      style: AppTheme.sansFont(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summaryText,
                                  style: AppTheme.sansFont(
                                    fontSize: 12,
                                    color: const Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVitalDetailCard({
    required String label,
    required String value,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.sansFont(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.sansFont(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          Text(
            status,
            style: AppTheme.sansFont(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acceptedGuardiansCount = _guardians.where((g) => g.isAccepted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile banner with Avatar image selector
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2DD4BF), Color(0xFF0D9488)],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFFE0F2FE),
                                child: Icon(
                                  _avatarPresetIndex == 0
                                      ? Icons.person_rounded
                                      : _avatarPresetIndex == 1
                                          ? Icons.face_rounded
                                          : _avatarPresetIndex == 2
                                              ? Icons.face_retouching_natural_rounded
                                              : Icons.account_circle_rounded,
                                  color: const Color(0xFF0284C7),
                                  size: 52,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: _showImagePickerModal,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x20000000),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Raj Mohan B',
                          style: AppTheme.sansFont(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Verified Patient | ID: #CF-9824',
                              style: AppTheme.sansFont(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. PERSONAL HEALTH STATS GRID
                        _SectionHeader('PERSONAL HEALTH STATS'),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.1,
                          children: const [
                            _ProfileInfoCard(
                                label: 'HEIGHT', value: '180', unit: 'cm', icon: Icons.straighten_rounded),
                            _ProfileInfoCard(
                                label: 'WEIGHT', value: '75', unit: 'kg', icon: Icons.scale_rounded),
                            _ProfileInfoCard(
                                label: 'AGE', value: '28', unit: 'yrs', icon: Icons.cake_rounded),
                            _ProfileInfoCard(
                                label: 'DATE OF BIRTH (DOB)',
                                value: '14/08/1996',
                                icon: Icons.calendar_month_rounded),
                            _ProfileInfoCard(
                                label: 'BMI',
                                value: '23.1',
                                valueHighlight: ' Normal',
                                highlightColor: Color(0xFF10B981),
                                icon: Icons.speed_rounded),
                            _ProfileInfoCard(
                                label: 'BLOOD TYPE',
                                value: 'O+',
                                valueHighlight: '+',
                                highlightColor: Colors.red,
                                icon: Icons.bloodtype_rounded),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 2. INVITE GUARDIAN MODULE (MULTIPLE GUARDIANS SUPPORT)
                        _SectionHeader('INVITE & CONNECT GUARDIANS'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                      color: Color(0xFF0D9488),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Connect Enrolled Guardians',
                                          style: AppTheme.sansFont(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Send in-app requests to enrolled caregivers using CareFor ID',
                                          style: AppTheme.sansFont(
                                            fontSize: 11,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // CareFor ID search input field
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.badge_outlined,
                                        color: Color(0xFF64748B), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _guardianIdCtrl,
                                        style: AppTheme.sansFont(
                                          fontSize: 13,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "Guardian's CareFor ID (e.g. #CF-G502)...",
                                          hintStyle: AppTheme.sansFont(
                                            fontSize: 13,
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Action Button
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton.icon(
                                  onPressed: _isSendingInvite ? null : _sendGuardianInvite,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D9488),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: _isSendingInvite
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded,
                                          color: Colors.white, size: 18),
                                  label: Text(
                                    _isSendingInvite
                                        ? 'Sending Request...'
                                        : 'Send Invite Request',
                                    style: AppTheme.sansFont(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              // Guardian List Section
                              if (_guardians.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'CONNECTED & PENDING GUARDIANS (${_guardians.length})',
                                  style: AppTheme.sansFont(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Column(
                                  children: _guardians.map((guardian) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: guardian.isAccepted
                                            ? const Color(0xFFF0FDF4)
                                            : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: guardian.isAccepted
                                              ? const Color(0xFFBBF7D0)
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                guardian.isAccepted
                                                    ? Icons.check_circle_rounded
                                                    : Icons.hourglass_top_rounded,
                                                color: guardian.isAccepted
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      guardian.name,
                                                      style: AppTheme.sansFont(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    Text(
                                                      guardian.email,
                                                      style: AppTheme.sansFont(
                                                        fontSize: 11,
                                                        color: const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded,
                                                    color: Color(0xFFEF4444), size: 18),
                                                onPressed: () {
                                                  setState(() {
                                                    _guardians.removeWhere((g) => g.id == guardian.id);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                          if (!guardian.isAccepted) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Status: Pending Acceptance',
                                                  style: AppTheme.sansFont(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFFD97706),
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    setState(() {
                                                      guardian.isAccepted = true;
                                                    });
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            '${guardian.name} accepted the invite! Shared results enabled.'),
                                                        backgroundColor: const Color(0xFF10B981),
                                                        behavior: SnackBarBehavior.floating,
                                                      ),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF10B981),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                                  label: Text(
                                                    'Accept Invite',
                                                    style: AppTheme.sansFont(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 3. VIEW HEALTH RESULT BUTTON
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x15000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showHealthResultsComparisonModal,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2DD4BF)
                                            .withOpacity(0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.analytics_rounded,
                                        color: Color(0xFF2DD4BF),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'View Health Results',
                                            style: AppTheme.sansFont(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            acceptedGuardiansCount > 0
                                                ? 'View camera scan reports for you & $acceptedGuardiansCount connected guardian(s)'
                                                : 'View your camera scan health report & analysis',
                                            style: AppTheme.sansFont(
                                              fontSize: 11,
                                              color: Colors.white
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 4. APP SETTINGS
                        _SectionHeader('APP SETTINGS'),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x04000000), blurRadius: 8)
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFECFEFF),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_rounded,
                                        color: Color(0xFF0891B2),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notifications',
                                            style: AppTheme.sansFont(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          Text(
                                            'Guardian alerts & weekly reports',
                                            style: AppTheme.sansFont(
                                              fontSize: 10,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _notifications,
                                      onChanged: (v) =>
                                          setState(() => _notifications = v),
                                      activeThumbColor: const Color(0xFF2DD4BF),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 5. SIGN OUT BUTTON (WITH CONFIRMATION POPUP)
                        GestureDetector(
                          onTap: _showSignOutConfirmationDialog,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.logout_rounded,
                                    color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign Out',
                                  style: AppTheme.sansFont(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
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
      extendBody: true,
      bottomNavigationBar: WavyBottomNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i == 0) widget.onNavigateToHome();
          if (i == 1) widget.onNavigateToDiary();
          if (i == 2) widget.onStartScan();
          if (i == 3) widget.onNavigateToChat(null);
          if (i == 4) {}
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTheme.sansFont(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF64748B),
          letterSpacing: 1.0,
        ),
      );
}

class _ProfileInfoCard extends StatelessWidget {
  final String label, value;
  final String? unit, valueHighlight;
  final Color? highlightColor;
  final IconData? icon;

  const _ProfileInfoCard({
    required this.label,
    required this.value,
    this.unit,
    this.valueHighlight,
    this.highlightColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.sansFont(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTheme.sansFont(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (valueHighlight != null)
                  Text(
                    valueHighlight!,
                    style: AppTheme.sansFont(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: highlightColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                if (unit != null) ...[
                  const SizedBox(width: 2),
                  Text(
                    unit!,
                    style: AppTheme.sansFont(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  )
                ],
              ],
            ),
          ],
        ),
      );
}
