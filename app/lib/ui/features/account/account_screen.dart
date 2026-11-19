import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/shop_repository.dart';
import '../../../domain/models/order_summary.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/view_models/auth_view_model.dart';
import '../auth/views/login_screen.dart';
import '../notifications/notifications_screen.dart';
import '../shell/home_shell.dart';
import 'views/order_tracking_screen.dart';
import 'views/points_screen.dart';

/// "Бүртгэл": нэвтрэх, оноо, мессеж, захиалга хянах
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => AccountScreenState();
}

class AccountScreenState extends State<AccountScreen> {
  List<OrderSummary> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final repo = context.read<ShopRepository>();
    final auth = context.read<AuthViewModel>();
    if (mounted) setState(() => _loading = true);
    List<OrderSummary> orders;
    try {
      if (repo.isLoggedIn) {
        await auth.refresh();
        orders = await repo.serverOrders();
      } else {
        orders = await repo.myOrders();
      }
    } catch (_) {
      orders = _orders;
    }
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _login() async {
    if (await showLogin(context)) refresh();
  }

  Future<void> _editName(String current) async {
    final c = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нэр солих'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Болих')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Хадгалах')),
        ],
      ),
    );
    c.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AuthViewModel>().updateName(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Гарах уу?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Үгүй')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Гарах')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthViewModel>().logout();
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final c = auth.customer;

    return Scaffold(
      appBar: AppBar(title: const Text('Бүртгэл')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (c == null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.sky,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.stars_rounded, color: AppColors.blue, size: 30),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Оноо цуглуулж эхлээрэй',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Утасны дугаараараа нэвтэрвэл худалдан авалт бүрээс оноо цуглуулж, '
                    'захиалгаа хянаж, мэдээллээ SMS-ээр авна.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _login, child: const Text('Нэвтрэх / Бүртгүүлэх')),
                  ),
                ]),
              )
            else ...[
              // Профайл ба оноо
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: AppColors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name.isEmpty ? 'Нэргүй' : c.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(c.phone, style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Нэр солих',
                      onPressed: () => _editName(c.name),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PointsScreen())),
                    child: Row(children: [
                      const Icon(Icons.stars_rounded, color: AppColors.sun, size: 30),
                      const SizedBox(width: 8),
                      Text('${formatNumber(c.points)} оноо',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      const Text('Түүх', style: TextStyle(color: Colors.white)),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.sky,
                  child: Icon(Icons.notifications_outlined, color: AppColors.blue),
                ),
                title: const Text('Мессежүүд', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (auth.unread > 0)
                    Badge(backgroundColor: AppColors.blue, label: Text('${auth.unread}')),
                  const Icon(Icons.chevron_right),
                ]),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 14, 0, 8),
              child: Text('Миний захиалгууд',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            ),
            if (_loading && _orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_orders.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_outlined,
                message: 'Одоогоор захиалга алга байна.',
                actionLabel: 'Тоглоом үзэх',
                onAction: () => HomeShell.of(context)?.selectTab(0),
              )
            else
              for (final o in _orders) _OrderTile(order: o),
            if (c != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('Гарах', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(o.orderId,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(formatMnt(o.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.blue)),
              ]),
              const SizedBox(height: 4),
              Text(
                o.itemCount > 1
                    ? '${o.firstItem} болон бусад (${o.itemCount} ш)'
                    : o.firstItem,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor(o)),
                  ),
                  child: Text(o.statusLabel,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor(o))),
                ),
                if (o.pointsEarned > 0) ...[
                  const SizedBox(width: 8),
                  Text('+${o.pointsEarned} оноо',
                      style: const TextStyle(
                          color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ],
                const Spacer(),
                const Text('Хянах', style: TextStyle(color: AppColors.blue)),
                const Icon(Icons.chevron_right, color: AppColors.blue, size: 20),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
