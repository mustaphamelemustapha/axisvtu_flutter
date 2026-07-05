import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../state/session.dart';
import '../state/theme_controller.dart';
import '../theme/axis_tokens.dart';
import '../widgets/concentric_circles_bg.dart';
import '../widgets/glass_card.dart';
import 'personal_info_screen.dart';
import '../widgets/pin_entry_sheet.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_toggle_button.dart';
import '../services/transaction_pin_service.dart';
import '../services/biometric_service.dart';
import '../services/push_notification_service.dart';
import 'quick_auth_screen.dart';
import 'welcome_screen.dart';
import 'about_screen.dart';
import 'referral_screen.dart';
import 'senior_men_board_screen.dart';
import 'security_screen.dart';
import 'admin_announcements_screen.dart';
import 'agent_dashboard_screen.dart';
import 'admin_agent_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _saveBeneficiariesKey = 'axis_profile_save_beneficiaries_v1';
  static const _pushNotificationsKey = 'axis_profile_push_notifications_v1';
  static const _emailAlertsKey = 'axis_profile_email_alerts_v1';

  bool _updatingProfile = false;
  bool _biometricBusy = false;
  bool _changingPassword = false;
  bool _saveBeneficiaries = true;
  bool _pushNotifications = true;
  bool _biometricEnabled = false;
  final _deleteConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = await BiometricService.isAppLockEnabled;
    if (!mounted) return;
    setState(() {
      _saveBeneficiaries =
          prefs.getBool(_saveBeneficiariesKey) ?? _saveBeneficiaries;
      _pushNotifications =
          prefs.getBool(_pushNotificationsKey) ?? _pushNotifications;
      _emailAlerts = prefs.getBool(_emailAlertsKey) ?? _emailAlerts;
      _biometricEnabled = bioEnabled;
    });
  }

  Future<void> _saveBoolPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  void dispose() {
    _deleteConfirmCtrl.dispose();
    super.dispose();
  }

  bool _emailAlerts = true;

  String _displayName(Map<String, dynamic> user) {
    final fullName = (user['full_name'] ?? user['name'] ?? '')
        .toString()
        .trim();
    if (fullName.isNotEmpty) return fullName;
    final email = (user['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String _initialsFromName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length > 1 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _joinedLabel(dynamic createdAt) {
    final raw = createdAt?.toString() ?? '';
    if (raw.trim().isEmpty) return 'Member';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Member';
    return 'Member since ${DateFormat('MMM yyyy').format(parsed.toLocal())}';
  }

  Future<void> _openEditProfileSheet() async {
    final session = context.read<SessionController>();
    final token = (session.token ?? '').trim();
    if (token.isEmpty) return;

    final currentUser = session.user ?? {};
    final fullNameCtrl = TextEditingController(
      text: (currentUser['full_name'] ?? currentUser['name'] ?? '').toString(),
    );
    final phoneCtrl = TextEditingController(
      text: (currentUser['phone_number'] ?? '').toString(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Edit Profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: _updatingProfile ? 'Saving...' : 'Save Changes',
                  loading: _updatingProfile,
                  icon: Icons.save_outlined,
                  onPressed: _updatingProfile
                      ? null
                      : () async {
                          final fullName = fullNameCtrl.text.trim();
                          final phone = phoneCtrl.text.trim();
                          if (fullName.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Full name is too short'),
                              ),
                            );
                            return;
                          }
                          if (phone.isNotEmpty && phone.length < 7) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Phone number is too short'),
                              ),
                            );
                            return;
                          }

                          setState(() => _updatingProfile = true);
                          try {
                            final updated = await AuthService(token: token)
                                .updateProfile(
                                  fullName: fullName,
                                  phoneNumber: phone,
                                );
                            session.updateUser(updated);
                            if (!mounted) return;
                            final navigator = Navigator.of(this.context);
                            final messenger = ScaffoldMessenger.of(
                              this.context,
                            );
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Profile updated')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Update failed: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _updatingProfile = false);
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleThemePreference() async {
    HapticFeedback.selectionClick();
    context.read<ThemeController>().toggle();
  }

  Future<void> _togglePushPreference(bool value) async {
    setState(() => _pushNotifications = value);
    await _saveBoolPref(_pushNotificationsKey, value);
    
    // Sync or wipe token in backend in real-time
    final session = context.read<SessionController>();
    await PushNotificationService.initialize(session);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'In-app alerts enabled.' : 'In-app alerts paused.',
        ),
      ),
    );
  }

  Future<void> _toggleEmailAlerts(bool value) async {
    setState(() => _emailAlerts = value);
    await _saveBoolPref(_emailAlertsKey, value);
  }

  Future<void> _toggleBeneficiaries(bool value) async {
    setState(() => _saveBeneficiaries = value);
    await _saveBoolPref(_saveBeneficiariesKey, value);
  }

  Future<void> _openFaqSheet() async {
    await _showFeatureSheet(
      title: 'Help center',
      subtitle: 'Common questions',
      icon: Icons.help_outline_rounded,
      helperText:
          'These notes cover the most common questions so you can move quickly without leaving the page.',
      actions: [
        _InfoTile(
          label: 'How do I add account credit?',
          value:
              'Transfer to your dedicated top-up details and the credit updates automatically.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Why is an order pending?',
          value:
              'Some providers confirm a little later. We keep the record visible in History.',
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Where is my receipt?',
          value: 'Open the transaction and use View Receipt or Share Receipt.',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'Why did my PIN fail?',
          value:
              'Wrong PIN attempts return a calm retry message so you can try again right away.',
          icon: Icons.pin_outlined,
        ),
        const SizedBox(height: 8),
        _InfoTile(
          label: 'What if a payment is pending?',
          value:
              'Pending transactions stay visible in History until the provider gives a final result.',
          icon: Icons.hourglass_bottom_rounded,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: 'Contact support',
          icon: Icons.mail_outline_rounded,
          onPressed: () {
            Navigator.pop(context);
            _contactSupport();
          },
        ),
      ],
    );
  }

  Future<void> _openIssueSheet() async {
    final subjectCtrl = TextEditingController(text: 'MELE DATA issue report');
    final detailsCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.14),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Report an issue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Write a short summary and we will route it to the mmtechglobe support team.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short summary',
                    prefixIcon: Icon(Icons.subject_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: detailsCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Describe what happened',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Email support',
                  icon: Icons.mail_outline_rounded,
                  onPressed: () async {
                    final subject = subjectCtrl.text.trim().isEmpty
                        ? 'MELE DATA issue report'
                        : subjectCtrl.text.trim();
                    final body = detailsCtrl.text.trim().isEmpty
                        ? 'Hello mmtechglobe team,\n\nI need help with an issue in the app.'
                        : detailsCtrl.text.trim();
                    Navigator.pop(context);
                    await _launchSupportEmail(subject: subject, body: body);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _contactSupport() async {
    await _launchSupportEmail(
      subject: 'MELE DATA support request',
      body: 'Hello mmtechglobe team,\n\nI need help with my MELE DATA account.',
    );
  }

  Future<void> _launchSupportEmail({
    required String subject,
    required String body,
  }) async {
    final sheetContext = context;
    final messenger = ScaffoldMessenger.of(sheetContext);
    final uri = Uri(
      scheme: 'mailto',
      path: 'mmtechglobe@gmail.com',
      queryParameters: {'subject': subject, 'body': body},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await Clipboard.setData(
          const ClipboardData(text: 'mmtechglobe@gmail.com'),
        );
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Support email copied. Send your issue to mmtechglobe@gmail.com.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(
        const ClipboardData(text: 'mmtechglobe@gmail.com'),
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Support email copied. Send your issue to mmtechglobe@gmail.com.',
          ),
        ),
      );
    }
  }

  Widget _buildFormGroup(BuildContext context, List<Widget?> children) {
    final validChildren = children.whereType<Widget>().toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < validChildren.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 68,
                  endIndent: 0,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.05),
                ),
              validChildren[i],
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 360 || size.height < 760;
    final session = context.watch<SessionController>();
    final user = session.user ?? {};
    final name = _displayName(user);
    final role = (user['role'] ?? '').toString().trim().toLowerCase();
    final joined = _joinedLabel(user['created_at']);
    final initials = _initialsFromName(name);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Header Colors
    final cardBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFF1F5F9);
    final tileBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.3) : const Color(0xFFF8FAFC);
    final heroText = isDark ? Colors.white : const Color(0xFF0F172A);
    final heroSoftText = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      body: ConcentricCirclesBg(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Header Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              style: TextStyle(
                                color: heroText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                joined,
                                style: TextStyle(
                                  color: heroSoftText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (role == 'reseller' || role == 'agent') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'AGENT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFD97706),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              _buildFormGroup(context, [
                if (session.isAdmin)
                  _ProfileTile(label: 'Manage Announcements', icon: Icons.campaign_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAnnouncementsScreen()))),
                if (session.isAdmin)
                  _ProfileTile(label: 'Manage Agents', icon: Icons.support_agent_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAgentScreen()))),
                if (role == 'reseller' || role == 'agent')
                  _ProfileTile(label: 'Agent Dashboard', icon: Icons.analytics_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AgentDashboardScreen()))),
              ]),

              _buildFormGroup(context, [
                _ProfileTile(
                  label: 'Personal Info', 
                  icon: Icons.person_outline_rounded, 
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
                  ),
                ),
                _ProfileTile(
                  label: 'Senior Men Board',
                  icon: Icons.emoji_events_rounded,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SeniorMenBoardScreen()),
                  ),
                ),
                _ProfileTile(
                  label: 'Notifications',
                  icon: Icons.notifications_none_rounded,
                  trailing: Switch.adaptive(value: _pushNotifications, onChanged: (value) => _togglePushPreference(value), activeColor: Theme.of(context).colorScheme.primary),
                  onTap: () => _togglePushPreference(!_pushNotifications),
                ),
                _ProfileTile(
                  label: 'Security', 
                  icon: Icons.security_rounded, 
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const SecurityScreen()),
                  ),
                ),
              ]),

              _buildFormGroup(context, [
                _ProfileTile(label: 'About', icon: Icons.info_outline_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()))),
                _ProfileTile(label: 'Help', icon: Icons.help_outline_rounded, onTap: _contactSupport),
              ]),

              _buildFormGroup(context, [
                _ProfileTile(label: 'Delete Account', icon: Icons.delete_outline_rounded, iconColor: Colors.redAccent.withValues(alpha: 0.7), textColor: Colors.redAccent.withValues(alpha: 0.7), onTap: _showDeleteAccountSheet),
                _ProfileTile(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  onTap: () async {
                    await session.logout();
                    if (!context.mounted) return;
                    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(QuickAuthScreen.route, (_) => false);
                  },
                ),
              ]),

              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'Social Media',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _buildFormGroup(context, [
                _ProfileTile(label: 'WhatsApp Channel', icon: Icons.chat_bubble_outline_rounded, trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey), onTap: () => launchUrl(Uri.parse('https://whatsapp.com/channel/0029VbCanujEawdvqLAYu83T'))),
                _ProfileTile(label: 'Instagram', icon: Icons.camera_alt_outlined, trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey), onTap: () => launchUrl(Uri.parse('https://www.instagram.com/meledata.ng?igsh=enNtb255MXpuemJ3&utm_source=qr'))),
                _ProfileTile(label: 'TikTok', icon: Icons.video_library_outlined, trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.grey), onTap: () => launchUrl(Uri.parse('https://www.tiktok.com/@meledata_ng'))),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor?.withValues(alpha: 0.1) ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? contentColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: contentColor.withValues(alpha: 0.3),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.sizeOf(context).height < 760;
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.64);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 34 : 36,
            height: compact ? 34 : 36,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: compact ? 16 : 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
