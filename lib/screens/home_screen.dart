// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/reminder_checker_service.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'voice_message_screen.dart';
import 'elderly_detail_screen.dart';
import 'add_elderly_screen.dart';
import 'payment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ElderlyProfile> _profiles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ReminderCheckerService.instance.start();
    _loadProfiles();
  }

  @override
  void dispose() {
    // Không stop service khi rời HomeScreen — giữ chạy ngầm cả session
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final profiles = await ApiService.getElderlyProfiles();
      // Cập nhật danh sách elderly cho service kiểm tra reminder
      ReminderCheckerService.instance.profiles = profiles;
      setState(() { _profiles = profiles; _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Không thể tải danh sách. Kiểm tra kết nối mạng.'; _isLoading = false; });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final auth = context.read<AuthProvider>();
      await auth.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initial = (user?.fullName?.isNotEmpty == true
        ? user!.fullName! : user?.email ?? 'U')[0].toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Alpha Mini Family'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Nhắn tin Robot',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VoiceMessageScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: 'Gói dịch vụ',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentScreen())),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(initial, style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w700,
                  fontSize: 14)),
            ),
            onSelected: (v) {
              if (v == 'logout') { _logout(); }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (user?.fullName != null)
                    Text(user!.fullName!, style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15,
                        color: AppTheme.textPrimary)),
                  Text(user?.email ?? '',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded, size: 18, color: AppTheme.danger),
                  SizedBox(width: 12),
                  Text('Đăng xuất',
                      style: TextStyle(color: AppTheme.danger)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfiles,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _profiles.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddElderlyScreen()));
          if (result == true) _loadProfiles();
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Thêm người nhà'),
        elevation: 2,
      ),
    );
  }

  Widget _buildList() => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    itemCount: _profiles.length,
    itemBuilder: (_, i) => _ElderlyCard(
      profile: _profiles[i],
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ElderlyDetailScreen(profile: _profiles[i])));
        _loadProfiles();
      },
    ),
  );

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.people_outline_rounded,
          size: 72, color: Colors.grey.shade300),
      const SizedBox(height: 20),
      const Text('Chưa có người nhà nào',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      const Text('Nhấn nút bên dưới để thêm người nhà',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
    ],
  ));

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.textSecondary),
      const SizedBox(height: 16),
      Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: _loadProfiles,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Thử lại'),
      ),
    ]),
  ));
}

// ── Elderly Card ──────────────────────────────────────────────────────────────

class _ElderlyCard extends StatelessWidget {
  final ElderlyProfile profile;
  final VoidCallback onTap;
  const _ElderlyCard({required this.profile, required this.onTap});

  int? get _age {
    if (profile.dateOfBirth == null) return null;
    try {
      final birth = DateTime.parse(profile.dateOfBirth!);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) { age--; }
      return age;
    } catch (_) { return null; }
  }

  // Màu avatar theo chữ cái — không dùng gradient
  Color get _avatarColor {
    const colors = [
      Color(0xFF0D9488), Color(0xFF0891B2), Color(0xFF22C55E),
      Color(0xFFF97316), Color(0xFFEF4444), Color(0xFF8B5CF6),
    ];
    final idx = profile.name.isNotEmpty
        ? profile.name.codeUnitAt(0) % colors.length : 0;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;
    final color = _avatarColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 5),
              Row(children: [
                if (age != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('$age tuổi',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary)),
                  const SizedBox(width: 12),
                ],
                if (profile.roomId != null) ...[
                  const Icon(Icons.door_back_door_outlined,
                      size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Phòng ${profile.roomId}',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary)),
                ],
              ]),
              if (profile.healthNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(profile.healthNotes!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ])),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary, size: 22),
          ]),
        ),
      ),
    );
  }
}

// ── Robot Web Banner (chỉ hiện khi chạy trên web/Netlify) ─────────────────────

class _RobotWebBanner extends StatefulWidget {
  const _RobotWebBanner();
  @override
  State<_RobotWebBanner> createState() => _RobotWebBannerState();
}

class _RobotWebBannerState extends State<_RobotWebBanner> {
  String _robotIp = '';
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('camera_base_url') ?? '';
    if (mounted && saved.isNotEmpty) {
      setState(() => _robotIp = saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final loginUrl = _robotIp.isNotEmpty
        ? '${_robotIp.endsWith('/') ? _robotIp : '$_robotIp/'}login'
        : 'http://<IP_LAPTOP>:8080/login';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.smart_toy_outlined, color: Colors.orange, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kết nối Robot Alpha Mini',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                  color: Color(0xFFE65100))),
          const SizedBox(height: 4),
          const Text(
            'App web không tự kết nối được robot. Mở trình duyệt '
            'cùng mạng WiFi với laptop và đăng nhập tại:',
            style: TextStyle(fontSize: 12, color: Color(0xFF6D4C41), height: 1.4),
          ),
          const SizedBox(height: 6),
          SelectableText(loginUrl,
              style: const TextStyle(fontSize: 12, color: Color(0xFFE65100),
                  fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ])),
        GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: const Icon(Icons.close_rounded, size: 18, color: Colors.orange),
        ),
      ]),
    );
  }
}
