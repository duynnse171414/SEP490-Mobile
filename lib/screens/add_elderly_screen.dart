// lib/screens/add_elderly_screen.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class AddElderlyScreen extends StatefulWidget {
  const AddElderlyScreen({super.key});

  @override
  State<AddElderlyScreen> createState() => _AddElderlyScreenState();
}

class _AddElderlyScreenState extends State<AddElderlyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _healthNotesCtrl = TextEditingController();
  final _preferredLangCtrl = TextEditingController();
  String? _speakingSpeed;
  int? _roomId;
  final _roomIdCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _healthNotesCtrl.dispose();
    _preferredLangCtrl.dispose();
    _roomIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(1950),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      _dobCtrl.text =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final request = ElderlyProfileRequest(
        name: _nameCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim(),
        healthNotes: _healthNotesCtrl.text.trim().isEmpty
            ? null
            : _healthNotesCtrl.text.trim(),
        preferredLanguage: _preferredLangCtrl.text.trim().isEmpty
            ? null
            : _preferredLangCtrl.text.trim(),
        speakingSpeed: _speakingSpeed,
        roomId: _roomIdCtrl.text.isEmpty
            ? null
            : int.tryParse(_roomIdCtrl.text),
      );

      await ApiService.createElderlyProfile(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thêm người nhà thành công!'),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm người nhà')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionTitle('Thông tin cơ bản'),
            const SizedBox(height: 12),

            // name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Họ và tên *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 12),

            // dateOfBirth
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Ngày sinh *',
                prefixIcon: Icon(Icons.cake_outlined),
                hintText: 'YYYY-MM-DD',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Vui lòng chọn ngày sinh' : null,
            ),
            const SizedBox(height: 24),

            _sectionTitle('Sức khỏe & Chăm sóc'),
            const SizedBox(height: 12),

            // healthNotes
            TextFormField(
              controller: _healthNotesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú sức khỏe',
                prefixIcon: Icon(Icons.medical_information_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // preferredLanguage
            TextFormField(
              controller: _preferredLangCtrl,
              decoration: const InputDecoration(
                labelText: 'Ngôn ngữ ưa thích',
                prefixIcon: Icon(Icons.language_outlined),
                hintText: 'Ví dụ: Tiếng Việt, Vietnamese',
              ),
            ),
            const SizedBox(height: 12),

            // speakingSpeed
            DropdownButtonFormField<String>(
              value: _speakingSpeed,
              decoration: const InputDecoration(
                labelText: 'Tốc độ nói của robot',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'SLOW', child: Text('Chậm')),
                DropdownMenuItem(value: 'NORMAL', child: Text('Bình thường')),
                DropdownMenuItem(value: 'FAST', child: Text('Nhanh')),
              ],
              onChanged: (v) => setState(() => _speakingSpeed = v),
            ),
            const SizedBox(height: 24),

            _sectionTitle('Phòng'),
            const SizedBox(height: 12),

            // roomId
            TextFormField(
              controller: _roomIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Room ID',
                prefixIcon: Icon(Icons.meeting_room_outlined),
                hintText: 'Nhập ID phòng nếu có',
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('LƯU THÔNG TIN'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary)),
      ],
    );
  }
}
