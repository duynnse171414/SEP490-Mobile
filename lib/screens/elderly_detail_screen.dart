// lib/screens/elderly_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'reminders_screen.dart';
import 'exercises_screen.dart';
import 'alert_screen.dart';
import 'camera_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAlertCount();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
    final p = widget.profile;
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
                colors: [AppTheme.elderlyPurple, AppTheme.primary],
              ),
            ),
            child: SafeArea(
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
                    // Camera button
                    IconButton(
                      icon: const Icon(Icons.videocam_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CameraScreen())),
                      tooltip: 'Camera Robot',
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
                      color: Colors.white.withOpacity(0.2),
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
            ),
          ),

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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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
