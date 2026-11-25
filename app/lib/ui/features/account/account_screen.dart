import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/shop_repository.dart';
import '../../../domain/models/order_summary.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/view_models/auth_view_model.dart';
import '../auth/views/login_screen.dart';
import '../auth/views/profile_form.dart';
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

  Future<void> _editProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
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

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Бүртгэл устгах уу?'),
        content: const Text(
            'Таны оноо, мессежүүд бүрмөсөн устна. Энэ үйлдлийг буцаах боломжгүй.\n\n'
            'Өмнө нь өгсөн захиалгууд дэлгүүрийн бүртгэлд хадгалагдана.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Болих')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthViewModel>().deleteAccount();
      messenger.showSnackBar(const SnackBar(content: Text('Бүртгэл устгагдлаа')));
      refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
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
                    'И-мэйл хаягаараа нэвтэрвэл худалдан авалт бүрээс оноо цуглуулж, '
                    'захиалгаа хянаж, мэдээллээ и-мэйлээр авна.',
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
                        if (c.email.isNotEmpty)
                          Text(c.email, style: const TextStyle(color: Colors.white70)),
                        Text(c.phone.isEmpty ? 'Утас оруулаагүй' : c.phone,
                            style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Мэдээлэл засах',
                      onPressed: _editProfile,
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
              if (!c.profileComplete)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Material(
                    color: const Color(0xFFFFF6D6),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Color(0xFF8A5A00)),
                      title: const Text('Нэр, утасны дугаараа оруулна уу',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Захиалга өгөхөд шаардлагатай'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editProfile,
                    ),
                  ),
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
              for (final o in _orders) _OrderTile(order: o, onChanged: refresh),
            if (c != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: AppColors.danger),
                label: const Text('Гарах', style: TextStyle(color: AppColors.danger)),
              ),
              TextButton(
                onPressed: _deleteAccount,
                child: const Text('Бүртгэл устгах',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onChanged});
  final OrderSummary order;
  final VoidCallback onChanged;

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
          onTap: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: o)));
            onChanged();
          },
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
                if (o.canCancel)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () async {
                      if (await confirmCancelOrder(context, o.orderId)) onChanged();
                    },
                    child: const Text('Цуцлах'),
                  ),
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
