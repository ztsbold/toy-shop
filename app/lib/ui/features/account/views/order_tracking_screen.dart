import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/order_summary.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';

String formatDateTime(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Color statusColor(OrderSummary o) {
  if (o.isCancelled) return AppColors.danger;
  if (!o.isPaid) return AppColors.warning;
  if (o.fulfillment == 'DELIVERED') return AppColors.success;
  return AppColors.blue;
}

/// Төлбөр хүлээж буй захиалгыг цуцлах (баталгаажуулалттай). Амжилттай бол true.
Future<bool> confirmCancelOrder(BuildContext context, String orderId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Захиалга цуцлах уу?'),
      content: Text('$orderId захиалга цуцлагдана. Ашигласан оноо тань буцаж орно.\n\n'
          'Хэрэв та төлбөрөө аль хэдийн төлсөн бол цуцлахгүй, дэлгүүртэй холбогдоно уу.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Үгүй')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Цуцлах'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await context.read<ShopRepository>().cancelMyOrder(orderId);
    messenger.showSnackBar(const SnackBar(content: Text('Захиалга цуцлагдлаа')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return false;
  }
}

/// Захиалгын явцыг алхам алхмаар харуулна
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.order});
  final OrderSummary order;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late OrderSummary _o = widget.order;

  Future<void> _reload() async {
    try {
      final fresh =
          await context.read<ShopRepository>().orderSummary(_o.orderId);
      if (!mounted) return;
      // Нийтийн төлөвийн хариунд бараа ирдэггүй тул өмнөхийг хадгална
      setState(() => _o = OrderSummary(
            orderId: fresh.orderId,
            status: fresh.status,
            fulfillment: fresh.fulfillment,
            total: fresh.total,
            createdAt: fresh.createdAt,
            itemCount: fresh.itemCount,
            firstItem: fresh.firstItem,
            deliveryOption: fresh.deliveryOption,
            subtotal: fresh.subtotal,
            deliveryFee: fresh.deliveryFee,
            pointsUsed: fresh.pointsUsed,
            pointsEarned: fresh.pointsEarned,
            items: _o.items,
            history: fresh.history,
          ));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    const steps = [
      ('CREATED', 'Захиалга хүлээн авсан', Icons.receipt_long_outlined),
      ('PAID', 'Төлбөр баталгаажсан', Icons.payments_outlined),
      ('PREPARING', 'Бэлтгэж байна', Icons.inventory_2_outlined),
      ('SHIPPING', 'Хүргэлтэнд гарсан', Icons.local_shipping_outlined),
      ('DELIVERED', 'Хүргэгдсэн', Icons.home_outlined),
    ];
    // Хамгийн сүүлд хүрсэн алхам
    var reached = 0;
    for (var i = 0; i < steps.length; i++) {
      if (o.timeOf(steps[i].$1) != null || (i == 0)) reached = i;
    }
    if (o.isPaid && reached < 1) reached = 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Захиалга хянах')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(
                child: Text(o.orderId,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor(o)),
                ),
                child: Text(o.statusLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: statusColor(o))),
              ),
            ]),
            const SizedBox(height: 4),
            Text(formatDateTime(o.createdAt),
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            if (o.isCancelled)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${o.cancelledByCustomer ? 'Та захиалгаа цуцалсан' : 'Захиалга цуцлагдсан'}'
                  '${o.timeOf('CANCELLED') != null ? ' (${formatDateTime(o.timeOf('CANCELLED')!)})' : ''}. '
                  '${o.pointsUsed > 0 ? 'Ашигласан оноо тань буцаж орсон. ' : ''}'
                  'Төлбөр төлсөн бол дэлгүүртэй холбогдоно уу.',
                  style: const TextStyle(color: AppColors.danger),
                ),
              )
            else
              for (var i = 0; i < steps.length; i++)
                _Step(
                  icon: steps[i].$3,
                  title: steps[i].$2,
                  time: o.timeOf(steps[i].$1) ?? (i == 0 ? o.createdAt : null),
                  done: i <= reached,
                  current: i == reached,
                  last: i == steps.length - 1,
                ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            if (o.items.isNotEmpty) ...[
              for (final it in o.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text('${it.name} × ${it.qty}')),
                    Text(formatMnt(it.price * it.qty)),
                  ]),
                ),
              const SizedBox(height: 6),
            ],
            if (o.deliveryOption.isNotEmpty)
              _line('Хүргэлт (${o.deliveryOption})',
                  o.deliveryFee == 0 ? 'Үнэгүй' : formatMnt(o.deliveryFee)),
            if (o.pointsUsed > 0)
              _line('Оноогоор хасагдсан', '−${o.pointsUsed} оноо'),
            _line('Нийт төлсөн', formatMnt(o.total), bold: true),
            if (o.canCancel) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: () async {
                  if (await confirmCancelOrder(context, o.orderId)) _reload();
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Захиалга цуцлах'),
              ),
            ],
            if (o.pointsEarned > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const Icon(Icons.stars_rounded, color: AppColors.blue),
                  const SizedBox(width: 6),
                  Text('Энэ захиалгаас ${o.pointsEarned} оноо авсан',
                      style: const TextStyle(
                          color: AppColors.blue, fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(a,
                  style: TextStyle(fontWeight: bold ? FontWeight.w800 : null))),
          Text(b,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : null,
                  color: bold ? AppColors.blue : null,
                  fontSize: bold ? 18 : null)),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.time,
    required this.done,
    required this.current,
    required this.last,
  });

  final IconData icon;
  final String title;
  final DateTime? time;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.blue : AppColors.line;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 40,
          child: Column(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current ? AppColors.blue : (done ? AppColors.sky : Colors.white),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon,
                  size: 18,
                  color: current
                      ? Colors.white
                      : (done ? AppColors.blue : AppColors.muted)),
            ),
            if (!last)
              Expanded(
                child: Container(width: 2, color: color),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      color: done ? AppColors.ink : AppColors.muted)),
              if (time != null && done)
                Text(formatDateTime(time!),
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}
