// lib/screens/elderly_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'reminders_screen.dart';
import 'exercises_screen.dart';
import 'alert_screen.dart';
import 'voice_message_screen.dart';
import 'interaction_log_screen.dart';

class ElderlyDetailScreen extends StatefulWidget {
  final ElderlyProfile profile;
  const ElderlyDetailScreen({super.key, required this.profile});

  @override
  State<ElderlyDetailScreen> createState() => _ElderlyDetailScreenState();
}

class _ElderlyDetailScreenState extends State<ElderlyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _unresolvedAlerts = 0;
  late ElderlyProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAlertCount();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _showEditSheet() async {
    final nameCtrl        = TextEditingController(text: _profile.name);
    final dobCtrl         = TextEditingController(text: _profile.dateOfBirth ?? '');
    final healthCtrl      = TextEditingController(text: _profile.healthNotes ?? '');
    final langCtrl        = TextEditingController(text: _profile.preferredLanguage ?? '');
    final speedCtrl       = TextEditingController(text: _profile.speakingSpeed ?? '');
    final roomCtrl        = TextEditingController(text: _profile.roomId?.toString() ?? '');
    final formKey         = GlobalKey<FormState>();
    bool saving           = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.edit_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Chỉnh sửa thông tin',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 20),
                _EditField(ctrl: nameCtrl, label: 'Họ tên', icon: Icons.person_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null),
                const SizedBox(height: 14),
                _EditField(ctrl: dobCtrl, label: 'Ngày sinh (YYYY-MM-DD)',
                    icon: Icons.cake_rounded, hint: 'vd: 1950-01-15'),
                const SizedBox(height: 14),
                _EditField(ctrl: healthCtrl, label: 'Ghi chú sức khoẻ',
                    icon: Icons.health_and_safety_rounded, maxLines: 3),
                const SizedBox(height: 14),
                _EditField(ctrl: langCtrl, label: 'Ngôn ngữ ưu tiên',
                    icon: Icons.language_rounded, hint: 'vd: vi'),
                const SizedBox(height: 14),
                _EditField(ctrl: speedCtrl, label: 'Tốc độ nói',
                    icon: Icons.speed_rounded, hint: 'vd: slow / normal / fast'),
                const SizedBox(height: 14),
                _EditField(ctrl: roomCtrl, label: 'Số phòng',
                    icon: Icons.meeting_room_rounded,
                    keyboardType: TextInputType.number, hint: 'vd: 101'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSheet(() => saving = true);
                      try {
                        final updated = await ApiService.updateElderlyProfile(
                          _profile.id,
                          {
                            'name': nameCtrl.text.trim(),
                            'dateOfBirth': dobCtrl.text.trim().isEmpty ? null : dobCtrl.text.trim(),
                            'healthNotes': healthCtrl.text.trim().isEmpty ? null : healthCtrl.text.trim(),
                            'preferredLanguage': langCtrl.text.trim().isEmpty ? null : langCtrl.text.trim(),
                            'speakingSpeed': speedCtrl.text.trim().isEmpty ? null : speedCtrl.text.trim(),
                            'roomId': roomCtrl.text.trim().isEmpty ? null : int.tryParse(roomCtrl.text.trim()),
                          },
                        );
                        if (mounted) {
                          setState(() => _profile = updated);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Đã cập nhật thông tin'),
                            backgroundColor: AppTheme.success,
                          ));
                        }
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        setSheet(() => saving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(e.message),
                          backgroundColor: AppTheme.danger,
                        ));
                      } catch (_) {
                        if (ctx.mounted) setSheet(() => saving = false);
                      }
                    },
                    icon: saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose(); dobCtrl.dispose(); healthCtrl.dispose();
    langCtrl.dispose(); speedCtrl.dispose(); roomCtrl.dispose();
  }

  Future<void> _loadAlertCount() async {
    try {
      final alerts = await ApiService.getAlertsByElderly(widget.profile.id);
      final count = alerts.where((a) => !a.resolved).length;
      if (mounted) setState(() => _unresolvedAlerts = count);
    } catch (_) {}
  }

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    try {
      final birth = DateTime.parse(dob);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) age--;
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final age = _calcAge(p.dateOfBirth);

    return Scaffold(
      body: Column(
        children: [
          // ── Header cố định (không dùng SliverAppBar) ──────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryDark, AppTheme.primary],
              ),
            ),
            child: Stack(
              children: [
                // Decorative background circles
                Positioned(
                  top: -40, right: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 20, right: 60,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40, left: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 60, left: 30,
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                SafeArea(
              bottom: false,
              child: Column(children: [
                // AppBar row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Alert badge icon
                    Stack(clipBehavior: Clip.none, children: [
                      const Icon(Icons.notifications_rounded,
                          color: Colors.white),
                      if (_unresolvedAlerts > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: AppTheme.danger, shape: BoxShape.circle),
                            child: Text('$_unresolvedAlerts',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      onPressed: _showEditSheet,
                      tooltip: 'Chỉnh sửa thông tin',
                    ),
                    // Nhắn tin Robot
                    IconButton(
                      icon: const Icon(Icons.chat_rounded, color: Colors.white),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => VoiceMessageScreen(elderly: _profile))),
                      tooltip: 'Nhắn tin Robot',
                    ),
                  ]),
                ),

                const SizedBox(height: 8),

                // Avatar
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  if (_unresolvedAlerts > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                            color: AppTheme.danger, shape: BoxShape.circle),
                        child: Text('$_unresolvedAlerts',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),

                const SizedBox(height: 10),

                // Info chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    if (age != null)
                      _InfoChip(icon: Icons.cake_outlined, label: '$age tuổi'),
                    if (p.preferredLanguage != null)
                      _InfoChip(
                          icon: Icons.language_outlined,
                          label: p.preferredLanguage!),
                    if (p.speakingSpeed != null)
                      _InfoChip(
                          icon: Icons.speed_outlined, label: p.speakingSpeed!),
                    if (p.roomId != null)
                      _InfoChip(
                          icon: Icons.meeting_room_outlined,
                          label: 'Phòng ${p.roomId}'),
                  ],
                ),

                const SizedBox(height: 14),

                // TabBar
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  tabs: [
                    const Tab(
                      icon: Icon(Icons.alarm_rounded, size: 18),
                      text: 'Nhắc nhở',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    const Tab(
                      icon: Icon(Icons.fitness_center_rounded, size: 18),
                      text: 'Bài tập',
                      iconMargin: EdgeInsets.only(bottom: 2),
                    ),
                    const Tab(
                      icon: Icon(Icons.history_rounded, size: 18),
                      text: 'Tương tác',
                    ),
                    Tab(
                      iconMargin: const EdgeInsets.only(bottom: 2),
                      icon: Stack(clipBehavior: Clip.none, children: [
                        const Icon(Icons.notifications_active_rounded,
                            size: 18),
                        if (_unresolvedAlerts > 0)
                          Positioned(
                            right: -8,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppTheme.danger,
                                  shape: BoxShape.circle),
                              child: Text('$_unresolvedAlerts',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ]),
                      text: 'Cảnh báo',
                    ),
                  ],
                ),
              ]),
                ),  // SafeArea
              ],
            ),  // Stack
          ),  // Container

          // ── Tab content ───────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                RemindersScreen(elderlyProfile: p),
                ExercisesScreen(elderlyProfile: p),
                InteractionLogScreen(elderlyProfile: p),
                AlertScreen(elderlyProfile: p),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _EditField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ]),
    );
  }
}
