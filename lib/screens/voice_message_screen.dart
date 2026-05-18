// lib/screens/voice_message_screen.dart
// Tương thích Android + Web - dùng speech_to_text package

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';
import '../utils/theme.dart';

class VoiceMessageScreen extends StatefulWidget {
  const VoiceMessageScreen({super.key});

  @override
  State<VoiceMessageScreen> createState() => _VoiceMessageScreenState();
}

class _VoiceMessageScreenState extends State<VoiceMessageScreen>
    with SingleTickerProviderStateMixin {
  final _textCtrl  = TextEditingController();
  final _speech    = stt.SpeechToText();
  bool _isSending   = false;
  bool _isRecording = false;
  bool _speechAvailable = false;
  String _interimText = '';
  final List<_SentMessage> _history = [];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const List<String> _quickMessages = [
    'Con yêu ông/bà!',
    'Ông/bà có khỏe không?',
    'Nhớ uống thuốc nhé!',
    'Ăn cơm chưa ông/bà?',
    'Con đang bận, tối gọi lại nhé!',
    'Nhớ tập thể dục nhé!',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.stop();
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => print('Speech error: $e'),
    );
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) {
      _showError('Thiết bị không hỗ trợ ghi âm');
      return;
    }

    setState(() { _isRecording = true; _interimText = ''; });
    _pulseCtrl.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _interimText = result.recognizedWords;
          if (result.finalResult) {
            _textCtrl.text = result.recognizedWords;
            _textCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: result.recognizedWords.length));
          }
        });
      },
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: false,
      partialResults: true,
      onSoundLevelChange: null,
    );

    // Khi speech kết thúc
    _speech.statusListener = (status) {
      if (status == 'done' || status == 'notListening') {
        if (mounted) {
          setState(() { _isRecording = false; _interimText = ''; });
          _pulseCtrl.stop();
        }
      }
    };
  }

  void _stopRecording() {
    _speech.stop();
    setState(() { _isRecording = false; _interimText = ''; });
    _pulseCtrl.stop();
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await ApiService.sendRobotAction('TTS:${text.trim()}');
      setState(() {
        _history.insert(0, _SentMessage(text: text.trim(), time: DateTime.now()));
        _textCtrl.clear();
        _interimText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Robot sẽ đọc tin nhắn của bạn!')),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: AppTheme.danger));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.record_voice_over_rounded,
                color: AppTheme.primary, size: 20)),
          const SizedBox(width: 10),
          const Text('Nhắn tin cho Robot'),
        ]),
      ),
      body: Column(children: [
        // Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.elderlyPurple],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Gửi lời nhắn đến Robot',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 2),
              Text('Gõ hoặc nhấn 🎤 nói — robot sẽ đọc to cho người thân',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),

        // Quick messages
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tin nhắn nhanh:', style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6,
              children: _quickMessages.map((msg) => GestureDetector(
                onTap: () => _sendText(msg),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Text(msg, style: const TextStyle(fontSize: 13,
                      color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ]),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),

        // History
        Expanded(
          child: _history.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 56, color: AppTheme.textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  const Text('Chưa có tin nhắn nào',
                      style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Gõ hoặc nhấn mic để ghi âm',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: _history.length,
                  itemBuilder: (_, i) => _MessageBubble(msg: _history[i]),
                ),
        ),

        // Recording indicator
        if (_isRecording)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.mic_rounded, color: AppTheme.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _interimText.isNotEmpty ? _interimText : 'Đang ghi âm... (hãy nói đi!)',
                  style: TextStyle(color: AppTheme.danger, fontSize: 13,
                      fontStyle: _interimText.isEmpty ? FontStyle.italic : FontStyle.normal),
                ),
              ),
              TextButton(
                onPressed: _stopRecording,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                child: const Text('Hủy', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
              ),
            ]),
          ),

        // Input bar
        Container(
          padding: EdgeInsets.fromLTRB(12, 10, 12,
              MediaQuery.of(context).viewInsets.bottom + 10),
          decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 10, offset: const Offset(0, -3))]),
          child: Row(children: [
            // Mic
            GestureDetector(
              onTap: _isRecording ? _stopRecording : _startRecording,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                    scale: _isRecording ? _pulseAnim.value : 1.0, child: child),
                child: Container(width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppTheme.danger : AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? Colors.white : AppTheme.primary, size: 22)),
              ),
            ),
            const SizedBox(width: 8),

            // TextField
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: 3, minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Nhập hoặc nhấn 🎤 để nói...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isSending
                  ? const SizedBox(width: 46, height: 46,
                      child: Center(child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))))
                  : GestureDetector(
                      onTap: () => _sendText(_textCtrl.text),
                      child: Container(width: 46, height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.elderlyPurple],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.4),
                              blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SentMessage {
  final String text;
  final DateTime time;
  _SentMessage({required this.text, required this.time});
}

class _MessageBubble extends StatelessWidget {
  final _SentMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final t = msg.time;
    final timeStr = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        const SizedBox(width: 60),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.elderlyPurple],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(msg.text, style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.4)),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(timeStr, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(width: 4),
            const Icon(Icons.smart_toy_rounded, size: 12, color: AppTheme.primary),
            const SizedBox(width: 2),
            const Text('Đã gửi đến robot', style: TextStyle(fontSize: 11,
                color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ]),
        ])),
      ]),
    );
  }
}
