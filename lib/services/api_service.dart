// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static String? _token;
  static int? _currentAccountId;

  static void setToken(String token) => _token = token;
  static void setAccountId(int id) => _currentAccountId = id;
  static int? get currentAccountId => _currentAccountId;
  static void clearToken() { _token = null; _currentAccountId = null; }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static String _extractErrorMsg(http.Response res) {
    String msg = 'Lỗi ${res.statusCode}';
    try {
      final b = json.decode(res.body);
      msg = b['message'] ?? b['error'] ?? b['detail'] ?? msg;
      if ((msg == 'Bad Request' || msg.startsWith('Lỗi ')) && res.body.isNotEmpty) {
        msg = res.body;
      }
    } catch (_) {
      if (res.body.isNotEmpty) msg = res.body;
    }
    return msg;
  }

  static Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      try {
        final d = json.decode(res.body);
        if (d is Map<String, dynamic>) return d;
        return {'data': d};
      } catch (_) { return {}; }
    }
    throw ApiException(_extractErrorMsg(res), statusCode: res.statusCode);
  }

  static Future<List<dynamic>> _handleListResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return [];
      try {
        final d = json.decode(res.body);
        if (d is List) return d;
        if (d is Map<String, dynamic>) {
          for (final k in ['data', 'content', 'items', 'result', 'list']) {
            if (d[k] is List) return d[k] as List;
          }
        }
        return [];
      } catch (_) { return []; }
    }
    throw ApiException(_extractErrorMsg(res), statusCode: res.statusCode);
  }

  // ─── AUTH ──────────────────────────────────────────────────────────────────
  // ─── Robot server URL (same host as camera, port 8080) ────────────────────
  static String? _robotBaseUrl;
  static void setRobotUrl(String url) => _robotBaseUrl = url;

  /// Thử probe 1 IP xem có robot server không
  static Future<String?> _probeRobot(String ip) async {
    try {
      final res = await http.get(Uri.parse('http://$ip:8080/status'))
          .timeout(const Duration(milliseconds: 600));
      if (res.statusCode == 200) return 'http://$ip:8080';
    } catch (_) {}
    return null;
  }

  /// Scan subnet tìm robot server (dùng khi chưa có URL lưu)
  static Future<String?> _discoverRobot() async {
    final candidates = <String>[];
    for (int i = 1; i <= 10; i++) { candidates.add('172.20.10.$i'); }
    for (int i = 1; i <= 10; i++) { candidates.add('192.168.1.$i'); }
    for (int i = 1; i <= 10; i++) { candidates.add('192.168.0.$i'); }
    final results = await Future.wait(candidates.map(_probeRobot));
    return results.whereType<String>().firstOrNull;
  }

  /// Gửi token lên robot server sau khi login (best-effort, không throw)
  static Future<void> pushTokenToRobot(User user) async {
    String? url = _robotBaseUrl;

    // Nếu chưa có URL → tự scan tìm robot
    if (url == null || url.isEmpty) {
      url = await _discoverRobot();
      if (url != null) {
        _robotBaseUrl = url;
        // Lưu lại để lần sau dùng
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('camera_base_url', url);
        } catch (_) {}
      }
    }

    if (url == null) return; // Không tìm thấy robot

    try {
      await http.post(
        Uri.parse('$url/set-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': user.token,
          'accountId': user.id,
          'email': user.email,
        }),
      ).timeout(const Duration(seconds: 5));
      // Token sent successfully
    } catch (_) {}
  }

  /// Trigger robot refresh elderly profiles (best-effort)
  static Future<void> refreshRobotProfiles() async {
    final url = _robotBaseUrl;
    if (url == null || url.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$url/refresh-profiles'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<User> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.login}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    final user = User.fromJson(data);
    _currentAccountId = user.id;
    // Gửi token lên robot (không chặn luồng chính)
    pushTokenToRobot(user);
    return user;
  }

  static Future<void> logout() async {
    try {
      await http.post(Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.logout}'),
          headers: _headers).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<void> register({
    required String fullName,
    required String gender,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.register}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({
        'fullName': fullName,
        'gender': gender,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(res);
  }

  static Future<void> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.forgotPassword}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({'email': email}),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(res);
  }

  static Future<void> verifyOtp(String email, String otp) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.verifyOtp}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({'email': email, 'otp': otp}),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(res);
  }

  static Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.resetPassword}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(res);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.changePassword}'),
      headers: _headers,
      body: json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    ).timeout(const Duration(seconds: 30));
    await _handleResponse(res);
  }

  // ─── ELDERLY PROFILE ───────────────────────────────────────────────────────
  static Future<List<ElderlyProfile>> getElderlyProfiles() async {
    final accountId = _currentAccountId;
    if (accountId == null) throw ApiException('Chưa đăng nhập');
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.elderlyByAccount(accountId)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => ElderlyProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ElderlyProfile> createElderlyProfile(ElderlyProfileRequest request) async {
    final accountId = _currentAccountId;
    if (accountId == null) throw ApiException('Chưa đăng nhập');
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.createElderlyForAccount(accountId)}'),
      headers: _headers,
      body: json.encode(request.toJson()),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    return ElderlyProfile.fromJson(data);
  }

  static Future<void> deleteElderlyProfile(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.elderlyProfileById(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Không thể xóa hồ sơ', statusCode: res.statusCode);
    }
  }

  // ─── REMINDER ──────────────────────────────────────────────────────────────
  static Future<List<Reminder>> getRemindersByElderly(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.remindersByElderly(elderlyId)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Reminder> createReminder(ReminderRequest request) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.reminders}'),
      headers: _headers,
      body: json.encode(request.toJson()),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    return Reminder.fromJson(data);
  }

  static Future<void> deleteReminder(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.reminderById(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Không thể xóa nhắc nhở', statusCode: res.statusCode);
    }
  }

  // ─── REMINDER LOG ──────────────────────────────────────────────────────────
  static Future<int?> createReminderLog(int reminderId, int elderlyId) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/reminder-logs'),
      headers: _headers,
      body: json.encode({
        'reminderId': reminderId,
        'elderlyId': elderlyId,
        'triggeredTime': DateTime.now().toUtc().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = json.decode(res.body);
      return data['id'] as int?;
    }
    return null;
  }

  static Future<List<ReminderLog>> getReminderLogsByElderly(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.reminderLogsByElderly(elderlyId)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => ReminderLog.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> confirmReminderLog(int logId) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.confirmReminderLog(logId)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Không thể xác nhận', statusCode: res.statusCode);
    }
  }

  // ─── EXERCISE ──────────────────────────────────────────────────────────────
  static Future<List<Exercise>> getExercises() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.exercises}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Exercise> createExercise(Exercise exercise) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.exercises}'),
      headers: _headers,
      body: json.encode(exercise.toCreateJson()),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    return Exercise.fromJson(data);
  }

  static Future<void> deleteExercise(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.exerciseById(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Không thể xóa bài tập', statusCode: res.statusCode);
    }
  }

  static Future<void> sendExerciseToRobot(int id) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.sendExerciseToRobot(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Không thể gửi đến robot', statusCode: res.statusCode);
    }
  }


  // ─── ALERT NOTIFICATION ────────────────────────────────────────────────────
  static Future<List<AlertNotification>> getAlertsByElderly(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.alertsByElderly(elderlyId)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => AlertNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<AlertNotification>> getAllAlerts() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.alerts}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => AlertNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createAlert({
    required int elderlyId,
    required String elderlyName,
    required String message,
    int? reminderLogId,
  }) async {
    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.alerts}'),
        headers: _headers,
        body: json.encode({
          'elderlyId': elderlyId,
          'elderlyName': elderlyName,
          'alertType': 'MEDICATION_MISSED',
          'message': message,
          'resolved': false,
          if (reminderLogId != null) 'reminderLogId': reminderLogId,
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  static Future<void> resolveAlert(AlertNotification alert) async {
    final res = await http.put(
      Uri.parse('${AppConstants.baseUrl}/api/alerts/${alert.id}'),
      headers: _headers,
      body: json.encode({
        'elderlyId': alert.elderlyId,
        'alertType': alert.alertType,
        'message': alert.message,
        'resolved': true,
        if (alert.reminderLogId != null) 'reminderLogId': alert.reminderLogId,
      }),
    ).timeout(const Duration(seconds: 30));
    _handleResponse(res);
  }

  // ─── ACTION LIBRARY ────────────────────────────────────────────────────────
  static Future<List<ActionLibrary>> getActionLibrary() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.actionLibrary}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list.map((e) => ActionLibrary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ActionLibrary> createActionLibrary(ActionLibrary action) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.actionLibrary}'),
      headers: _headers,
      body: json.encode(action.toCreateJson()),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    return ActionLibrary.fromJson(data);
  }

  static Future<void> deleteActionLibrary(int id) async {
    final res = await http.delete(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.actionLibraryById(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_extractErrorMsg(res), statusCode: res.statusCode);
    }
  }

  // ─── ROBOT ACTION ──────────────────────────────────────────────────────────
  /// Gửi lệnh thực hiện động tác đến robot
  /// POST /api/robot-action với { action: code, executed: false }
  static Future<RobotAction> sendRobotAction(String actionCode) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.robotAction}'),
      headers: _headers,
      body: json.encode({'action': actionCode, 'executed': false}),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    return RobotAction.fromJson(data);
  }

  static Future<void> markRobotActionDone(int id) async {
    await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.robotActionDone(id)}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
  }
  // Thêm vào cuối file lib/services/api_service.dart

  // ─── SERVICE PACKAGES ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getServicePackages() async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/service-packages'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    final list = await _handleListResponse(res);
    return list;
  }

  // ─── PAYMENT ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createPayment(
      int servicePackageId, int elderlyProfileId) async {
    final res = await http.post(
      Uri.parse(
          '${AppConstants.baseUrl}/api/payments/create/$servicePackageId'
          '?elderlyProfileId=$elderlyProfileId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    return _handleResponse(res);
  }
  static Future<List<dynamic>> getUserPackagesByElderly(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/user-packages/elderly/$elderlyId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    return _handleListResponse(res);
  }

  // ─── INTERACTION LOGS ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getInteractionLogs(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/interaction-logs/elderly/$elderlyId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    return _handleListResponse(res);
  }

}