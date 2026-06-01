// lib/screens/camera_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const String _prefKey  = 'camera_base_url';
  static const String _defaultUrl = 'http://192.168.1.1:8080';

  String   _baseUrl    = _defaultUrl;
  Uint8List? _frameBytes;
  bool     _isConnected = false;
  bool     _hasError    = false;
  DateTime? _connectedAt;
  bool     _showUrl    = false;
  late TextEditingController _urlCtrl;

  int      _frameCount = 0;
  double   _fps        = 0;
  DateTime _lastFpsTime = DateTime.now();

  bool _looping = true;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: _baseUrl);
    _loadSavedUrl();
  }

  @override
  void dispose() {
    _looping = false;
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
      _urlCtrl.text = saved;
    }
    _startLoop();
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, url);
  }

  void _applyUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    _baseUrl = url;
    _saveUrl(url);
    setState(() {
      _showUrl     = false;
      _isConnected = false;
      _hasError    = false;
      _frameBytes  = null;
      _connectedAt = null;
    });
    _startLoop();
  }

  void _startLoop() {
    _looping = true;
    _fetchLoop();
  }

  Future<void> _fetchLoop() async {
    while (mounted && _looping) {
      await _fetchFrame();
    }
  }

  Future<void> _fetchFrame() async {
    try {
      final url = '$_baseUrl/snapshot?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));

      if (!mounted) return;

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _frameBytes  = response.bodyBytes;
        _isConnected = true;
        _hasError    = false;
        _connectedAt ??= DateTime.now();

        _frameCount++;
        final now  = DateTime.now();
        final diff = now.difference(_lastFpsTime).inMilliseconds;
        if (diff >= 1000) {
          _fps         = _frameCount * 1000 / diff;
          _frameCount  = 0;
          _lastFpsTime = now;
        }

        if (mounted) setState(() {});
      } else {
        if (mounted) {
          setState(() { _hasError = true; _isConnected = false; });
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() { _hasError = true; _isConnected = false; });
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (_) {
      if (mounted) {
        setState(() { _hasError = true; _isConnected = false; });
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  String get _elapsed {
    if (_connectedAt == null) return '';
    final d = DateTime.now().difference(_connectedAt!);
    return '${d.inMinutes.toString().padLeft(2, '0')}:'
        '${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Camera Robot',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        actions: [
          // Status badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isConnected
                  ? AppTheme.success.withValues(alpha: 0.2)
                  : _hasError
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : AppTheme.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _isConnected
                      ? AppTheme.success
                      : _hasError
                          ? AppTheme.danger
                          : AppTheme.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _isConnected
                    ? 'Live${_fps > 0 ? " ${_fps.toStringAsFixed(0)}fps" : ""}'
                    : _hasError
                        ? 'Lỗi'
                        : 'Kết nối...',
                style: TextStyle(
                  color: _isConnected
                      ? AppTheme.success
                      : _hasError
                          ? AppTheme.danger
                          : AppTheme.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
          // Settings — đổi URL
          IconButton(
            icon: Icon(Icons.settings_rounded,
                color: Colors.white.withValues(alpha: 0.5)),
            onPressed: () => setState(() => _showUrl = !_showUrl),
          ),
        ],
      ),
      body: Column(children: [
        // ── URL editor ──────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _showUrl ? 72 : 0,
          color: const Color(0xFF0D0D20),
          child: _showUrl
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IP laptop đang chạy main.py',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'http://IP_LAPTOP:8080',
                              hintStyle: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.3),
                                  fontSize: 12),
                              fillColor:
                                  Colors.white.withValues(alpha: 0.08),
                              filled: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _applyUrl(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _applyUrl,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Lưu',
                              style: TextStyle(fontSize: 13)),
                        ),
                      ]),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // ── Video frame ─────────────────────────────────────────────
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            if (_frameBytes != null)
              Image.memory(
                _frameBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              )
            else if (!_hasError)
              const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary),
              ),

            if (_hasError && _frameBytes == null) _buildError(),

            // LIVE badge
            if (_isConnected)
              Positioned(
                top: 12,
                left: 12,
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record,
                              color: Colors.white, size: 8),
                          SizedBox(width: 4),
                          Text('LIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                        ]),
                  ),
                  const SizedBox(width: 6),
                  if (_connectedAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_elapsed,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'monospace')),
                    ),
                ]),
              ),
          ]),
        ),

        // ── Bottom bar ──────────────────────────────────────────────
        Container(
          color: const Color(0xFF0D0D1A),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.computer_rounded,
                color: AppTheme.textSecondary, size: 13),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _baseUrl,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () {
                _looping = false;
                setState(() {
                  _isConnected = false;
                  _hasError    = false;
                  _frameBytes  = null;
                  _connectedAt = null;
                });
                _startLoop();
              },
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero),
              child: const Text('Thử lại',
                  style: TextStyle(
                      color: AppTheme.primary, fontSize: 11)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_rounded,
              color: AppTheme.danger, size: 52),
          const SizedBox(height: 14),
          const Text('Không kết nối được camera',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Kiểm tra:\n'
            '• main.py đang chạy trên laptop\n'
            '• Điện thoại và laptop cùng WiFi\n'
            '• Nhấn ⚙️ để đổi IP laptop',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                height: 1.7),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showUrl = true),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Đổi IP laptop'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _looping = false;
              setState(() {
                _hasError    = false;
                _frameBytes  = null;
                _connectedAt = null;
              });
              _startLoop();
            },
            child: const Text('Thử lại',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ]),
      ),
    );
  }
}
