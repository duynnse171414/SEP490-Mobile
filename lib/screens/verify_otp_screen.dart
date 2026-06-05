import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  const VerifyOtpScreen({super.key, required this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  static const int _otpLength = 6;

  final List<TextEditingController> _ctrls =
        List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _otpValue => _ctrls.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    // Paste: nếu paste cả chuỗi 6 số vào ô đầu
    if (value.length == _otpLength) {
      for (int i = 0; i < _otpLength; i++) {
        _ctrls[i].text = value[i];
      }

      _focusNodes[_otpLength - 1].requestFocus();
      setState(() {});
      return;
    }
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _ctrls[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    final otp = _otpValue;
    if (otp.length < _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập đủ 6 chữ số OTP'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(widget.email, otp);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Xác thực thành công! Vui lòng đăng nhập.'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 2),
      ));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error!),
        backgroundColor: AppTheme.danger,
      ));
      for (final c in _ctrls) { c.clear(); }
      _focusNodes[0].requestFocus();
      setState(() {});
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    _startCountdown();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã gửi lại mã OTP, vui lòng kiểm tra email'),
        backgroundColor: AppTheme.primary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFilled = _otpValue.length == _otpLength;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // Header teal
          Container(
            height: 220,
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
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                ),

                // Icon + title
                const SizedBox(height: 4),
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, size: 34, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text('Xác thực tài khoản',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Mã OTP gửi đến',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(widget.email,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 28),

                // Card
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
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          // Label
                          Row(children: [
                            Container(
                              width: 4, height: 20,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Nhập mã OTP',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary)),
                          ]),
                          const SizedBox(height: 6),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Kiểm tra hộp thư đến và thư mục spam',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ),
                          const SizedBox(height: 28),

                          // 6 OTP boxes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(_otpLength, (i) => _OtpBox(
                              controller: _ctrls[i],
                              focusNode: _focusNodes[i],
                              onChanged: (v) => _onOtpChanged(i, v),
                              onKeyEvent: (e) => _onKeyEvent(i, e),
                            )),
                          ),
                          const SizedBox(height: 32),

                          // Xác nhận button
                          Consumer<AuthProvider>(
                            builder: (_, auth, __) => SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (auth.isLoading || !allFilled) ? null : _verify,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  disabledBackgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        height: 22, width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: Colors.white))
                                    : const Text('XÁC NHẬN OTP',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                            color: Colors.white)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Gửi lại OTP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Không nhận được mã?',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondary)),
                              const SizedBox(width: 4),
                              _resendCountdown > 0
                                  ? Text(
                                      'Gửi lại sau ${_resendCountdown}s',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600),
                                    )
                                  : TextButton(
                                      onPressed: _resend,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Gửi lại OTP',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w700)),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    final hasValue  = controller.text.isNotEmpty;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: 46,
        height: 56,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isFocused
                ? AppTheme.primary.withValues(alpha: 0.06)
                : (hasValue ? AppTheme.surface : const Color(0xFFF8FFFE)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFocused
                  ? AppTheme.primary
                  : (hasValue ? AppTheme.primary.withValues(alpha: 0.4)
                              : const Color(0xFFCCFBF1)),
              width: isFocused ? 2 : 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            maxLength: 1,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isFocused ? AppTheme.primary : AppTheme.textPrimary,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border:      InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
