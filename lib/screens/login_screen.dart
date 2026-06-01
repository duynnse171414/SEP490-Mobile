// lib/screens/login_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Floating bubbles animation
  late AnimationController _bubbleCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();

    _bubbleCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _bubbleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error!),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF134E4A), AppTheme.primaryDark, AppTheme.primary],
          ),
        ),
        child: Stack(
          children: [
            // Animated floating bubbles
            ..._buildBubbles(),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        children: [
                          // Logo & Robot
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 2),
                            ),
                            child: const Icon(Icons.smart_toy_rounded,
                                size: 55, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          const Text('Alpha Mini',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text('Quản lý gia đình thông minh',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(height: 40),

                          // Card form
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10))
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Đăng nhập',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary)),
                                  const SizedBox(height: 6),
                                  const Text('Dành cho thành viên gia đình',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary)),
                                  const SizedBox(height: 24),

                                  // Username
                                  TextFormField(
                                    controller: _usernameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Tên đăng nhập',
                                      prefixIcon: Icon(Icons.person_outline_rounded),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Vui lòng nhập tên đăng nhập'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'Mật khẩu',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined),
                                        onPressed: () => setState(() =>
                                            _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Vui lòng nhập mật khẩu'
                                        : null,
                                    onFieldSubmitted: (_) => _login(),
                                  ),

                                  // Forgot password link
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ForgotPasswordScreen()),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 0),
                                      ),
                                      child: const Text(
                                        'Quên mật khẩu?',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Login Button
                                  Consumer<AuthProvider>(
                                    builder: (_, auth, __) => SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: auth.isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          backgroundColor: AppTheme.primary,
                                        ),
                                        child: auth.isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white))
                                            : const Text('ĐĂNG NHẬP',
                                                style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Chưa có tài khoản?',
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 14)),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
                                ),
                                child: const Text('Đăng ký',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.85)),
                                const SizedBox(width: 6),
                                Text('Chỉ tài khoản FAMILYMEMBER được phép',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.85))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBubbles() {
    const bubbles = [
      _BubbleData(size: 180, top: -60, left: -50, phase: 0.0),
      _BubbleData(size: 80, top: 80, right: -20, phase: 0.3),
      _BubbleData(size: 120, top: 160, left: -30, phase: 0.6),
      _BubbleData(size: 60, top: 260, right: 30, phase: 1.2),
      _BubbleData(size: 100, bottom: 200, left: 20, phase: 0.9),
      _BubbleData(size: 50, bottom: 320, right: 50, phase: 1.5),
      _BubbleData(size: 140, bottom: -50, right: -40, phase: 0.4),
      _BubbleData(size: 70, bottom: 100, left: -20, phase: 1.8),
    ];

    return bubbles.map((b) => AnimatedBuilder(
      animation: _bubbleCtrl,
      builder: (_, __) {
        final val = _bubbleCtrl.value;
        final offset = math.sin((val + b.phase) * 2 * math.pi) * 12.0;
        return Positioned(
          top: b.top != null ? b.top! + offset : null,
          bottom: b.bottom != null ? b.bottom! - offset : null,
          left: b.left,
          right: b.right,
          child: Container(
            width: b.size,
            height: b.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
        );
      },
    )).toList();
  }
}

class _BubbleData {
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double phase;
  const _BubbleData({
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.phase,
  });
}
