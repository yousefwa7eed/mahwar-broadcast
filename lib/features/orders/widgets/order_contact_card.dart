import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

class OrderContactCard extends StatefulWidget {
  final String orderId;
  final String status;

  const OrderContactCard({
    super.key,
    required this.orderId,
    required this.status,
  });

  @override
  State<OrderContactCard> createState() => _OrderContactCardState();
}

class _OrderContactCardState extends State<OrderContactCard> {
  String? _contactPhone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchContactIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OrderContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.orderId != widget.orderId) {
      _fetchContactIfNeeded();
    }
  }

  bool _shouldFetch(String status) => status == 'confirmed';

  Future<void> _fetchContactIfNeeded() async {
    if (!_shouldFetch(widget.status)) {
      if (mounted && _contactPhone != null) {
        setState(() => _contactPhone = null);
      }
      return;
    }
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _contactPhone = null;
    });
    try {
      final client = Supabase.instance.client;
      final response = await client.rpc('get_order_contact', params: {'p_order_id': widget.orderId});
      if (mounted) {
        setState(() {
          final s = response?.toString().trim() ?? '';
          _contactPhone = s.isEmpty ? null : s;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contactPhone = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callOwner() async {
    final phone = _contactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldFetch(widget.status)) return const SizedBox.shrink();
    if (_contactPhone == null || _contactPhone!.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.phoneNumber ?? 'رقم الهاتف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone, size: 16, color: subColor),
              const SizedBox(width: 6),
              Expanded(child: Text(_contactPhone!, style: TextStyle(fontSize: 13, color: subColor), overflow: TextOverflow.ellipsis)),
              TextButton.icon(
                onPressed: _callOwner,
                icon: const Icon(Icons.call, size: 16),
                label: Text(l10n?.call ?? 'اتصال'),
                style: TextButton.styleFrom(foregroundColor: AppColors.orangePrimary, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



