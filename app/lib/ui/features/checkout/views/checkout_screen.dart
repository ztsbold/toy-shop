import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart' as config;
import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/delivery_info.dart';
import '../../../core/format.dart';
import '../../cart/view_models/cart_view_model.dart';
import '../../payment/views/payment_screen.dart';
import '../view_models/checkout_view_model.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CheckoutViewModel vm;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _extraPhone = TextEditingController();
  final _khoroo = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  final _register = TextEditingController();
  final _email = TextEditingController();
  String? _district;
  ReceiptType _receipt = ReceiptType.personal;

  @override
  void initState() {
    super.initState();
    vm = CheckoutViewModel(repository: context.read<ShopRepository>());
    vm.loadSaved().then((_) => _prefill(vm.savedDelivery));
  }

  void _prefill(DeliveryInfo? d) {
    if (d == null || !mounted) return;
    setState(() {
      _name.text = d.fullName;
      _phone.text = d.phone;
      _extraPhone.text = d.extraPhone;
      _khoroo.text = d.khoroo;
      _address.text = d.address;
      _email.text = d.email;
      _register.text = d.companyRegister;
      _district = config.districts.contains(d.district) ? d.district : null;
      _receipt = d.receiptType;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _extraPhone, _khoroo, _address, _note, _register, _email
    ]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Заавал бөглөнө үү' : null;

  String? _phoneValidator(String? v, {bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : 'Утасны дугаар оруулна уу';
    return RegExp(r'^[6-9]\d{7}$').hasMatch(s)
        ? null
        : '8 оронтой дугаар оруулна уу';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = context.read<CartViewModel>();
    final delivery = DeliveryInfo(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      extraPhone: _extraPhone.text.trim(),
      district: _district!,
      khoroo: _khoroo.text.trim(),
      address: _address.text.trim(),
      note: _note.text.trim(),
      receiptType: _receipt,
      companyRegister:
          _receipt == ReceiptType.company ? _register.text.trim() : '',
      email: _email.text.trim(),
    );

    final result = await vm.submit(cart.items, delivery);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.error ?? 'Алдаа гарлаа')));
      return;
    }
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => PaymentScreen(order: result)));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    const gap = SizedBox(height: 12);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(title: const Text('Хүргэлтийн мэдээлэл')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Захиалагч'),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Нэр *'),
                  validator: _required,
                ),
                gap,
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digits,
                  maxLength: 8,
                  decoration: const InputDecoration(
                      labelText: 'Утас *', counterText: ''),
                  validator: _phoneValidator,
                ),
                gap,
                TextFormField(
                  controller: _extraPhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: digits,
                  maxLength: 8,
                  decoration: const InputDecoration(
                      labelText: 'Нэмэлт утас', counterText: ''),
                  validator: (v) => _phoneValidator(v, optional: true),
                ),
                gap,
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'И-мэйл (заавал биш)'),
                ),
                _section('Хүргэлтийн хаяг'),
                DropdownButtonFormField<String>(
                  value: _district,
                  decoration:
                      const InputDecoration(labelText: 'Дүүрэг / Аймаг *'),
                  items: [
                    for (final d in config.districts)
                      DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() => _district = v),
                  validator: (v) => v == null ? 'Сонгоно уу' : null,
                ),
                gap,
                TextFormField(
                  controller: _khoroo,
                  decoration: const InputDecoration(labelText: 'Хороо'),
                ),
                gap,
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Дэлгэрэнгүй хаяг *',
                      hintText: 'Байр, орц, давхар, тоот, орцны код'),
                  validator: _required,
                ),
                gap,
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Нэмэлт тайлбар',
                      hintText: 'Хүргүүлэх цаг, бэлэг боодол г.м'),
                ),
                _section('И-баримт'),
                SegmentedButton<ReceiptType>(
                  segments: const [
                    ButtonSegment(
                        value: ReceiptType.personal, label: Text('Хувь хүн')),
                    ButtonSegment(
                        value: ReceiptType.company, label: Text('Байгууллага')),
                  ],
                  selected: {_receipt},
                  onSelectionChanged: (s) =>
                      setState(() => _receipt = s.first),
                ),
                if (_receipt == ReceiptType.company) ...[
                  gap,
                  TextFormField(
                    controller: _register,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    maxLength: 7,
                    decoration: const InputDecoration(
                        labelText: 'Байгууллагын регистр *', counterText: ''),
                    validator: (v) => RegExp(r'^\d{7}$').hasMatch(v ?? '')
                        ? null
                        : '7 оронтой регистр оруулна уу',
                  ),
                ],
                _section('Захиалга'),
                for (final i in cart.items)
                  _line('${i.toy.name} × ${i.qty}', formatMnt(i.subtotal)),
                _line(
                    'Хүргэлт',
                    cart.deliveryFee == 0
                        ? 'Үнэгүй'
                        : formatMnt(cart.deliveryFee)),
                const Divider(),
                _line('Нийт төлөх', formatMnt(cart.total), bold: true),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListenableBuilder(
            listenable: vm,
            builder: (_, __) => FilledButton.icon(
              onPressed: vm.submitting || cart.isEmpty ? null : _submit,
              icon: vm.submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.qr_code_2),
              label: Text('Төлбөр төлөх · ${formatMnt(cart.total)}'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _line(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(a,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : null))),
          Text(b,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ]),
      );
}
