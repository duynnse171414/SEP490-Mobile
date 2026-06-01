// lib/screens/exercises_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

// ── Per-elderly action storage ─────────────────────────────────────────────────
class _ElderlyActionStore {
  static String _key(int elderlyId) => 'elderly_actions_$elderlyId';

  static Future<Set<int>> getActionIds(int elderlyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(elderlyId)) ?? [];
    return raw.map((s) => int.tryParse(s) ?? -1).where((i) => i >= 0).toSet();
  }

  static Future<void> addActionId(int elderlyId, int actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await getActionIds(elderlyId);
    ids.add(actionId);
    await prefs.setStringList(_key(elderlyId), ids.map((i) => i.toString()).toList());
  }

  static Future<int> count(int elderlyId) async =>
      (await getActionIds(elderlyId)).length;
}

class ExercisesScreen extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const ExercisesScreen({super.key, required this.elderlyProfile});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Toàn bộ catalog từ API
  List<ActionLibrary> _catalog = [];
  // Danh sách đã thêm cho elderly này (subset của catalog)
  List<ActionLibrary> _myActions = [];

  bool _isLoading = true;
  String? _error;

  final Set<int> _playingIds  = {};
  final Set<int> _testingIds  = {};
  final Set<int> _addingIds   = {};

  static const int _freeLimit = 5;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final all = await ApiService.getActionLibrary();
      final myIds = await _ElderlyActionStore.getActionIds(widget.elderlyProfile.id);

      setState(() {
        _catalog   = all;
        _myActions = all.where((a) => myIds.contains(a.id)).toList();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Không thể tải thư viện động tác'; _isLoading = false; });
    }
  }

  // ── Test thử (gửi robot) ────────────────────────────────────────────────────
  Future<void> _testAction(ActionLibrary action) async {
    if (action.code == null || action.code!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Động tác này chưa có mã robot'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_circle_outline_rounded, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Test: ${action.name}',
              style: const TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 46, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          if (action.description != null && action.description!.isNotEmpty)
            Text(action.description!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.code_rounded, size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(action.code!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13,
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (action.duration != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('~${action.duration} giây',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Gửi Robot Test'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _testingIds.add(action.id));
    try {
      await ApiService.sendRobotAction(action.code!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.smart_toy_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Robot đang test "${action.name}"!')),
          ]),
          backgroundColor: AppTheme.accent,
          duration: const Duration(seconds: 3),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger)); }
    } finally {
      if (mounted) { setState(() => _testingIds.remove(action.id)); }
    }
  }

  // ── Thêm vào danh sách của elderly ─────────────────────────────────────────
  Future<void> _addToMyList(ActionLibrary action) async {
    final alreadyAdded = _myActions.any((a) => a.id == action.id);
    if (alreadyAdded) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${action.name}" đã có trong danh sách'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    // Kiểm tra giới hạn per-elderly
    final currentCount = await _ElderlyActionStore.count(widget.elderlyProfile.id);
    if (currentCount >= _freeLimit) {
      final hasPkg = await _hasActivePaidPackage();
      if (!mounted) return;
      if (!hasPkg) { _showUpgradeDialog(currentCount); return; }
    }

    setState(() => _addingIds.add(action.id));
    try {
      // Chỉ lưu mapping local — action đã có trong DB rồi, không tạo mới
      await _ElderlyActionStore.addActionId(widget.elderlyProfile.id, action.id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Đã thêm "${action.name}" vào danh sách!')),
          ]),
          backgroundColor: AppTheme.success,
        ));
        _tabCtrl.animateTo(1);
      }
    } finally {
      if (mounted) { setState(() => _addingIds.remove(action.id)); }
    }
  }

  // ── Play từ danh sách của tôi ───────────────────────────────────────────────
  Future<void> _playAction(ActionLibrary action) async {
    if (action.code == null || action.code!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Động tác này chưa có mã code robot'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Gửi đến Robot', style: TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text('Robot sẽ thực hiện:\n"${action.name}"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (action.code != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Code: ${action.code}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13,
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ],
          if (action.duration != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('~${action.duration} giây',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Thực hiện'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _playingIds.add(action.id));
    try {
      await ApiService.sendRobotAction(action.code!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.smart_toy_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Robot đang thực hiện "${action.name}"!')),
          ]),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 3),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger)); }
    } finally {
      if (mounted) { setState(() => _playingIds.remove(action.id)); }
    }
  }

  Future<bool> _hasActivePaidPackage() async {
    try {
      final pkgs = await ApiService.getUserPackagesByElderly(widget.elderlyProfile.id);
      return pkgs.any((p) {
        final s = (p['status'] as String? ?? '').toUpperCase();
        final expired = p['expiredAt'] as String?;
        if (s != 'PAID') return false;
        if (expired == null) return true;
        return DateTime.tryParse(expired)?.isAfter(DateTime.now()) ?? false;
      });
    } catch (_) {
      return false;
    }
  }

  void _showUpgradeDialog(int currentCount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Đã đủ giới hạn', style: TextStyle(fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.elderlyProfile.name} đã có $currentCount/$_freeLimit động tác miễn phí.',
              style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Nâng cấp gói Premium để thêm không giới hạn!',
                  style: TextStyle(fontSize: 13, color: Colors.black87))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Mua gói Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(icon: Icon(Icons.explore_rounded, size: 18), text: 'Khám phá'),
            Tab(
              icon: const Icon(Icons.bookmark_rounded, size: 18),
              text: _isLoading ? 'Của tôi' : 'Của tôi (${_myActions.length})',
            ),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [_buildCatalogTab(), _buildMyTab()],
        ),
      ),
    ]);
  }

  // ── Catalog tab ─────────────────────────────────────────────────────────────
  Widget _buildCatalogTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
      ]));
    }
    if (_catalog.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.smart_toy_outlined, size: 72,
            color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('Chưa có động tác nào trong thư viện',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tải lại'),
        ),
      ]));
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 18),
          SizedBox(width: 10),
          Expanded(child: Text(
            'Nhấn Test để robot thực hiện thử — nếu phù hợp thì Thêm vào',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          )),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            itemCount: _catalog.length,
            itemBuilder: (_, i) {
              final action = _catalog[i];
              final added   = _myActions.any((a) => a.id == action.id);
              final testing = _testingIds.contains(action.id);
              final adding  = _addingIds.contains(action.id);
              return _CatalogCard(
                action: action,
                alreadyAdded: added,
                isTesting: testing,
                isAdding: adding,
                onTest: () => _testAction(action),
                onAdd: added ? null : () => _addToMyList(action),
              );
            },
          ),
        ),
      ),
    ]);
  }

  // ── My actions tab ──────────────────────────────────────────────────────────
  Widget _buildMyTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_myActions.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_border_rounded, size: 72,
            color: AppTheme.textSecondary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('Chưa có động tác nào',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        const Text('Sang tab Khám phá để chọn động tác phù hợp',
            style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _tabCtrl.animateTo(0),
          icon: const Icon(Icons.explore_rounded),
          label: const Text('Khám phá ngay'),
        ),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        itemCount: _myActions.length,
        itemBuilder: (_, i) => _MyActionCard(
          action: _myActions[i],
          isPlaying: _playingIds.contains(_myActions[i].id),
          onPlay: () => _playAction(_myActions[i]),
        ),
      ),
    );
  }
}

// ── Catalog Card ───────────────────────────────────────────────────────────────
class _CatalogCard extends StatelessWidget {
  final ActionLibrary action;
  final bool alreadyAdded;
  final bool isTesting;
  final bool isAdding;
  final VoidCallback onTest;
  final VoidCallback? onAdd;

  const _CatalogCard({
    required this.action, required this.alreadyAdded,
    required this.isTesting, required this.isAdding,
    required this.onTest, this.onAdd,
  });

  Color get _typeColor {
    switch ((action.type ?? '').toUpperCase()) {
      case 'STRETCHING': return const Color(0xFF0D9488);
      case 'STRENGTH':   return const Color(0xFFEF4444);
      case 'BALANCE':    return const Color(0xFF8B5CF6);
      case 'CARDIO':     return const Color(0xFFEC4899);
      case 'RELAXATION': return const Color(0xFF22C55E);
      default:           return AppTheme.primary;
    }
  }

  String get _typeLabel {
    switch ((action.type ?? '').toUpperCase()) {
      case 'STRETCHING': return 'Khởi động';
      case 'STRENGTH':   return 'Tăng lực';
      case 'BALANCE':    return 'Thăng bằng';
      case 'CARDIO':     return 'Tim mạch';
      case 'RELAXATION': return 'Thư giãn';
      default:           return action.type ?? 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alreadyAdded
              ? AppTheme.success.withValues(alpha: 0.4)
              : const Color(0xFFCCFBF1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_run_rounded, color: _typeColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(action.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary))),
                if (alreadyAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text('Đã thêm', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if (action.type != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_typeLabel, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _typeColor)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (action.code != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(action.code!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppTheme.primary, fontFamily: 'monospace')),
                  ),
                  const SizedBox(width: 6),
                ],
                if (action.duration != null) ...[
                  const Icon(Icons.timer_outlined, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text('${action.duration}s',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ]),
            ])),
          ]),

          if (action.description != null && action.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(action.description!,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 12),

          Row(children: [
            // Test button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isTesting ? null : onTest,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.6)),
                  foregroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isTesting
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                    : const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text(isTesting ? 'Đang test...' : 'Test thử',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            // Add button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (alreadyAdded || isAdding) ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyAdded ? AppTheme.success : AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  disabledBackgroundColor: alreadyAdded
                      ? AppTheme.success.withValues(alpha: 0.6) : null,
                  disabledForegroundColor: Colors.white,
                ),
                icon: isAdding
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(alreadyAdded ? Icons.check_rounded : Icons.add_rounded, size: 18),
                label: Text(
                  isAdding ? 'Đang thêm...' : alreadyAdded ? 'Đã thêm' : 'Thêm vào',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── My Action Card ─────────────────────────────────────────────────────────────
class _MyActionCard extends StatelessWidget {
  final ActionLibrary action;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _MyActionCard({required this.action, required this.isPlaying, required this.onPlay});

  Color get _typeColor {
    switch ((action.type ?? '').toUpperCase()) {
      case 'STRETCHING': return const Color(0xFF0D9488);
      case 'STRENGTH':   return const Color(0xFFEF4444);
      case 'BALANCE':    return const Color(0xFF8B5CF6);
      case 'CARDIO':     return const Color(0xFFEC4899);
      case 'RELAXATION': return const Color(0xFF22C55E);
      default:           return AppTheme.primary;
    }
  }

  String get _typeLabel {
    switch ((action.type ?? '').toUpperCase()) {
      case 'STRETCHING': return 'Khởi động';
      case 'STRENGTH':   return 'Tăng lực';
      case 'BALANCE':    return 'Thăng bằng';
      case 'CARDIO':     return 'Tim mạch';
      case 'RELAXATION': return 'Thư giãn';
      default:           return action.type ?? 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying
              ? AppTheme.primary.withValues(alpha: 0.5)
              : const Color(0xFFCCFBF1),
          width: isPlaying ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_run_rounded, color: _typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(action.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              if (action.type != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(_typeLabel, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _typeColor)),
                ),
                const SizedBox(width: 6),
              ],
              if (action.code != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(action.code!, style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.primary, fontFamily: 'monospace')),
                ),
            ]),
            if (action.description != null && action.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(action.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ])),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: ElevatedButton.icon(
              onPressed: isPlaying ? null : onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlaying ? Colors.grey : AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: isPlaying
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(isPlaying ? '...' : 'Play',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
