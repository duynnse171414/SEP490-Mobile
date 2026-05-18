// lib/screens/interaction_log_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';



// ─── Screen ───────────────────────────────────────────────────────────────────

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
  String? _selectedEmotion;

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
          .toList();
      // Sắp xếp mới nhất lên trên
      logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _logs = logs;
        _filtered = logs;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Không thể tải lịch sử'; _isLoading = false; });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _logs.where((l) {
        final typeOk = _selectedType == null ||
            l.interactionType == _selectedType;
        final emotionOk = _selectedEmotion == null ||
            l.emotionDetected == _selectedEmotion;
        return typeOk && emotionOk;
      }).toList();
    });
  }

  List<String> get _types => _logs
      .map((l) => l.interactionType ?? '')
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  List<String> get _emotions => _logs
      .map((l) => l.emotionDetected ?? '')
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  // Stats
  Map<String, int> get _emotionStats {
    final map = <String, int>{};
    for (final l in _logs) {
      if (l.emotionDetected != null && l.emotionDetected!.isNotEmpty) {
        map[l.emotionDetected!] = (map[l.emotionDetected!] ?? 0) + 1;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lịch sử tương tác'),
          Text(widget.elderlyProfile.name,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
          IconButton(
            icon: Badge(
              isLabelVisible:
                  _selectedType != null || _selectedEmotion != null,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: _showFilterSheet,
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
                      // Stats bar
                      if (_emotionStats.isNotEmpty) _buildEmotionStats(),
                      // Filter chips
                      if (_selectedType != null || _selectedEmotion != null)
                        _buildActiveFilters(),
                      // Count
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(children: [
                          Text('${_filtered.length} tương tác',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      // List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) =>
                                _LogCard(log: _filtered[i]),
                          ),
                        ),
                      ),
                    ]),
    );
  }

  Widget _buildEmotionStats() {
    return Container(
      height: 80,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Text('Cảm xúc',
                style: TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _emotionStats.entries.map((e) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _emotionColor(e.key).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_emotionEmoji(e.key),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text('${e.key} (${e.value})',
                        style: TextStyle(
                            fontSize: 11,
                            color: _emotionColor(e.key),
                            fontWeight: FontWeight.w700)),
                  ]),
                )).toList(),
              ),
            ),
          ]),
        ),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${_logs.length}',
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary)),
          const Text('tổng', style: TextStyle(
              fontSize: 11, color: AppTheme.textSecondary)),
        ]),
      ]),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        if (_selectedType != null)
          _FilterChip(
            label: _selectedType!,
            onRemove: () {
              setState(() => _selectedType = null);
              _applyFilter();
            },
          ),
        if (_selectedEmotion != null)
          _FilterChip(
            label: _emotionEmoji(_selectedEmotion!) + ' ' + _selectedEmotion!,
            onRemove: () {
              setState(() => _selectedEmotion = null);
              _applyFilter();
            },
          ),
        const Spacer(),
        TextButton(
          onPressed: () {
            setState(() { _selectedType = null; _selectedEmotion = null; });
            _applyFilter();
          },
          child: const Text('Xóa tất cả',
              style: TextStyle(fontSize: 12, color: AppTheme.danger)),
        ),
      ]),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Lọc', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            if (_types.isNotEmpty) ...[
              const Text('Loại tương tác',
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6,
                children: [
                  _SelectChip(
                    label: 'Tất cả',
                    selected: _selectedType == null,
                    onTap: () => setS(() => _selectedType = null),
                  ),
                  ..._types.map((t) => _SelectChip(
                    label: t,
                    selected: _selectedType == t,
                    onTap: () => setS(() => _selectedType = t),
                  )),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_emotions.isNotEmpty) ...[
              const Text('Cảm xúc',
                  style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6,
                children: [
                  _SelectChip(
                    label: 'Tất cả',
                    selected: _selectedEmotion == null,
                    onTap: () => setS(() => _selectedEmotion = null),
                  ),
                  ..._emotions.map((e) => _SelectChip(
                    label: '${_emotionEmoji(e)} $e',
                    selected: _selectedEmotion == e,
                    onTap: () => setS(() => _selectedEmotion = e),
                  )),
                ],
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _applyFilter();
                  Navigator.pop(context);
                },
                child: const Text('Áp dụng'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.chat_bubble_outline_rounded,
        size: 64, color: AppTheme.textSecondary.withOpacity(0.3)),
    const SizedBox(height: 16),
    const Text('Chưa có lịch sử tương tác',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary)),
  ]));

  Widget _buildError() => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
    const SizedBox(height: 8),
    Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
  ]));
}

// ─── Log Card ─────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final InteractionLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final dt = log.createdDateTime;
    final timeStr = dt != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(dt)
        : log.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            // Type badge
            if (log.interactionType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor(log.interactionType!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(log.interactionType!,
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _typeColor(log.interactionType!))),
              ),
            const Spacer(),
            // Emotion
            if (log.emotionDetected != null &&
                log.emotionDetected!.isNotEmpty) ...[
              Text(_emotionEmoji(log.emotionDetected!),
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(log.emotionDetected!,
                  style: TextStyle(
                      fontSize: 11,
                      color: _emotionColor(log.emotionDetected!),
                      fontWeight: FontWeight.w600)),
            ],
          ]),

          const SizedBox(height: 10),

          // User input
          if (log.userInputText != null && log.userInputText!.isNotEmpty) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    size: 14, color: AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(log.userInputText!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],

          // Robot response
          if (log.robotResponseText != null &&
              log.robotResponseText!.isNotEmpty) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.robotBlue.withOpacity(0.06),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(log.robotResponseText!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.robotBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    size: 14, color: AppTheme.robotBlue),
              ),
            ]),
            const SizedBox(height: 8),
          ],

          // Time + robot name
          Row(children: [
            const Icon(Icons.access_time_rounded,
                size: 12, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(timeStr, style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
            if (log.robotName != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.smart_toy_rounded,
                  size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(log.robotName!,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _typeColor(String type) {
  switch (type.toUpperCase()) {
    case 'VOICE': return AppTheme.primary;
    case 'REMINDER': return AppTheme.warning;
    case 'EXERCISE': return AppTheme.robotBlue;
    case 'CHAT': return AppTheme.success;
    default: return AppTheme.textSecondary;
  }
}

Color _emotionColor(String emotion) {
  switch (emotion.toUpperCase()) {
    case 'HAPPY': case 'VUI': return const Color(0xFFF59E0B);
    case 'SAD': case 'BUON': return const Color(0xFF6B7280);
    case 'ANGRY': case 'TUC': return AppTheme.danger;
    case 'SURPRISED': case 'NGAC_NHIEN': return AppTheme.elderlyPurple;
    case 'NEUTRAL': return AppTheme.textSecondary;
    default: return AppTheme.primary;
  }
}

String _emotionEmoji(String emotion) {
  switch (emotion.toUpperCase()) {
    case 'HAPPY': case 'VUI': return '😊';
    case 'SAD': case 'BUON': return '😢';
    case 'ANGRY': case 'TUC': return '😠';
    case 'SURPRISED': case 'NGAC_NHIEN': return '😮';
    case 'NEUTRAL': return '😐';
    case 'FEAR': return '😨';
    case 'DISGUST': return '😒';
    default: return '🤖';
  }
}

// ─── Small Widgets ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    margin: const EdgeInsets.only(right: 6),
    decoration: BoxDecoration(
      color: AppTheme.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, color: AppTheme.primary,
          fontWeight: FontWeight.w600)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close_rounded,
            size: 14, color: AppTheme.primary),
      ),
    ]),
  );
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary
            : AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppTheme.primary)),
    ),
  );
}
