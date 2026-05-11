// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';
import 'login_screen.dart';
import 'camera_screen.dart';
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
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = await ApiService.getElderlyProfiles();
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể tải danh sách. Kiểm tra kết nối mạng.';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    // User model mới: có email, fullName, phone — không có username
    final user = context.watch<AuthProvider>().user;

    // Lấy chữ cái đầu hiển thị avatar: ưu tiên fullName, fallback email
    final displayInitial = (user?.fullName?.isNotEmpty == true
            ? user!.fullName!
            : user?.email ?? 'U')[0]
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.smart_toy_rounded,
                  color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Alpha Mini'),
          ],
        ),
        // Thay phần actions trong AppBar của home_screen.dart
// Tìm đoạn actions: [...] và thay bằng đoạn dưới

        actions: [
          // Gộp camera + voice + payment vào 1 PopupMenu
          PopupMenuButton<String>(
            icon: const Icon(Icons.apps_rounded),
            tooltip: 'Tính năng',
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              switch (v) {
                case 'camera':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CameraScreen()));
                  break;
                case 'voice':
                  Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const VoiceMessageScreen()));
                  break;
                case 'payment':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PaymentScreen()));
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'camera',
                child: Row(children: [
                  Icon(Icons.videocam_rounded, color: AppTheme.robotBlue),
                  SizedBox(width: 12),
                  Text('Camera Robot'),
                ]),
              ),
              const PopupMenuItem(
                value: 'voice',
                child: Row(children: [
                  Icon(Icons.record_voice_over_rounded,
                      color: AppTheme.primary),
                  SizedBox(width: 12),
                  Text('Nhắn tin cho Robot'),
                ]),
              ),
              const PopupMenuItem(
                value: 'payment',
                child: Row(children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: AppTheme.success),
                  SizedBox(width: 12),
                  Text('Gói dịch vụ'),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadProfiles,
            tooltip: 'Làm mới',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                displayInitial,
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w700),
              ),
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user?.fullName != null)
                      Text(user!.fullName!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    Text(user?.email ?? '',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                    if (user?.phone != null)
                      Text(user!.phone!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(user?.role ?? 'FAMILYMEMBER',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout_rounded,
                      color: AppTheme.danger, size: 18),
                  SizedBox(width: 10),
                  Text('Đăng xuất',
                      style: TextStyle(color: AppTheme.danger)),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 8),
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
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _profiles.length,
      itemBuilder: (_, i) => _ElderlyCard(
        profile: _profiles[i],
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ElderlyDetailScreen(profile: _profiles[i])));
          _loadProfiles();
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 72, color: AppTheme.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Chưa có người nhà nào',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('Nhấn + để thêm người nhà đầu tiên',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProfiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Elderly Card ──────────────────────────────────────────────────────────────

class _ElderlyCard extends StatelessWidget {
  final ElderlyProfile profile;
  final VoidCallback onTap;

  const _ElderlyCard({required this.profile, required this.onTap});

  /// Tính tuổi từ dateOfBirth "YYYY-MM-DD"
  int? get _age {
    if (profile.dateOfBirth == null) return null;
    try {
      final birth = DateTime.parse(profile.dateOfBirth!);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _age;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar — dùng chữ cái đầu của profile.name
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.elderlyPurple, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    profile.name.isNotEmpty
                        ? profile.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // profile.name thay vì profile.fullName
                    Text(profile.name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    // Tuổi tính từ dateOfBirth
                    if (age != null)
                      Row(
                        children: [
                          const Icon(Icons.cake_outlined,
                              size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('$age tuổi',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                        ],
                      ),
                    // healthNotes thay cho relationship
                    if (profile.healthNotes != null &&
                        profile.healthNotes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.medical_information_outlined,
                              size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profile.healthNotes!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // roomId nếu có
                    if (profile.roomId != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.meeting_room_outlined,
                              size: 13, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text('Phòng ${profile.roomId}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
