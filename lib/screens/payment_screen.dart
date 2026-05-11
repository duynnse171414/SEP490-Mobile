// lib/screens/payment_screen.dart

import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';
import '../utils/theme.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ServicePackage {
  final int id;
  final String name;
  final String? description;
  final String? level;
  final double price;
  final bool active;
  final int? durationDays;
  final List<dynamic> robotActions;

  ServicePackage({
    required this.id,
    required this.name,
    this.description,
    this.level,
    required this.price,
    required this.active,
    this.durationDays,
    this.robotActions = const [],
  });

  factory ServicePackage.fromJson(Map<String, dynamic> json) => ServicePackage(
        id: json['id'] ?? 0,
        name: json['name'] ?? '',
        description: json['description'],
        level: json['level'],
        price: (json['price'] ?? 0).toDouble(),
        active: json['active'] ?? false,
        durationDays: json['durationDays'],
        robotActions: json['robotActions'] ?? [],
      );

  String get formattedPrice {
    final p = price.toInt();
    final s = p.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf}đ';
  }
}

// ─── Payment Screen ───────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<ServicePackage> _packages = [];
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
      // Lấy List<dynamic> rồi parse sang ServicePackage
      final raw = await ApiService.getServicePackages();
      final packages = raw
          .map((e) => ServicePackage.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _packages = packages; _isLoading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Không thể tải gói dịch vụ: $e'; _isLoading = false; });
    }
  }

  Future<void> _onBuy(ServicePackage pkg) async {
    final profiles = await ApiService.getElderlyProfiles();
    if (!mounted) return;

    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng thêm người nhà trước!'),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }

    int elderlyId = profiles.first.id;

    if (profiles.length > 1) {
      final selected = await showDialog<int>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Chọn người nhà'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: profiles.map((e) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.elderlyPurple.withOpacity(0.1),
                child: Text(e.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.elderlyPurple,
                        fontWeight: FontWeight.w700)),
              ),
              title: Text(e.name),
              onTap: () => Navigator.pop(context, e.id),
            )).toList(),
          ),
        ),
      );
      if (selected == null) return;
      elderlyId = selected;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payment_rounded, color: AppTheme.success),
          ),
          const SizedBox(width: 12),
          const Text('Xác nhận mua gói'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _InfoRow(label: 'Gói dịch vụ', value: pkg.name),
          _InfoRow(label: 'Giá', value: pkg.formattedPrice,
              color: AppTheme.success),
          if (pkg.durationDays != null)
            _InfoRow(label: 'Thời hạn', value: '${pkg.durationDays} ngày'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.open_in_new_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Trang PayOS sẽ mở trong tab mới để thanh toán qua QR',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.qr_code_rounded),
            label: const Text('Tạo QR'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    _showLoading();
    try {
      final result = await ApiService.createPayment(pkg.id, elderlyId);
      if (!mounted) return;
      Navigator.pop(context); // đóng loading

      final checkoutUrl = result['checkoutUrl'] as String? ?? '';
      final amount = (result['amount'] ?? 0).toDouble();

      if (checkoutUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không nhận được URL thanh toán'),
          backgroundColor: AppTheme.danger,
        ));
        return;
      }

      // Mở PayOS trong tab mới
      html.window.open(checkoutUrl, '_blank');
      _showPaymentGuide(pkg, amount, checkoutUrl);

    } on ApiException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), backgroundColor: AppTheme.danger));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi: $e'), backgroundColor: AppTheme.danger));
      }
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: AppTheme.success),
          SizedBox(width: 16),
          Text('Đang tạo mã QR...'),
        ]),
      ),
    );
  }

  void _showPaymentGuide(ServicePackage pkg, double amount, String url) {
    final s = amount.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    final formattedAmt = '${buf}đ';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                color: AppTheme.success, size: 28),
          ),
          const SizedBox(width: 12),
          const Text('Thanh toán PayOS'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text(pkg.name, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(formattedAmt, style: const TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.w900,
                  fontSize: 24)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('Trang PayOS đã mở trong tab mới.\nLàm theo các bước:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          _guideStep('1', 'Chuyển sang tab PayOS vừa mở'),
          _guideStep('2', 'Quét mã QR bằng app ngân hàng'),
          _guideStep('3', 'Xác nhận thanh toán trong app ngân hàng'),
          _guideStep('4', 'Quay lại app sau khi thanh toán xong'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => html.window.open(url, '_blank'),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.open_in_new_rounded,
                    color: AppTheme.primary, size: 16),
                SizedBox(width: 6),
                Text('Mở lại trang thanh toán',
                    style: TextStyle(color: AppTheme.primary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Đã thanh toán'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(
            color: AppTheme.success, shape: BoxShape.circle),
        child: Center(child: Text(num, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Gói dịch vụ'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline,
                    color: AppTheme.danger, size: 48),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
              ]))
              : _packages.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64,
                        color: AppTheme.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text('Chưa có gói dịch vụ nào',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                  ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _packages.length,
                        itemBuilder: (_, i) => _PackageCard(
                          pkg: _packages[i],
                          onBuy: () => _onBuy(_packages[i]),
                        ),
                      ),
                    ),
    );
  }
}

// ─── Package Card ─────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final ServicePackage pkg;
  final VoidCallback onBuy;
  const _PackageCard({required this.pkg, required this.onBuy});

  Color get _color {
    switch (pkg.level?.toUpperCase()) {
      case 'BASIC':    return AppTheme.primary;
      case 'STANDARD': return AppTheme.warning;
      case 'PREMIUM':  return AppTheme.elderlyPurple;
      default:         return AppTheme.textSecondary;
    }
  }

  bool get _isPremium => pkg.level?.toUpperCase() == 'PREMIUM';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: _isPremium
            ? Border.all(color: AppTheme.elderlyPurple.withOpacity(0.5), width: 2)
            : Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: _isPremium
              ? AppTheme.elderlyPurple.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPremium
                  ? [AppTheme.elderlyPurple, AppTheme.primary]
                  : [_color.withOpacity(0.85), _color],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Icon(_isPremium
                ? Icons.workspace_premium_rounded : Icons.star_rounded,
                color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pkg.name, style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              if (pkg.level != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(pkg.level!, style: const TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w700)),
                ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pkg.formattedPrice, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              if (pkg.durationDays != null)
                Text('${pkg.durationDays} ngày',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12)),
            ]),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (pkg.description != null) ...[
              Text(pkg.description!, style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
            ],
            if (pkg.robotActions.isNotEmpty) ...[
              const Text('Bài tập bao gồm:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: pkg.robotActions.take(4).map((a) {
                  final action = a as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.robotBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.robotBlue.withOpacity(0.2)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 11, color: AppTheme.robotBlue),
                      const SizedBox(width: 4),
                      Text(action['name'] ?? '',
                          style: const TextStyle(fontSize: 11,
                              color: AppTheme.robotBlue,
                              fontWeight: FontWeight.w600)),
                    ]),
                  );
                }).toList(),
              ),
              if (pkg.robotActions.length > 4) ...[
                const SizedBox(height: 4),
                Text('+${pkg.robotActions.length - 4} bài tập khác',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pkg.active ? onBuy : null,
                icon: const Icon(Icons.qr_code_rounded),
                label: Text(pkg.active ? 'Thanh toán qua PayOS' : 'Không khả dụng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPremium
                      ? AppTheme.elderlyPurple : AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(
          color: AppTheme.textSecondary, fontSize: 14)),
      Text(value, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14,
          color: color ?? AppTheme.textPrimary)),
    ]),
  );
}