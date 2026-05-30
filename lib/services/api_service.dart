// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
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

  static Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      try {
        final d = json.decode(res.body);
        if (d is Map<String, dynamic>) return d;
        return {'data': d};
      } catch (_) { return {}; }
    }
    String msg = 'Lỗi ${res.statusCode}';
    try { final b = json.decode(res.body); msg = b['message'] ?? b['error'] ?? msg; }
    catch (_) {}
    throw ApiException(msg, statusCode: res.statusCode);
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
    String msg = 'Lỗi ${res.statusCode}';
    try { final b = json.decode(res.body); msg = b['message'] ?? b['error'] ?? msg; }
    catch (_) {}
    throw ApiException(msg, statusCode: res.statusCode);
  }

  // ─── AUTH ──────────────────────────────────────────────────────────────────
  static Future<User> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}${ApiEndpoints.login}'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 30));
    final data = await _handleResponse(res);
    final user = User.fromJson(data);
    _currentAccountId = user.id;
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
      throw ApiException('Không thể xóa', statusCode: res.statusCode);
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
  // ─── INTERACTION LOGS ──────────────────────────────────────────────────────
  static Future<List<dynamic>> getInteractionLogs(int elderlyId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/api/interaction-logs?elderlyId=$elderlyId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 30));
    return _handleListResponse(res);
  }

}