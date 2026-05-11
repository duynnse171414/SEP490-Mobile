// lib/services/auth_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../utils/constants.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.userKey);
    if (raw != null) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        _user = User.fromJson(decoded);
        ApiService.setToken(_user!.token);
        notifyListeners();
      } catch (_) {
        await prefs.remove(AppConstants.userKey);
      }
    }
  }

  /// Login bằng email + password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await ApiService.login(email.trim(), password);

      // Kiểm tra role — cập nhật allowedRoles trong constants.dart
      // khi biết chính xác role của FAMILY trong hệ thống
      if (!AppConstants.allowedRoles.contains(user.role)) {
        _error =
            'Tài khoản "${user.role}" không có quyền truy cập.\nChỉ tài khoản FAMILY được phép.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Kiểm tra trạng thái tài khoản
      if (user.status != 'ACTIVE') {
        _error = 'Tài khoản chưa được kích hoạt hoặc đã bị khóa.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _user = user;
      ApiService.setToken(user.token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userKey, json.encode(user.toJson()));

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Không thể kết nối server. Vui lòng kiểm tra mạng.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    ApiService.clearToken();
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
    notifyListeners();
  }
}
