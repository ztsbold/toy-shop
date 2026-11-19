import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/customer.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../config/shop_config_view_model.dart';
import 'order_tracking_screen.dart' show formatDateTime;

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  List<PointsEntry>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<ShopRepository>().pointsHistory();
      if (!mounted) return;
      context.read<AuthViewModel>().refresh();
      setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = context.watch<AuthViewModel>().points;
    final loyalty = context.watch<ShopConfigViewModel>().config.loyalty;

    return Scaffold(
      appBar: AppBar(title: const Text('Миний оноо')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Үлдэгдэл',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${formatNumber(points)} оноо',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
                Text('= ${formatMnt(points * loyalty.pointValue)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sky,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Худалдан авалтын ${formatMnt(loyalty.pointsPerAmount)} тутамд 1 оноо. '
                '1 оноо = ${formatMnt(loyalty.pointValue)}. '
                'Оноогоо "Оноогоор авч болно" тэмдэгтэй бараан дээр захиалга өгөхдөө ашиглана.',
                style: const TextStyle(height: 1.4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 6),
              child: Text('Түүх',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            if (_items == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              EmptyState(icon: Icons.wifi_off, message: _error!)
            else if (_items!.isEmpty)
              const EmptyState(
                  icon: Icons.stars_outlined, message: 'Одоогоор онооны гүйлгээ алга.')
            else
              for (final e in _items!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: e.delta > 0 ? AppColors.sky : const Color(0xFFFDF2E9),
                    child: Icon(e.delta > 0 ? Icons.add : Icons.remove,
                        color: e.delta > 0 ? AppColors.blue : AppColors.warning),
                  ),
                  title: Text(e.reason),
                  subtitle: Text(formatDateTime(e.createdAt)),
                  trailing: Text('${e.delta > 0 ? '+' : ''}${formatNumber(e.delta)}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: e.delta > 0 ? AppColors.blue : AppColors.warning)),
                ),
          ],
        ),
      ),
    );
  }
}
