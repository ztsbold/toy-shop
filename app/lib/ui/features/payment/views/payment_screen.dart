import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/order_result.dart';
import '../../../core/format.dart';
import '../../cart/view_models/cart_view_model.dart';
import '../view_models/payment_view_model.dart';
import 'order_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.order});
  final OrderResult order;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  late final PaymentViewModel vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vm = PaymentViewModel(
        repository: context.read<ShopRepository>(), order: widget.order)
      ..addListener(_onChange)
      ..startPolling();
  }

  // Банкны апп-аас буцаж ирэхэд шууд шалгана.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) vm.check(silent: true);
  }

  void _onChange() {
    if (vm.paid && mounted) {
      context.read<CartViewModel>().clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(order: widget.order)),
        (route) => route.isFirst,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vm.removeListener(_onChange);
    vm.dispose();
    super.dispose();
  }

  Future<void> _openBank(BankLink bank) async {
    final ok = await launchUrl(Uri.parse(bank.link),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${bank.description} апп суулгаагүй байна')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final inv = order.invoice;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Төлбөр төлөх')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Захиалга: ${order.orderId}',
                  textAlign: TextAlign.center, style: text.bodyMedium),
              const SizedBox(height: 4),
              Text(formatMnt(order.total),
                  textAlign: TextAlign.center,
                  style: text.displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (inv.manual != null)
                _ManualTransferCard(info: inv.manual!, amount: order.total)
              else
                Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text('QPay QR кодоор төлөх', style: text.titleMedium),
                    const SizedBox(height: 12),
                    if (inv.qrImage.isNotEmpty)
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: Image.memory(base64Decode(inv.qrImage),
                            width: 240, height: 240),
                      )
                    else
                      SelectableText(inv.qrText),
                    const SizedBox(height: 8),
                    Text(
                      'Өөр утсан дээрх банкны аппаараа уншуулж төлнө үү',
                      textAlign: TextAlign.center,
                      style: text.bodySmall,
                    ),
                  ]),
                ),
              ),
              if (inv.banks.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Энэ утсан дээрх банкны аппаар төлөх',
                    style: text.titleMedium),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: inv.banks.length,
                  itemBuilder: (_, i) {
                    final b = inv.banks[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openBank(b),
                      child: Column(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(b.logo,
                              width: 52,
                              height: 52,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_balance,
                                  size: 52)),
                        ),
                        const SizedBox(height: 4),
                        Text(b.description,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall),
                      ]),
                    );
                  },
                ),
              ],
              if (inv.shortUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inv.shortUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Холбоос хуулагдлаа')));
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Төлбөрийн холбоос хуулах'),
                ),
              ],
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: vm,
                builder: (_, __) => Column(children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Төлбөр хүлээж байна...'),
                    ],
                  ),
                  if (vm.message != null) ...[
                    const SizedBox(height: 8),
                    Text(vm.message!, textAlign: TextAlign.center),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: vm,
            builder: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: vm.checking ? null : () => vm.check(),
                  child: const Text('Төлбөр шалгах'),
                ),
                if (order.isManual)
                  TextButton(
                    onPressed: () {
                      final messenger = ScaffoldMessenger.of(context);
                      context.read<CartViewModel>().clear();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      messenger.showSnackBar(SnackBar(
                          content: Text(
                              'Захиалга ${order.orderId} бүртгэгдлээ. Төлбөр баталгаажмагц бид холбогдоно.')));
                    },
                    child: const Text('Шилжүүлсэн, дэлгүүр рүү буцах'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _ManualTransferCard extends StatelessWidget {
  const _ManualTransferCard({required this.info, required this.amount});
  final ManualTransfer info;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(label, style: text.bodySmall),
          subtitle: Text(value, style: text.titleMedium),
          trailing: IconButton(
            tooltip: 'Хуулах',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label хуулагдлаа')));
            },
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Дансаар шилжүүлэх', style: text.titleMedium),
            const SizedBox(height: 4),
            if (info.bankName.isNotEmpty) Text(info.bankName),
            row('Дансны дугаар', info.accountNumber),
            if (info.accountHolder.isNotEmpty)
              row('Хүлээн авагч', info.accountHolder),
            row('Дүн', amount.toString()),
            row('Гүйлгээний утга', info.reference),
            const SizedBox(height: 8),
            Text(info.note, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
