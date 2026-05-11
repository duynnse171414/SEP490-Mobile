// lib/screens/alert_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class AlertScreen extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const AlertScreen({super.key, required this.elderlyProfile});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  List<AlertNotification> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await ApiService.getAlertsByElderly(widget.elderlyProfile.id);
      // Sắp xếp: chưa giải quyết lên trên, mới nhất lên đầu
      list.sort((a, b) {
        if (a.resolved != b.resolved) return a.resolved ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
      setState(() { _alerts = list; _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Không thể tải cảnh báo'; _isLoading = false; });
    }
  }

  int get _unresolvedCount => _alerts.where((a) => !a.resolved).length;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Summary banner nếu có alert chưa giải quyết
      if (!_isLoading && _unresolvedCount > 0)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.danger, Color(0xFFFF6B6B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.danger.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '$_unresolvedCount cảnh báo chưa giải quyết!',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '${widget.elderlyProfile.name} không phản hồi nhắc nhở',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
              ),
            ])),
            const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 28),
          ]),
        ),

      // List
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _alerts.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: _alerts.length,
                          itemBuilder: (_, i) => _AlertCard(alert: _alerts[i]),
                        ),
                      ),
      ),
    ]);
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline_rounded,
          size: 72, color: AppTheme.success.withOpacity(0.6)),
      const SizedBox(height: 16),
      const Text('Không có cảnh báo!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.success)),
      const SizedBox(height: 8),
      Text('${widget.elderlyProfile.name} đang phản hồi tốt',
          style: const TextStyle(color: AppTheme.textSecondary)),
    ]));
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
      const SizedBox(height: 8),
      Text(_error!, textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
    ]));
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AlertNotification alert;
  const _AlertCard({required this.alert});

  IconData get _typeIcon {
    switch (alert.alertType?.toUpperCase()) {
      case 'NO_RESPONSE': return Icons.notifications_off_rounded;
      case 'MISSED':      return Icons.alarm_off_rounded;
      case 'EMERGENCY':   return Icons.emergency_rounded;
      default:            return Icons.warning_amber_rounded;
    }
  }

  String get _typeLabel {
    switch (alert.alertType?.toUpperCase()) {
      case 'NO_RESPONSE': return 'Không phản hồi';
      case 'MISSED':      return 'Bỏ lỡ nhắc nhở';
      case 'EMERGENCY':   return 'Khẩn cấp';
      default:            return alert.alertType ?? 'Cảnh báo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolved = alert.resolved;
    final dt = alert.createdDateTime;
    final timeStr = dt != null
        ? DateFormat('HH:mm - dd/MM/yyyy').format(dt)
        : alert.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: resolved
              ? Colors.grey.withOpacity(0.2)
              : AppTheme.danger.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Icon type
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: resolved
                    ? Colors.grey.withOpacity(0.1)
                    : AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon,
                  color: resolved ? AppTheme.textSecondary : AppTheme.danger,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_typeLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: resolved ? AppTheme.textSecondary : AppTheme.danger)),
              if (alert.elderlyName != null)
                Row(children: [
                  const Icon(Icons.person_outline, size: 12, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(alert.elderlyName!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ]),
            ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: resolved
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  resolved ? Icons.check_circle_rounded : Icons.error_rounded,
                  size: 12,
                  color: resolved ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  resolved ? 'Đã xử lý' : 'Chưa xử lý',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: resolved ? AppTheme.success : AppTheme.danger),
                ),
              ]),
            ),
          ]),

          if (alert.message != null && alert.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: resolved
                    ? Colors.grey.withOpacity(0.05)
                    : AppTheme.danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(alert.message!,
                  style: TextStyle(
                      fontSize: 13,
                      color: resolved ? AppTheme.textSecondary : AppTheme.textPrimary)),
            ),
          ],

          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(timeStr,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (alert.reminderLogId != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.link_rounded, size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('Log #${alert.reminderLogId}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ]),
        ]),
      ),
    );
  }
}
