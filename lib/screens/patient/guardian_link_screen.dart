import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_styles.dart';
import '../../providers/patient_provider.dart';

class GuardianLinkScreen extends StatefulWidget {
  const GuardianLinkScreen({super.key});

  @override
  State<GuardianLinkScreen> createState() => _GuardianLinkScreenState();
}

class _GuardianLinkScreenState extends State<GuardianLinkScreen> {
  String? _generatedCode;
  bool _isLoadingCode = true;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    final patientProvider = context.read<PatientProvider>();
    final code = await patientProvider.fetchOrCreateInviteCode();
    if (mounted) {
      setState(() {
        _generatedCode = code;
        _isLoadingCode = false;
      });
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code "$code" copied to clipboard!'),
        backgroundColor: AppColors.patientBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmUnlink() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unlink Caregiver?'),
        content: const Text(
          'Your caregiver will no longer receive notifications or be able to view your medication schedules. You can reconnect at any time using a new invite code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<PatientProvider>().unlinkCaregiver();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caregiver unlinked successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                _loadCode();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final patientProvider = context.watch<PatientProvider>();
    final isLinked = patientProvider.isLinkedToCaregiver;
    final caregiver = patientProvider.caregiverUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Guardian & Caregiver Link',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'PlusJakartaSans',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: isLinked ? _buildLinkedView(caregiver) : _buildUnlinkedView(),
        ),
      ),
    );
  }

  // ==========================================
  // UNLINKED VIEW (SHOW INVITE CODE & INSTRUCTIONS)
  // ==========================================
  Widget _buildUnlinkedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: AppStyles.gradientDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect with your Caregiver',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Linking an account allows your guardian to check your schedules, ensure you take doses on time, and receive safety alerts.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'YOUR INVITE CODE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 10),

        // Code Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.patientBlue.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.patientBlue.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_isLoadingCode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(color: AppColors.patientBlue),
                )
              else ...[
                Text(
                  _generatedCode ?? 'HS-LINK',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.patientBlue,
                    letterSpacing: 4,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Valid and ready to connect',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_generatedCode != null) {
                            _copyToClipboard(_generatedCode!);
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.patientBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        const Text(
          'HOW TO CONNECT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 12),

        _StepTile(
          step: '1',
          title: 'Give this code to your caregiver',
          subtitle: 'Send the 6-character code via text message or tell them in person.',
        ),
        _StepTile(
          step: '2',
          title: 'Caregiver opens HealthSync app',
          subtitle: 'They sign into their Caregiver account and tap "Link Patient".',
        ),
        _StepTile(
          step: '3',
          title: 'Enter code & connect',
          subtitle: 'As soon as they submit the code, both accounts link instantly.',
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ledActiveBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: const [
              Icon(Icons.hourglass_top_rounded, color: AppColors.patientBlue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Status: Waiting for your caregiver to connect...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.patientBlue,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // LINKED VIEW (SHOW CAREGIVER DETAILS & UNLINK)
  // ==========================================
  Widget _buildLinkedView(caregiver) {
    final name = caregiver != null ? '${caregiver.firstName} ${caregiver.lastName}'.trim() : 'Active Caregiver';
    final email = caregiver?.email ?? 'Connected';
    final phone = caregiver?.phone ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.greenGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CONNECTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Caregiver is Linked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your caregiver is actively monitoring your medication adherence and receiving notifications.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'CAREGIVER DETAILS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: AppStyles.cardDecoration,
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.caregiverGreen.withOpacity(0.15),
                    child: const Icon(Icons.person, color: AppColors.caregiverGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontFamily: 'PlusJakartaSans',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'SHARED PERMISSIONS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
            fontFamily: 'PlusJakartaSans',
          ),
        ),
        const SizedBox(height: 12),

        _PermissionItem(
          icon: Icons.calendar_today_outlined,
          title: 'Medication Schedules',
          description: 'Can view dose times, pills remaining, and prescribed instructions',
        ),
        _PermissionItem(
          icon: Icons.notifications_active_outlined,
          title: 'Missed Dose Alerts',
          description: 'Receives instant notification when a dose is missed or skipped',
        ),
        _PermissionItem(
          icon: Icons.wifi_tethering,
          title: 'Smart Medicine Box Status',
          description: 'Can view device battery and online connectivity status',
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _confirmUnlink,
            icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
            label: const Text(
              'Unlink this Caregiver',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;

  const _StepTile({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.patientBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.patientBlue,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.caregiverGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.caregiverGreen, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_rounded, color: AppColors.caregiverGreen, size: 20),
        ],
      ),
    );
  }
}
