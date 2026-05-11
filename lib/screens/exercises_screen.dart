// lib/screens/exercises_screen.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class ExercisesScreen extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const ExercisesScreen({super.key, required this.elderlyProfile});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<ActionLibrary> _actions = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _playingIds = {}; // đang gửi robot

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await ApiService.getActionLibrary();
      setState(() { _actions = list; _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Không thể tải thư viện động tác'; _isLoading = false; });
    }
  }

  Future<void> _addAction() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddActionSheet(),
    );
    if (result == true) _load();
  }

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
                color: AppTheme.robotBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.smart_toy_rounded, color: AppTheme.robotBlue),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Gửi đến Robot Alpha Mini',
              style: TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Robot animation placeholder
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.robotBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                size: 48, color: AppTheme.robotBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Robot sẽ thực hiện:\n"${action.name}"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (action.code != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.robotBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Code: ${action.code}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: AppTheme.robotBlue, fontWeight: FontWeight.w700)),
            ),
          ],
          if (action.duration != null) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Thời gian: ${action.duration}s',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.robotBlue),
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
          backgroundColor: AppTheme.robotBlue,
          duration: const Duration(seconds: 3),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _playingIds.remove(action.id));
    }
  }

  Future<void> _deleteAction(ActionLibrary action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa động tác'),
        content: Text('Xóa "${action.name}" khỏi thư viện?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.deleteActionLibrary(action.id);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa'), backgroundColor: AppTheme.success));
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        // Header info
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.robotBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.robotBlue.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.smart_toy_rounded, color: AppTheme.robotBlue, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Thư viện động tác Robot Alpha Mini',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      color: AppTheme.robotBlue, fontSize: 14)),
              Text('Nhấn ▶ để robot thực hiện động tác cho ${widget.elderlyProfile.name}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ])),
          ]),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _actions.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
                            itemCount: _actions.length,
                            itemBuilder: (_, i) => _ActionCard(
                              action: _actions[i],
                              isPlaying: _playingIds.contains(_actions[i].id),
                              onPlay: () => _playAction(_actions[i]),
                              onDelete: () => _deleteAction(_actions[i]),
                            ),
                          ),
                        ),
        ),
      ]),

      // FAB
      Positioned(
        bottom: 16, right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'exercise_fab',
          onPressed: _addAction,
          icon: const Icon(Icons.add),
          label: const Text('Thêm động tác'),
          backgroundColor: AppTheme.robotBlue,
          foregroundColor: Colors.white,
        ),
      ),
    ]);
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.smart_toy_outlined, size: 72, color: AppTheme.textSecondary.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('Thư viện trống',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      const Text('Thêm động tác để robot thực hiện',
          style: TextStyle(color: AppTheme.textSecondary)),
    ]));
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
      const SizedBox(height: 8),
      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
    ]));
  }
}

// ── Action Card ────────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final ActionLibrary action;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _ActionCard({
    required this.action,
    required this.isPlaying,
    required this.onPlay,
    required this.onDelete,
  });

  Color get _typeColor {
    switch (action.type?.toUpperCase()) {
      case 'STRETCHING':  return const Color(0xFF4CAF50);
      case 'STRENGTH':    return const Color(0xFFFF5722);
      case 'BALANCE':     return const Color(0xFF9C27B0);
      case 'CARDIO':      return const Color(0xFFE91E63);
      case 'RELAXATION':  return const Color(0xFF00BCD4);
      default:            return AppTheme.robotBlue;
    }
  }

  String get _typeLabel {
    switch (action.type?.toUpperCase()) {
      case 'STRETCHING':  return 'Khởi động';
      case 'STRENGTH':    return 'Tăng lực';
      case 'BALANCE':     return 'Thăng bằng';
      case 'CARDIO':      return 'Tim mạch';
      case 'RELAXATION':  return 'Thư giãn';
      default:            return action.type ?? 'Khác';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPlaying
            ? const BorderSide(color: AppTheme.robotBlue, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.robotBlue, AppTheme.robotBlue.withBlue(255)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(action.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                // Type badge
                if (action.type != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_typeLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _typeColor)),
                  ),
                // Code badge
                if (action.code != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.robotBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(action.code!,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppTheme.robotBlue, fontFamily: 'monospace')),
                  ),
                ],
              ]),
            ])),
            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
              onPressed: onDelete,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.danger.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),

          if (action.description != null && action.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(action.description!,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],

          if (action.duration != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${action.duration} giây',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ]),
          ],

          const SizedBox(height: 14),

          // Play button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPlaying ? null : onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlaying ? Colors.grey : AppTheme.robotBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: isPlaying
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                isPlaying ? 'Đang gửi đến robot...' : 'Thực hiện trên Robot',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Add Action Bottom Sheet ────────────────────────────────────────────────────

class _AddActionSheet extends StatefulWidget {
  const _AddActionSheet();

  @override
  State<_AddActionSheet> createState() => _AddActionSheetState();
}

class _AddActionSheetState extends State<_AddActionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  String? _type;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose();
    _descCtrl.dispose(); _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.createActionLibrary(ActionLibrary(
        id: 0,
        name: _nameCtrl.text.trim(),
        code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        type: _type,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        duration: _durationCtrl.text.isEmpty ? null : int.tryParse(_durationCtrl.text),
      ));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.robotBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.library_add_rounded, color: AppTheme.robotBlue),
              ),
              const SizedBox(width: 12),
              const Text('Thêm vào thư viện',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),

            // name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tên động tác *',
                  prefixIcon: Icon(Icons.directions_run_rounded)),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên' : null,
            ),
            const SizedBox(height: 12),

            // Robot code (quan trọng để gửi robot)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.robotBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.robotBlue.withOpacity(0.25)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.smart_toy_rounded, size: 16, color: AppTheme.robotBlue),
                  const SizedBox(width: 6),
                  const Text('Mã lệnh Robot *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppTheme.robotBlue)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Cần để Play',
                        style: TextStyle(fontSize: 10, color: AppTheme.warning,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'Ví dụ: WAVE_HAND, NOD_HEAD, SIT_DOWN',
                      prefixIcon: Icon(Icons.code_rounded)),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // type
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                  labelText: 'Loại động tác',
                  prefixIcon: Icon(Icons.category_outlined)),
              items: const [
                DropdownMenuItem(value: 'STRETCHING', child: Text('Khởi động')),
                DropdownMenuItem(value: 'STRENGTH', child: Text('Tăng lực')),
                DropdownMenuItem(value: 'BALANCE', child: Text('Thăng bằng')),
                DropdownMenuItem(value: 'CARDIO', child: Text('Tim mạch')),
                DropdownMenuItem(value: 'RELAXATION', child: Text('Thư giãn')),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: 12),

            // description
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Mô tả động tác',
                  prefixIcon: Icon(Icons.notes_rounded),
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),

            // duration
            TextFormField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Thời gian thực hiện (giây)',
                  prefixIcon: Icon(Icons.timer_outlined)),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.robotBlue),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('LƯU VÀO THƯ VIỆN',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
