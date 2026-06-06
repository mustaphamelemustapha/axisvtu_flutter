import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../state/session.dart';
import '../theme/axis_tokens.dart';
import '../widgets/glass_card.dart';
import '../widgets/primary_button.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  static const String route = '/admin/announcements';

  @override
  State<AdminAnnouncementsScreen> createState() => _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _updatingIds = {};

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null) {
        throw Exception('User is not authenticated');
      }

      final adminService = AdminService(token: token);
      final list = await adminService.getAdminAnnouncements();

      if (mounted) {
        setState(() {
          _announcements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleActive(int announcementId, bool currentVal) async {
    if (_updatingIds.contains(announcementId)) return;

    setState(() {
      _updatingIds.add(announcementId);
    });

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      await adminService.updateAnnouncement(announcementId, isActive: !currentVal);

      // Refresh list to show updated state and logs
      final list = await adminService.getAdminAnnouncements();

      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _announcements = list;
          _updatingIds.remove(announcementId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentVal ? 'Announcement activated' : 'Announcement deactivated',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updatingIds.remove(announcementId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update active state: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'success':
        return Colors.greenAccent;
      case 'warning':
        return Colors.amberAccent;
      case 'critical':
        return Colors.redAccent;
      case 'info':
      default:
        return const Color(0xFF2457F5);
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level.toLowerCase()) {
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'critical':
        return Icons.gpp_maybe_outlined;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _formatDateTime(String? rawIso) {
    if (rawIso == null || rawIso.isEmpty) return '—';
    final parsed = DateTime.tryParse(rawIso);
    if (parsed == null) return '—';
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }

  void _openCreateAnnouncementSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateAnnouncementSheet(
        onSuccess: () {
          _loadAnnouncements();
        },
      ),
    );
  }

  void _openEditAnnouncementSheet(Map<String, dynamic> announcement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateAnnouncementSheet(
        announcement: announcement,
        onSuccess: () {
          _loadAnnouncements();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textMain, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Announcements',
          style: TextStyle(
            color: textMain,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textMain),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateAnnouncementSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.campaign_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withValues(alpha: 0.8)),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load announcements',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textMain),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: textDim),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _loadAnnouncements,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _announcements.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.campaign_outlined,
                                size: 36,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Announcements Yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textMain),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Platform broadcasts or notices will show up here. Create one to inform your users.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: textDim, height: 1.4),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _openCreateAnnouncementSheet,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create Announcement'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _announcements.length,
                      itemBuilder: (context, index) {
                        final item = _announcements[index];
                        final id = item['id'] as int;
                        final title = (item['title'] ?? '').toString();
                        final message = (item['message'] ?? '').toString();
                        final level = (item['level'] ?? 'info').toString();
                        final isActive = item['is_active'] == true;
                        final creator = item['created_by_email']?.toString() ?? 'Admin';
                        final created = _formatDateTime(item['created_at']);
                        final startsAt = item['starts_at'];
                        final endsAt = item['ends_at'];
                        final hasTimeWindow = startsAt != null || endsAt != null;

                        final levelColor = _getLevelColor(level);
                        final levelIcon = _getLevelIcon(level);
                        final isUpdating = _updatingIds.contains(id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: levelColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: levelColor.withValues(alpha: 0.3), width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(levelIcon, size: 14, color: levelColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            level.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: levelColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded, color: textDim, size: 20),
                                      onPressed: () => _openEditAnnouncementSheet(item),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 8),
                                    isUpdating
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Switch.adaptive(
                                            value: isActive,
                                            activeColor: Theme.of(context).colorScheme.primary,
                                            onChanged: (val) => _toggleActive(id, isActive),
                                          ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: textMain,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textDim,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1, thickness: 0.5),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Created by: $creator',
                                            style: TextStyle(fontSize: 11, color: textDim),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Created on: $created',
                                            style: TextStyle(fontSize: 11, color: textDim),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasTimeWindow)
                                      Icon(
                                        Icons.date_range_rounded,
                                        size: 16,
                                        color: textDim.withValues(alpha: 0.6),
                                      ),
                                  ],
                                ),
                                if (hasTimeWindow) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.2) : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'VALIDITY WINDOW',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: textDim.withValues(alpha: 0.7),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Start: ${_formatDateTime(startsAt)}',
                                          style: TextStyle(fontSize: 11, color: textMain),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'End: ${_formatDateTime(endsAt)}',
                                          style: TextStyle(fontSize: 11, color: textMain),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _CreateAnnouncementSheet extends StatefulWidget {
  const _CreateAnnouncementSheet({
    required this.onSuccess,
    this.announcement,
  });

  final VoidCallback onSuccess;
  final Map<String, dynamic>? announcement;

  @override
  State<_CreateAnnouncementSheet> createState() => _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<_CreateAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _level = 'info';
  bool _isActive = true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.announcement != null) {
      _titleCtrl.text = widget.announcement!['title']?.toString() ?? '';
      _messageCtrl.text = widget.announcement!['message']?.toString() ?? '';
      _level = widget.announcement!['level']?.toString() ?? 'info';
      _isActive = widget.announcement!['is_active'] == true;
      if (widget.announcement!['starts_at'] != null) {
        _startsAt = DateTime.tryParse(widget.announcement!['starts_at'].toString())?.toLocal();
      }
      if (widget.announcement!['ends_at'] != null) {
        _endsAt = DateTime.tryParse(widget.announcement!['ends_at'].toString())?.toLocal();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final now = DateTime.now();
    final firstDate = isStart ? now.subtract(const Duration(days: 30)) : (_startsAt ?? now);
    
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startsAt ?? now) : (_endsAt ?? now.add(const Duration(days: 1))),
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? (_startsAt ?? now) : (_endsAt ?? now.add(const Duration(hours: 1)))),
    );

    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _startsAt = combined;
        // Auto adjust end time if it is before start time
        if (_endsAt != null && _endsAt!.isBefore(combined)) {
          _endsAt = combined.add(const Duration(hours: 1));
        }
      } else {
        _endsAt = combined;
      }
    });
  }

  String _formatPickerLabel(DateTime? dt, String placeholder) {
    if (dt == null) return placeholder;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final session = context.read<SessionController>();
      final token = session.token;
      if (token == null) throw Exception('Session expired');

      final adminService = AdminService(token: token);
      if (widget.announcement != null) {
        final id = widget.announcement!['id'] as int;
        await adminService.updateAnnouncement(
          id,
          title: _titleCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
          level: _level,
          isActive: _isActive,
          startsAt: _startsAt,
          endsAt: _endsAt,
        );
      } else {
        await adminService.createAnnouncement(
          title: _titleCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
          level: _level,
          isActive: _isActive,
          startsAt: _startsAt,
          endsAt: _endsAt,
        );
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.announcement != null
                ? 'Announcement updated successfully'
                : 'Announcement broadcasted successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create announcement: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textDim = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AxisShadows.softGlow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      widget.announcement != null ? 'Edit Announcement' : 'New Announcement',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Title is required';
                    if (text.length < 2) return 'Title must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageCtrl,
                  maxLength: 2000,
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Message Body',
                    prefixIcon: Icon(Icons.campaign_outlined),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Message body is required';
                    if (text.length < 6) return 'Message must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _level,
                  decoration: const InputDecoration(
                    labelText: 'Severity Level',
                    prefixIcon: Icon(Icons.segment_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info (Blue)')),
                    DropdownMenuItem(value: 'success', child: Text('Success (Green)')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning (Amber)')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical (Red)')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _level = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  title: const Text('Active Immediately', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text('Visible to users if the validity window permits.', style: TextStyle(color: textDim, fontSize: 12)),
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Validity Window (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textDim,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'If left unset, the announcement is active indefinitely.',
                  style: TextStyle(fontSize: 11, color: textDim),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Starts At', style: TextStyle(fontSize: 12, color: textDim, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDateTime(true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatPickerLabel(_startsAt, 'Not Set'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _startsAt == null ? textDim : textMain,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_startsAt != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _startsAt = null;
                                        });
                                      },
                                      child: Icon(Icons.close_rounded, size: 16, color: textDim),
                                    )
                                  else
                                    Icon(Icons.calendar_today_rounded, size: 16, color: textDim),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ends At', style: TextStyle(fontSize: 12, color: textDim, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _pickDateTime(false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatPickerLabel(_endsAt, 'Not Set'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _endsAt == null ? textDim : textMain,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_endsAt != null)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _endsAt = null;
                                        });
                                      },
                                      child: Icon(Icons.close_rounded, size: 16, color: textDim),
                                    )
                                  else
                                    Icon(Icons.calendar_today_rounded, size: 16, color: textDim),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _submitting
                      ? (widget.announcement != null ? 'Updating...' : 'Broadcasting...')
                      : (widget.announcement != null ? 'Update Announcement' : 'Broadcast Announcement'),
                  loading: _submitting,
                  icon: Icons.campaign_rounded,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
