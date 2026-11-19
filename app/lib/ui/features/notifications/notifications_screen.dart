import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/shop_repository.dart';
import '../../../domain/models/customer.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../account/views/order_tracking_screen.dart' show formatDateTime;
import '../auth/view_models/auth_view_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<ShopRepository>();
    final auth = context.read<AuthViewModel>();
    try {
      final items = await repo.notifications();
      if (!mounted) return;
      setState(() => _items = items);
      if (items.any((n) => !n.read)) {
        await repo.markNotificationsRead();
        auth.clearUnread();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Мессежүүд')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [EmptyState(icon: Icons.wifi_off, message: _error!)])
                : items!.isEmpty
                    ? ListView(children: const [
                        EmptyState(
                            icon: Icons.notifications_none,
                            message: 'Захиалгын мэдээлэл энд ирнэ.'),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(indent: 72, height: 1),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return ListTile(
                            tileColor: n.read ? null : AppColors.sky,
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.blue,
                              child: Icon(Icons.local_shipping_outlined,
                                  color: Colors.white, size: 20),
                            ),
                            title: Text(n.title,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${n.body}\n${formatDateTime(n.createdAt)}'),
                            isThreeLine: true,
                          );
                        },
                      ),
      ),
    );
  }
}
