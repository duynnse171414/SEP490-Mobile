// lib/screens/reminders_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class RemindersScreen extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const RemindersScreen({super.key, required this.elderlyProfile});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Reminder> _reminders = [];
  List<ReminderLog> _logs = [];
  bool _loadingReminders = true;
  bool _loadingLogs = true;
  String? _errorReminders;
  String? _errorLogs;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadReminders();
    _loadLogs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ─── Load data ─────────────────────────────────────────────────────────────

  Future<void> _loadReminders() async {
    setState(() { _loadingReminders = true; _errorReminders = null; });
    try {
      final list = await ApiService.getRemindersByElderly(widget.elderlyProfile.id);
      setState(() { _reminders = list; _loadingReminders = false; });
      // Alert nếu có reminder chưa active
      final inactive = list.where((r) => !r.active).toList();
      if (inactive.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showInactiveAlert(inactive);
        });
      }
    } on ApiException catch (e) {
      setState(() { _errorReminders = e.message; _loadingReminders = false; });
    } catch (_) {
      setState(() { _errorReminders = 'Không thể tải nhắc nhở'; _loadingReminders = false; });
    }
  }

  Future<void> _loadLogs() async {
    setState(() { _loadingLogs = true; _errorLogs = null; });
    try {
      final list = await ApiService.getReminderLogsByElderly(widget.elderlyProfile.id);
      setState(() { _logs = list; _loadingLogs = false; });
    } on ApiException catch (e) {
      setState(() { _errorLogs = e.message; _loadingLogs = false; });
    } catch (_) {
      setState(() { _errorLogs = 'Không thể tải lịch sử'; _loadingLogs = false; });
    }
  }

  void _showInactiveAlert(List<Reminder> inactive) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.notification_important_rounded,
                color: AppTheme.warning),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Nhắc nhở chưa kích hoạt', style: TextStyle(fontSize: 16))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.elderlyProfile.name} có ${inactive.length} nhắc nhở chưa active:',
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ...inactive.take(3).map((r) {
              final dt = r.scheduleDateTime;
              final t = dt != null ? DateFormat('HH:mm dd/MM').format(dt) : r.scheduleTime;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppTheme.warning, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(t, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
              );
            }),
            if (inactive.length > 3)
              Text('...và ${inactive.length - 3} nhắc nhở khác',
                  style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _addReminder() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddReminderSheet(elderlyProfile: widget.elderlyProfile),
    );
    if (result == true) { _loadReminders(); _loadLogs(); }
  }

  Future<void> _deleteReminder(Reminder r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa nhắc nhở'),
        content: Text('Xóa "${r.title}"?'),
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
        await ApiService.deleteReminder(r.id);
        _loadReminders();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa'), backgroundColor: AppTheme.success));
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
      }
    }
  }

  Future<void> _confirmLog(ReminderLog log) async {
    try {
      await ApiService.confirmReminderLog(log.id);
      _loadLogs();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã xác nhận!'), backgroundColor: AppTheme.success));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unconfirmedLogs = _logs.where((l) => !l.confirmed).length;

    return Column(children: [
      // Tab bar
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            const Tab(icon: Icon(Icons.alarm_rounded, size: 18), text: 'Nhắc nhở'),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.history_rounded, size: 18),
                  if (unconfirmedLogs > 0)
                    Positioned(
                      right: -6, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                        child: Text('$unconfirmedLogs',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              text: 'Lịch sử log',
            ),
          ],
        ),
      ),

      // Tab content
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildRemindersTab(),
            _buildLogsTab(),
          ],
        ),
      ),
    ]);
  }

  // ── Tab 1: Reminders ───────────────────────────────────────────────────────

  Widget _buildRemindersTab() {
    final inactiveCount = _reminders.where((r) => !r.active).length;
    return Column(children: [
      // Alert banner
      if (!_loadingReminders && inactiveCount > 0)
        GestureDetector(
          onTap: () => _showInactiveAlert(_reminders.where((r) => !r.active).toList()),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
              const SizedBox(width: 10),
              Expanded(child: Text('$inactiveCount nhắc nhở chưa kích hoạt',
                  style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.warning),
            ]),
          ),
        ),

      Expanded(
        child: _loadingReminders
            ? const Center(child: CircularProgressIndicator())
            : _errorReminders != null
                ? _buildError(_errorReminders!, _loadReminders)
                : _reminders.isEmpty
                    ? _buildEmpty('Chưa có nhắc nhở nào', Icons.alarm_off_rounded)
                    : RefreshIndicator(
                        onRefresh: _loadReminders,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                          itemCount: _reminders.length,
                          itemBuilder: (_, i) => _ReminderCard(
                            reminder: _reminders[i],
                            onDelete: () => _deleteReminder(_reminders[i]),
                          ),
                        ),
                      ),
      ),

      // Add button
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addReminder,
            icon: const Icon(Icons.add_alarm_rounded),
            label: const Text('Thêm nhắc nhở'),
          ),
        ),
      ),
    ]);
  }

  // ── Tab 2: Reminder Logs ───────────────────────────────────────────────────

  Widget _buildLogsTab() {
    final unconfirmed = _logs.where((l) => !l.confirmed).toList();
    final confirmed = _logs.where((l) => l.confirmed).toList();

    return _loadingLogs
        ? const Center(child: CircularProgressIndicator())
        : _errorLogs != null
            ? _buildError(_errorLogs!, _loadLogs)
            : _logs.isEmpty
                ? _buildEmpty('Chưa có lịch sử nhắc nhở', Icons.history_rounded)
                : RefreshIndicator(
                    onRefresh: _loadLogs,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      children: [
                        // ── Chưa xác nhận ──
                        if (unconfirmed.isNotEmpty) ...[
                          _sectionHeader(
                            '⚠️ Chưa xác nhận (${unconfirmed.length})',
                            AppTheme.warning,
                          ),
                          const SizedBox(height: 8),
                          ...unconfirmed.map((log) => _LogCard(
                                log: log,
                                onConfirm: () => _confirmLog(log),
                              )),
                          const SizedBox(height: 16),
                        ],

                        // ── Đã xác nhận ──
                        if (confirmed.isNotEmpty) ...[
                          _sectionHeader(
                            '✅ Đã xác nhận (${confirmed.length})',
                            AppTheme.success,
                          ),
                          const SizedBox(height: 8),
                          ...confirmed.map((log) => _LogCard(log: log)),
                        ],
                      ],
                    ),
                  );
  }

  Widget _sectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(title,
          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
    );
  }

  Widget _buildEmpty(String msg, IconData icon) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 60, color: AppTheme.textSecondary.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _buildError(String msg, VoidCallback retry) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
      const SizedBox(height: 8),
      Text(msg, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: retry, child: const Text('Thử lại')),
    ]));
  }
}

// ── Reminder Card ──────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onDelete;
  const _ReminderCard({required this.reminder, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dt = reminder.scheduleDateTime;
    final timeStr = dt != null ? DateFormat('HH:mm - dd/MM/yyyy').format(dt) : reminder.scheduleTime;
    final active = reminder.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: active ? AppTheme.success.withOpacity(0.3) : AppTheme.warning.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(active ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                color: active ? AppTheme.success : AppTheme.warning),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(reminder.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (reminder.reminderType != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.label_outline, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(reminder.reminderType!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ],
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ]),
            if (reminder.repeatPattern != null) ...[
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.repeat_rounded, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(reminder.repeatPattern!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ]),
            ],
          ])),
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active ? AppTheme.success.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(active ? 'Active' : 'Inactive',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: active ? AppTheme.success : AppTheme.warning)),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Log Card ───────────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final ReminderLog log;
  final VoidCallback? onConfirm;
  const _LogCard({required this.log, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final triggered = log.triggeredDateTime;
    final confirmedDt = log.confirmedDateTime;
    final triggeredStr = triggered != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(triggered)
        : log.triggeredTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: log.confirmed
              ? AppTheme.success.withOpacity(0.25)
              : AppTheme.warning.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: log.confirmed
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                log.confirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: log.confirmed ? AppTheme.success : AppTheme.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.reminderTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (log.robotName != null)
                Row(children: [
                  const Icon(Icons.smart_toy_rounded, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(log.robotName!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: log.confirmed
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(log.confirmed ? 'Đã xác nhận' : 'Chưa xác nhận',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: log.confirmed ? AppTheme.success : AppTheme.warning)),
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Triggered time
          Row(children: [
            const Icon(Icons.notifications_rounded, size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text('Kích hoạt: $triggeredStr',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ]),

          // Confirmed time
          if (log.confirmed && confirmedDt != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.check_rounded, size: 13, color: AppTheme.success),
              const SizedBox(width: 6),
              Text('Xác nhận: ${DateFormat('HH:mm - dd/MM/yyyy').format(confirmedDt)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.success)),
            ]),
          ],

          // Confirm button nếu chưa confirm
          if (!log.confirmed && onConfirm != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Xác nhận đã thực hiện'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Add Reminder Bottom Sheet ──────────────────────────────────────────────────

class _AddReminderSheet extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const _AddReminderSheet({required this.elderlyProfile});

  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  DateTime? _scheduleDateTime;
  String? _reminderType;
  String? _repeatPattern;
  bool _active = true;
  bool _isLoading = false;

  @override
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;
    setState(() => _scheduleDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Vui lòng chọn thời gian'), backgroundColor: AppTheme.warning));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService.createReminder(ReminderRequest(
        elderlyId: widget.elderlyProfile.id,
        title: _titleCtrl.text.trim(),
        reminderType: _reminderType,
        scheduleTime: _scheduleDateTime!.toUtc().toIso8601String(),
        repeatPattern: _repeatPattern,
        active: _active,
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
    final dtStr = _scheduleDateTime != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(_scheduleDateTime!)
        : 'Chọn ngày & giờ';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Thêm nhắc nhở',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Tiêu đề *', prefixIcon: Icon(Icons.title_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
          ),
          const SizedBox(height: 12),

          // DateTime picker
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: _scheduleDateTime != null
                    ? Border.all(color: AppTheme.primary, width: 2) : null,
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    color: _scheduleDateTime != null ? AppTheme.primary : AppTheme.textSecondary),
                const SizedBox(width: 12),
                Text(dtStr, style: TextStyle(
                    color: _scheduleDateTime != null ? AppTheme.textPrimary : AppTheme.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _reminderType,
                decoration: const InputDecoration(labelText: 'Loại', prefixIcon: Icon(Icons.label_outline)),
                items: const [
                  DropdownMenuItem(value: 'MEDICINE', child: Text('Uống thuốc')),
                  DropdownMenuItem(value: 'EXERCISE', child: Text('Tập thể dục')),
                  DropdownMenuItem(value: 'MEAL', child: Text('Ăn uống')),
                  DropdownMenuItem(value: 'CHECKUP', child: Text('Khám bệnh')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => _reminderType = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _repeatPattern,
                decoration: const InputDecoration(labelText: 'Lặp lại', prefixIcon: Icon(Icons.repeat_rounded)),
                items: const [
                  DropdownMenuItem(value: 'DAILY', child: Text('Hàng ngày')),
                  DropdownMenuItem(value: 'WEEKLY', child: Text('Hàng tuần')),
                  DropdownMenuItem(value: 'MONTHLY', child: Text('Hàng tháng')),
                  DropdownMenuItem(value: 'NONE', child: Text('Không lặp')),
                ],
                onChanged: (v) => setState(() => _repeatPattern = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          Row(children: [
            const Text('Kích hoạt ngay:', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Switch(value: _active, onChanged: (v) => setState(() => _active = v),
                activeColor: AppTheme.primary),
          ]),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('LƯU NHẮC NHỞ'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}
