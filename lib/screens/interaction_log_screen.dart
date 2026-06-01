// lib/screens/interaction_log_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class InteractionLogScreen extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const InteractionLogScreen({super.key, required this.elderlyProfile});

  @override
  State<InteractionLogScreen> createState() => _InteractionLogScreenState();
}

class _InteractionLogScreenState extends State<InteractionLogScreen> {
  List<InteractionLog> _logs = [];
  List<InteractionLog> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await ApiService.getInteractionLogs(widget.elderlyProfile.id);
      final logs = raw
          .map((e) => InteractionLog.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() { _logs = logs; _filtered = logs; _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Không thể tải lịch sử'; _isLoading = false; });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _selectedType == null
          ? _logs
          : _logs.where((l) => l.interactionType == _selectedType).toList();
    });
  }

  List<String> get _types => _logs
      .map((l) => l.interactionType ?? '')
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  String _typeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'VOICE':    return 'Giọng nói';
      case 'REMINDER': return 'Nhắc nhở';
      case 'EXERCISE': return 'Bài tập';
      case 'CHAT':     return 'Trò chuyện';
      default:         return type;
    }
  }

  Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'VOICE':    return AppTheme.primary;
      case 'REMINDER': return AppTheme.warning;
      case 'EXERCISE': return AppTheme.accent;
      case 'CHAT':     return AppTheme.success;
      default:         return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Lịch sử tương tác'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _logs.isEmpty
                  ? _buildEmpty()
                  : Column(children: [
                      // Filter bar
                      if (_types.length > 1) _buildFilterBar(),
                      // Count
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Row(children: [
                          Text('${_filtered.length} cuộc trò chuyện',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _LogCard(
                              log: _filtered[i],
                              typeLabel: _typeLabel(_filtered[i].interactionType ?? ''),
                              typeColor: _typeColor(_filtered[i].interactionType ?? ''),
                            ),
                          ),
                        ),
                      ),
                    ]),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Chip(
            label: 'Tất cả',
            selected: _selectedType == null,
            onTap: () { setState(() => _selectedType = null); _applyFilter(); },
          ),
          ..._types.map((t) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _Chip(
              label: _typeLabel(t),
              color: _typeColor(t),
              selected: _selectedType == t,
              onTap: () {
                setState(() => _selectedType = _selectedType == t ? null : t);
                _applyFilter();
              },
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.chat_bubble_outline_rounded,
          size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      const Text('Chưa có lịch sử tương tác',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary)),
      const SizedBox(height: 8),
      const Text('Các cuộc trò chuyện với robot sẽ hiện ở đây',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
    ],
  ));

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 52),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
    ],
  ));
}

// ─── Log Card ─────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final InteractionLog log;
  final String typeLabel;
  final Color typeColor;
  const _LogCard({required this.log, required this.typeLabel, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final dt = log.createdDateTime;
    final timeStr = dt != null
        ? DateFormat('HH:mm · dd/MM/yyyy').format(dt)
        : log.createdAt;

    final hasUser  = log.userInputText?.isNotEmpty == true;
    final hasRobot = log.robotResponseText?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCCFBF1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            if (log.interactionType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(typeLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: typeColor)),
              ),
            const Spacer(),
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(timeStr, style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
            ]),
          ]),
        ),

        const Divider(height: 1),

        // Messages
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            // User bubble
            if (hasUser)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded,
                      size: 15, color: AppTheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(log.userInputText!,
                        style: const TextStyle(fontSize: 14,
                            color: AppTheme.textPrimary, height: 1.4)),
                  ),
                ),
              ]),

            if (hasUser && hasRobot) const SizedBox(height: 10),

            // Robot bubble
            if (hasRobot)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Text(log.robotResponseText!,
                        style: const TextStyle(fontSize: 14,
                            color: AppTheme.textPrimary, height: 1.4)),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                  child: const Icon(Icons.smart_toy_rounded,
                      size: 15, color: AppTheme.accent),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

// ─── Chip ─────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _Chip({required this.label, required this.selected,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? c : const Color(0xFFCCFBF1),
          ),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }
}
