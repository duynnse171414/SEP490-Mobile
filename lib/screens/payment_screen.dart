// lib/screens/payment_screen.dart
// Tương thích cả Web lẫn Android - dùng url_launcher thay dart:html

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../models/models.dart';


class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

// Gói đang dùng của 1 elderly
class _ElderlyPackageInfo {
  final ElderlyProfile profile;
  final Map<String, dynamic>? activePackage; // null = chưa có gói
  final ServicePackage? packageDetail;       // thông tin chi tiết gói
  _ElderlyPackageInfo(this.profile, this.activePackage, [this.packageDetail]);
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ServicePackage> _packages = [];
  List<_ElderlyPackageInfo> _elderlyPackages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await ApiService.getServicePackages();
      final packages = raw
          .map((e) => ServicePackage.fromJson(e as Map<String, dynamic>))
          .toList();

      // Load gói hiện tại của từng elderly
      final profiles = await ApiService.getElderlyProfiles();
      final elderlyPkgs = <_ElderlyPackageInfo>[];
      for (final p in profiles) {
        try {
          final pkgs = await ApiService.getUserPackagesByElderly(p.id);
          final active = pkgs.cast<Map<String, dynamic>>().where((pkg) {
            final s = (pkg['status'] as String? ?? '').toUpperCase();
            final exp = pkg['expiredAt'] as String?;
            if (s != 'PAID') return false;
            if (exp == null) return true;
            return DateTime.tryParse(exp)?.isAfter(DateTime.now()) ?? false;
          }).toList();
          final activePkg = active.isNotEmpty ? active.first : null;
          ServicePackage? detail;
          if (activePkg != null) {
            final svcId = activePkg['servicePackageId'];
            detail = packages.where((p) => p.id == svcId).firstOrNull;
          }
          elderlyPkgs.add(_ElderlyPackageInfo(p, activePkg, detail));
        } catch (_) {
          elderlyPkgs.add(_ElderlyPackageInfo(p, null));
        }
      }

      setState(() {
        _packages = packages;
        _elderlyPackages = elderlyPkgs;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Không thể tải gói dịch vụ'; _isLoading = false; });
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
          content: Column(mainAxisSize: MainAxisSize.min,
            children: profiles.map((e) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.elderlyPurple.withOpacity(0.1),
                child: Text(e.name[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.elderlyPurple,
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

    // Kiểm tra gói hiện tại trước khi cho mua
    if (!mounted) return;
    try {
      final pkgs = await ApiService.getUserPackagesByElderly(elderlyId);
      if (!mounted) return;
      final active = pkgs.where((p) {
        final s = (p['status'] as String? ?? '').toUpperCase();
        return s == 'PAID' || s == 'PENDING';
      }).toList();
      if (active.isNotEmpty) {
        final expiredAt = active.first['expiredAt'] as String?;
        final statusStr = (active.first['status'] as String? ?? '').toUpperCase();
        final msg = statusStr == 'PENDING'
            ? 'Bạn đang có một giao dịch chờ thanh toán.\nVui lòng hoàn tất hoặc chờ hết hạn trước khi mua gói mới.'
            : 'Bạn đã có gói dịch vụ đang hoạt động.${expiredAt != null ? '\nHết hạn: ${expiredAt.substring(0, 10)}' : ''}';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.warning),
              SizedBox(width: 8),
              Text('Đã có gói dịch vụ'),
            ]),
            content: Text(msg),
            actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            )],
          ),
        );
        return;
      }
    } catch (_) {}

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.payment_rounded, color: AppTheme.success)),
          const SizedBox(width: 12),
          const Text('Xác nhận mua gói'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _InfoRow(label: 'Gói', value: pkg.name),
          _InfoRow(label: 'Giá', value: pkg.formattedPrice, color: AppTheme.success),
          if (pkg.durationDays != null)
            _InfoRow(label: 'Thời hạn', value: '${pkg.durationDays} ngày'),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.open_in_new_rounded, color: AppTheme.primary, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Trang PayOS sẽ mở để thanh toán qua QR',
                  style: TextStyle(fontSize: 13, color: AppTheme.primary))),
            ])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
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
      Navigator.pop(context);

      final checkoutUrl = result['checkoutUrl'] as String? ?? '';
      final amount = (result['amount'] ?? 0).toDouble();

      if (checkoutUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Không nhận được URL thanh toán'),
          backgroundColor: AppTheme.danger,
        ));
        return;
      }

      // Dùng url_launcher thay dart:html — hoạt động cả Web lẫn Android
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      _showPaymentGuide(pkg, amount, checkoutUrl);

    } on ApiException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.error_outline_rounded, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('Không thể tạo thanh toán'),
            ]),
            content: Text(e.message, style: const TextStyle(fontSize: 14)),
            actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            )],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.error_outline_rounded, color: AppTheme.danger),
              SizedBox(width: 8),
              Text('Lỗi'),
            ]),
            content: Text('$e', style: const TextStyle(fontSize: 14)),
            actions: [TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            )],
          ),
        );
      }
    }
  }

  void _showLoading() {
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: AppTheme.success),
          SizedBox(width: 16), Text('Đang tạo mã QR...'),
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thanh toán PayOS'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(pkg.name, style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text('${buf}đ', style: const TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.w900, fontSize: 22)),
            ])),
          const SizedBox(height: 14),
          _step('1', 'Quét mã QR bằng app ngân hàng'),
          _step('2', 'Xác nhận thanh toán trong app ngân hàng'),
          _step('3', 'Quay lại app sau khi thanh toán xong'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
              child: const Row(children: [
                Icon(Icons.open_in_new_rounded, color: AppTheme.primary, size: 16),
                SizedBox(width: 6),
                Text('Mở lại trang thanh toán',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ])),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
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

  Widget _step(String n, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 20, height: 20,
        decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
        child: Center(child: Text(n, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)))),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
    ]),
  );

  int get _activeCount => _elderlyPackages.where((e) => e.activePackage != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Gói dịch vụ',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Gói của tôi (${_elderlyPackages.length})'),
            const Tab(text: 'Mua gói'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabCtrl,
                  children: [_buildMyPackagesTab(), _buildBuyTab()],
                ),
    );
  }

  Widget _buildError() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 52),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Thử lại'),
      ),
    ],
  ));

  Widget _buildMyPackagesTab() {
    if (_elderlyPackages.isEmpty) {
      return const Center(child: Text('Chưa có người nhà nào',
          style: TextStyle(color: AppTheme.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Summary banner
          _buildSummaryBanner(),
          const SizedBox(height: 16),
          ..._elderlyPackages.map((info) => _ElderlyPackageCard(info: info)),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner() {
    final total = _elderlyPackages.length;
    final active = _activeCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$active / $total người có gói',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(active == total ? 'Tất cả đã được bảo vệ'
              : '${total - active} người chưa có gói',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$active', style: const TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
          Text('đang hoạt động', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildBuyTab() {
    if (_packages.isEmpty) {
      return const Center(child: Text('Chưa có gói dịch vụ nào',
          style: TextStyle(color: AppTheme.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _packages.length,
        itemBuilder: (_, i) => _PackageCard(
            pkg: _packages[i], onBuy: () => _onBuy(_packages[i])),
      ),
    );
  }
}

// ── Elderly Package Card ──────────────────────────────────────────────────────

class _ElderlyPackageCard extends StatelessWidget {
  final _ElderlyPackageInfo info;
  const _ElderlyPackageCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final pkg = info.activePackage;
    final detail = info.packageDetail;
    final hasPkg = pkg != null;
    final expiredAt = hasPkg ? (pkg['expiredAt'] as String?) : null;
    final expiry = expiredAt != null ? DateTime.tryParse(expiredAt) : null;
    final daysLeft = expiry?.toLocal().difference(DateTime.now()).inDays;

    final isExpiring = daysLeft != null && daysLeft <= 7 && daysLeft >= 0;
    final isExpired = daysLeft != null && daysLeft < 0;
    final Color statusColor = !hasPkg
        ? Colors.grey.shade400
        : isExpired
            ? AppTheme.danger
            : isExpiring
                ? AppTheme.warning
                : AppTheme.success;

    final String statusLabel = !hasPkg
        ? 'Chưa có gói'
        : isExpired
            ? 'Đã hết hạn'
            : isExpiring
                ? 'Còn $daysLeft ngày'
                : 'Đang hoạt động';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10, offset: const Offset(0, 3),
        )],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hasPkg
                ? statusColor.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(
              color: hasPkg
                  ? statusColor.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.1),
            )),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.elderlyPurple.withValues(alpha: 0.12),
              child: Text(
                info.profile.name.isNotEmpty
                    ? info.profile.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.elderlyPurple,
                    fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.profile.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (info.profile.dateOfBirth != null) ...[
                Builder(builder: (_) {
                  final dob = DateTime.tryParse(info.profile.dateOfBirth!);
                  if (dob == null) return const SizedBox.shrink();
                  final age = DateTime.now().year - dob.year;
                  return Text('$age tuổi',
                      style: const TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary));
                }),
              ],
            ])),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(statusLabel, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: statusColor)),
              ]),
            ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: hasPkg
              ? Row(children: [
                  // Package icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(detail?.name ?? 'Gói dịch vụ',
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 14, color: AppTheme.textPrimary)),
                    if (detail?.level != null) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(detail!.level!,
                            style: const TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.success)),
                      ),
                    ],
                  ])),
                  if (expiry != null)
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('Hết hạn',
                          style: TextStyle(fontSize: 10,
                              color: AppTheme.textSecondary)),
                      Text(DateFormat('dd/MM/yyyy').format(expiry.toLocal()),
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isExpiring || isExpired
                                  ? statusColor : AppTheme.textPrimary)),
                    ]),
                ])
              : Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_card_rounded,
                        color: Colors.grey.shade400, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Chưa đăng ký gói dịch vụ',
                      style: TextStyle(color: AppTheme.textSecondary,
                          fontSize: 13))),
                ]),
        ),
      ]),
    );
  }
}

// ── Package Card ──────────────────────────────────────────────────────────────

class _PackageCard extends StatelessWidget {
  final ServicePackage pkg;
  final VoidCallback onBuy;
  const _PackageCard({required this.pkg, required this.onBuy});

  Color get _color {
    switch (pkg.level?.toUpperCase()) {
      case 'BASIC': return AppTheme.primary;
      case 'STANDARD': return AppTheme.warning;
      case 'PREMIUM': return AppTheme.elderlyPurple;
      default: return AppTheme.textSecondary;
    }
  }
  bool get _isPremium => pkg.level?.toUpperCase() == 'PREMIUM';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: _isPremium
            ? Border.all(color: AppTheme.elderlyPurple.withOpacity(0.5), width: 2)
            : Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [BoxShadow(
          color: _isPremium ? AppTheme.elderlyPurple.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPremium ? [AppTheme.elderlyPurple, AppTheme.primary] : [_color.withOpacity(0.85), _color],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Icon(_isPremium ? Icons.workspace_premium_rounded : Icons.star_rounded,
                color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pkg.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              if (pkg.level != null)
                Container(margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(pkg.level!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pkg.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              if (pkg.durationDays != null)
                Text('${pkg.durationDays} ngày', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (pkg.description != null) ...[
              Text(pkg.description!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 12),
            ],
            if (pkg.robotActions.isNotEmpty) ...[
              const Text('Bài tập:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: pkg.robotActions.take(4).map((a) {
                  final action = a as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.robotBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.robotBlue.withOpacity(0.2))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fitness_center_rounded, size: 11, color: AppTheme.robotBlue),
                      const SizedBox(width: 4),
                      Text(action['name'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.robotBlue, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }).toList()),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pkg.active ? onBuy : null,
                icon: const Icon(Icons.qr_code_rounded),
                label: Text(pkg.active ? 'Thanh toán qua PayOS' : 'Không khả dụng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPremium ? AppTheme.elderlyPurple : AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color ?? AppTheme.textPrimary)),
    ]),
  );
}
