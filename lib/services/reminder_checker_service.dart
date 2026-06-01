// lib/services/reminder_checker_service.dart
//
// Chạy ngầm trong Flutter app — không cần main.py.
// Mỗi 60 giây: fetch reminders của tất cả elderly trong tài khoản,
// kiểm tra giờ, tạo log khi đến giờ, tạo alert sau 5 phút nếu chưa xác nhận.

import 'dart:async';
import '../models/models.dart';
import '../services/api_service.dart';

class ReminderCheckerService {
  // Singleton
  ReminderCheckerService._();
  static final ReminderCheckerService instance = ReminderCheckerService._();

  // Danh sách elderly được set từ ngoài vào (cập nhật khi thêm/xóa elderly)
  List<ElderlyProfile> profiles = [];

  // Đã xử lý trong ngày: key = "elderlyId_reminderId_date(yyyy-MM-dd)"
  final Set<String> _processedToday = {};
  DateTime? _lastResetDate;

  // Pending alert timers: sau khi tạo log, chờ 5 phút rồi tạo alert nếu chưa confirm
  // key = logId, value = Timer
  final Map<int, Timer> _alertTimers = {};

  // Danh sách logId đã được confirm (nhận từ bên ngoài)
  final Set<int> _confirmedLogIds = {};

  Timer? _pollTimer;
  static const _pollInterval  = Duration(minutes: 1);
  static const _alertDelay    = Duration(minutes: 5);
  static const _windowMinutes = 2; // cửa sổ thời gian khớp giờ reminder (±2 phút)

  bool _running = false;

  // ── Khởi động / dừng ────────────────────────────────────────────────────────

  void start() {
    if (_running) return;
    _running = true;
    // Catchup reminders đã qua giờ hôm nay mà chưa có log
    _catchupMissedReminders();
    // Chạy ngay lần đầu, rồi mỗi 60 giây
    _checkAll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkAll());
  }

  void stop() {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final t in _alertTimers.values) {
      t.cancel();
    }
    _alertTimers.clear();
  }

  /// Gọi từ bên ngoài khi người dùng xác nhận log (nhấn "Đã làm")
  void markConfirmed(int logId) {
    _confirmedLogIds.add(logId);
    _alertTimers[logId]?.cancel();
    _alertTimers.remove(logId);
  }

  // ── Logic chính ─────────────────────────────────────────────────────────────

  Future<void> _checkAll() async {
    if (!ApiService.currentAccountId.hasValue) return;
    _resetIfNewDay();

    for (final profile in profiles) {
      await _checkForElderly(profile);
    }
  }

  Future<void> _checkForElderly(ElderlyProfile profile) async {
    List<Reminder> reminders;
    try {
      reminders = await ApiService.getRemindersByElderly(profile.id);
    } catch (_) {
      return;
    }

    final now = DateTime.now();
    final todayStr = _dateStr(now);

    for (final r in reminders) {
      if (!r.active) continue;

      final key = '${profile.id}_${r.id}_$todayStr';
      if (_processedToday.contains(key)) continue;

      final scheduledTime = _resolveTimeToday(r);
      if (scheduledTime == null) continue;

      final diff = now.difference(scheduledTime).inMinutes;
      // Đến giờ: trong khoảng [0, +windowMinutes]
      if (diff < 0 || diff > _windowMinutes) continue;

      // Kiểm tra đã có log hôm nay chưa (tránh tạo trùng khi app restart)
      final alreadyLogged = await _hasLogToday(r.id, profile.id, now);
      if (alreadyLogged) {
        _processedToday.add(key);
        continue;
      }

      // Tạo reminder log
      _processedToday.add(key);
      final logId = await ApiService.createReminderLog(r.id, profile.id);

      // Schedule alert sau 5 phút nếu chưa confirm
      if (logId != null) {
        _scheduleAlert(
          logId: logId,
          profile: profile,
          reminderTitle: r.title,
        );
      }
    }
  }

  void _scheduleAlert({
    required int logId,
    required ElderlyProfile profile,
    required String reminderTitle,
  }) {
    _alertTimers[logId]?.cancel();
    _alertTimers[logId] = Timer(_alertDelay, () async {
      if (_confirmedLogIds.contains(logId)) return;
      // Chưa confirm → tạo alert
      await ApiService.createAlert(
        elderlyId: profile.id,
        elderlyName: profile.name,
        message: '${profile.name} chưa xác nhận: $reminderTitle',
        reminderLogId: logId,
      );
      _alertTimers.remove(logId);
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Khi app khởi động hoặc đầu ngày mới: tạo log + alert ngay cho những
  /// reminder đã qua giờ hôm nay mà chưa có log (app bị đóng lúc đến giờ).
  Future<void> _catchupMissedReminders() async {
    if (!ApiService.currentAccountId.hasValue) return;
    final now = DateTime.now();
    final todayStr = _dateStr(now);

    for (final profile in profiles) {
      List<Reminder> reminders;
      try {
        reminders = await ApiService.getRemindersByElderly(profile.id);
      } catch (_) {
        continue;
      }

      for (final r in reminders) {
        if (!r.active) continue;

        final key = '${profile.id}_${r.id}_$todayStr';
        if (_processedToday.contains(key)) continue;

        final scheduledTime = _resolveTimeToday(r);
        if (scheduledTime == null) continue;

        final diff = now.difference(scheduledTime).inMinutes;
        // Chỉ xử lý reminder đã qua cửa sổ bình thường (> 2 phút)
        if (diff <= _windowMinutes || diff < 0) continue;

        // Kiểm tra đã có log hôm nay chưa
        final alreadyLogged = await _hasLogToday(r.id, profile.id, now);
        if (alreadyLogged) {
          _processedToday.add(key);
          continue;
        }

        // Tạo log + alert ngay (missed)
        _processedToday.add(key);
        final logId = await ApiService.createReminderLog(r.id, profile.id);
        if (logId != null) {
          await ApiService.createAlert(
            elderlyId: profile.id,
            elderlyName: profile.name,
            message: '${profile.name} chưa xác nhận: ${r.title}',
            reminderLogId: logId,
          );
        }
      }
    }
  }

  void _resetIfNewDay() {
    final today = DateTime.now();
    if (_lastResetDate == null || _lastResetDate!.day != today.day) {
      _processedToday.clear();
      _confirmedLogIds.clear();
      _lastResetDate = today;
      // Đầu ngày mới: catchup reminder hôm qua bị bỏ lỡ (nếu có)
      _catchupMissedReminders();
    }
  }

  /// Tính giờ reminder áp vào ngày hôm nay (xử lý DAILY).
  DateTime? _resolveTimeToday(Reminder r) {
    final scheduled = r.scheduleDateTime;
    if (scheduled == null) return null;
    final repeat = (r.repeatPattern ?? '').toUpperCase();
    final now = DateTime.now();
    if (repeat == 'DAILY' || repeat == 'EVERYDAY') {
      return DateTime(now.year, now.month, now.day,
          scheduled.hour, scheduled.minute, scheduled.second);
    }
    // Non-repeat: chỉ áp dụng đúng ngày
    if (scheduled.year == now.year &&
        scheduled.month == now.month &&
        scheduled.day == now.day) {
      return scheduled;
    }
    return null;
  }

  /// Kiểm tra API xem đã có log cho reminder này hôm nay chưa.
  Future<bool> _hasLogToday(int reminderId, int elderlyId, DateTime today) async {
    try {
      final logs = await ApiService.getReminderLogsByElderly(elderlyId);
      return logs.any((log) {
        if (log.reminderId != reminderId) return false;
        final t = log.triggeredDateTime;
        if (t == null) return false;
        return t.year == today.year && t.month == today.month && t.day == today.day;
      });
    } catch (_) {
      return false;
    }
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

extension on int? {
  bool get hasValue => this != null;
}
