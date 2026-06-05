import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';
import 'verify_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _fullNameCtrl      = TextEditingController();
  final _emailCtrl         = TextEditingController();
  final _phoneCtrl         = TextEditingController();
  final _passwordCtrl      = TextEditingController();
  final _confirmCtrl       = TextEditingController();
  String _gender           = 'Male';
  bool _obscurePassword    = true;
  bool _obscureConfirm     = true;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      fullName: _fullNameCtrl.text.trim(),
      gender:   _gender,
      email:    _emailCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VerifyOtpScreen(email: _emailCtrl.text.trim()),
      ));
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error!),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Header teal
          Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(36),
                bottomRight: Radius.circular(36),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Icon + title
                const SizedBox(height: 4),
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 34, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text('Tạo tài khoản',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text('Đăng ký tài khoản gia đình',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 24),

                // Form card
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section label
                            Row(children: [
                              Container(
                                width: 4, height: 20,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('Thông tin đăng ký',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary)),
                            ]),
                            const SizedBox(height: 20),

                            // Họ và tên
                            const _FieldLabel(label: 'Họ và tên', required: true),
                            TextFormField(
                              controller: _fullNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'Nguyễn Văn A',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Vui lòng nhập họ và tên' : null,
                            ),
                            const SizedBox(height: 16),

                            // Giới tính
                            const _FieldLabel(label: 'Giới tính', required: true),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.wc_rounded),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male',   child: Text('Nam')),
                                DropdownMenuItem(value: 'Female', child: Text('Nữ')),
                              ],
                              onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                            ),
                            const SizedBox(height: 16),

                            // Email
                            const _FieldLabel(label: 'Email', required: true),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'example@email.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Vui lòng nhập email';
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                                  return 'Email không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Số điện thoại
                            const _FieldLabel(label: 'Số điện thoại', required: true),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: '0901234567',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Vui lòng nhập số điện thoại';
                                if (!RegExp(r'^[0-9]{9,11}$').hasMatch(v.trim())) {
                                  return 'Số điện thoại không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Divider
                            const Divider(height: 8),
                            const SizedBox(height: 8),

                            // Mật khẩu
                            const _FieldLabel(label: 'Mật khẩu', required: true),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Ít nhất 6 ký tự',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                                if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Xác nhận mật khẩu
                            const _FieldLabel(label: 'Xác nhận mật khẩu', required: true),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                hintText: 'Nhập lại mật khẩu',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                  onPressed: () =>
                                      setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                                if (v != _passwordCtrl.text) return 'Mật khẩu không khớp';
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 28),

                            // Nút đăng ký
                            Consumer<AuthProvider>(
                              builder: (_, auth, __) => SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          height: 22, width: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5, color: Colors.white))
                                      : const Text('ĐĂNG KÝ',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Đã có tài khoản
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản?',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Đăng nhập',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: AppTheme.danger, fontSize: 13)),
        ],
      ]),
    );
  }
}
