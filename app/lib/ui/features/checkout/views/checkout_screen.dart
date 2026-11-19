import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/delivery_info.dart';
import '../../../../domain/models/shop_config.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../auth/view_models/auth_view_model.dart';
import '../../auth/views/login_screen.dart';
import '../../cart/view_models/cart_view_model.dart';
import '../../config/shop_config_view_model.dart';
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
  final _building = TextEditingController();
  final _apartment = TextEditingController();
  final _localArea = TextEditingController(); // орон нутагт сум/баг
  final _note = TextEditingController();
  final _register = TextEditingController();
  String? _district;
  String? _khoroo;
  bool _company = false;
  String? _optionId;
  bool _usePoints = false;
  int _formVersion = 0; // dropdown-уудыг дахин бөглөхөд

  @override
  void initState() {
    super.initState();
    vm = CheckoutViewModel(repository: context.read<ShopRepository>());
    vm.loadSaved().then((_) {
      _prefill(vm.savedDelivery);
      _prefillFromAccount();
    });
    // Хүргэлтийн үнийг хамгийн сүүлийн байдлаар нь авна
    context.read<ShopConfigViewModel>().load();
  }

  void _prefill(DeliveryInfo? d) {
    if (d == null || !mounted) return;
    setState(() {
      _name.text = d.fullName;
      _phone.text = d.phone;
      _note.text = '';
      _register.text = d.companyRegister;
      _company = d.receiptType == ReceiptType.company;
      _district = districts.containsKey(d.district) ? d.district : null;
      final max = districts[_district] ?? 0;
      if (max == 0) {
        _khoroo = null;
        _localArea.text = d.khoroo;
      } else {
        final k = int.tryParse(d.khoroo);
        _khoroo = (k != null && k >= 1 && k <= max) ? '$k' : null;
      }
      _building.text = d.building;
      _apartment.text = d.apartment;
      _formVersion++;
    });
  }

  /// Нэвтэрсэн бол нэр, утсыг бүртгэлээс бөглөнө (хоосон бол)
  void _prefillFromAccount() {
    final c = context.read<AuthViewModel>().customer;
    if (c == null || !mounted) return;
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = c.name;
      if (_phone.text.trim().isEmpty) _phone.text = c.phone;
    });
  }

  Future<void> _login() async {
    if (await showLogin(context)) _prefillFromAccount();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _building, _apartment, _localArea, _note, _register
    ]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Заавал бөглөнө үү' : null;

  String? _phoneValidator(String? v) {
    final s = (v ?? '').replaceAll('-', '').trim();
    if (s.isEmpty) return 'Утасны дугаар оруулна уу';
    return RegExp(r'^[6-9]\d{7}$').hasMatch(s)
        ? null
        : '8 оронтой дугаар оруулна уу';
  }

  DeliveryOption _selectedOption(ShopConfig cfg) => cfg.deliveryOptions
      .firstWhere((o) => o.id == _optionId,
          orElse: () => cfg.deliveryOptions.first);

  Future<void> _submit(ShopConfig cfg) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Улаанаар тэмдэглэсэн талбаруудыг бөглөнө үү.')));
      return;
    }
    final cart = context.read<CartViewModel>();
    final isLocal = (districts[_district] ?? 0) == 0;
    final delivery = DeliveryInfo(
      fullName: _name.text.trim(),
      phone: _phone.text.replaceAll('-', '').trim(),
      district: _district!,
      khoroo: isLocal ? _localArea.text.trim() : (_khoroo ?? ''),
      building: _building.text.trim(),
      apartment: _apartment.text.trim(),
      note: _note.text.trim(),
      receiptType: _company ? ReceiptType.company : ReceiptType.personal,
      companyRegister: _company ? _register.text.trim() : '',
    );

    final auth = context.read<AuthViewModel>();
    final points = _pointsToUse(cfg, cart, auth);
    final result = await vm.submit(cart.items, delivery, _selectedOption(cfg).id,
        pointsToUse: points);
    if (points > 0) auth.refresh();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(vm.error ?? 'Алдаа гарлаа')));
      return;
    }
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => PaymentScreen(order: result)));
  }

  int _eligibleSubtotal(CartViewModel cart) => cart.items
      .where((i) => i.toy.pointsEligible)
      .fold(0, (s, i) => s + i.subtotal);

  int _maxPoints(ShopConfig cfg, CartViewModel cart, AuthViewModel auth) =>
      auth.isLoggedIn
          ? cfg.loyalty.maxUsable(
              balance: auth.points, eligibleSubtotal: _eligibleSubtotal(cart))
          : 0;

  int _pointsToUse(ShopConfig cfg, CartViewModel cart, AuthViewModel auth) =>
      _usePoints ? _maxPoints(cfg, cart, auth) : 0;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final auth = context.watch<AuthViewModel>();
    final cfg = context.watch<ShopConfigViewModel>().config;
    final option = _selectedOption(cfg);
    final fee = cfg.feeFor(option, cart.subtotal);
    final maxPoints = _maxPoints(cfg, cart, auth);
    final usedPoints = _pointsToUse(cfg, cart, auth);
    final discount = usedPoints * cfg.loyalty.pointValue;
    final rawTotal = cart.subtotal + fee - discount;
    final total = rawTotal < 0 ? 0 : rawTotal;
    final willEarn = cfg.loyalty.pointsFor(cart.subtotal - discount);
    final khorooMax = districts[_district] ?? 0;
    final isLocal = _district != null && khorooMax == 0;
    const gap = SizedBox(height: 14);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        title: const Text('Захиалга өгөх'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.verified_user_outlined, color: AppColors.ink),
          ),
        ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _SectionTitle(
                    icon: Icons.location_on, title: 'Хүргэлтийн мэдээлэл'),
                _Card(children: [
                  const _Label('Нэр', required: true),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Бүтэн нэрээ оруулна уу',
                      suffixIcon: Icon(Icons.person_outline),
                    ),
                    validator: _required,
                  ),
                  gap,
                  const _Label('Утасны дугаар', required: true),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: digits,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      hintText: 'xxxx-xxxx',
                      counterText: '',
                      suffixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: _phoneValidator,
                  ),
                  gap,
                  const _Label('Хүргэлтийн хаяг',
                      required: true, hint: '(дүүрэг, хороо, байр)'),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      flex: 5,
                      child: _Dropdown(
                        key: ValueKey('d$_formVersion'),
                        label: 'Дүүрэг',
                        value: _district,
                        items: districts.keys.toList(),
                        onChanged: (v) => setState(() {
                          _district = v;
                          _khoroo = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: isLocal
                          ? _LabeledField(
                              label: 'Сум, баг',
                              child: TextFormField(
                                controller: _localArea,
                                decoration:
                                    const InputDecoration(hintText: 'Сум'),
                                validator: _required,
                              ),
                            )
                          : _Dropdown(
                              key: ValueKey('k$_district$_formVersion'),
                              label: 'Хороо',
                              value: _khoroo,
                              items: [
                                for (var i = 1; i <= khorooMax; i++) '$i'
                              ],
                              itemLabel: (v) => '$v-р хороо',
                              enabled: _district != null,
                              onChanged: (v) => setState(() => _khoroo = v),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _LabeledField(
                        label: 'Байр',
                        child: TextFormField(
                          controller: _building,
                          decoration:
                              const InputDecoration(hintText: 'Байр'),
                          validator: _required,
                        ),
                      ),
                    ),
                  ]),
                  gap,
                  const _Label('Орц, давхар, тоот', required: true),
                  TextFormField(
                    controller: _apartment,
                    decoration: const InputDecoration(
                      hintText: '2-р орц, 5 давхар, 34 тоот',
                      suffixIcon: Icon(Icons.door_front_door_outlined),
                    ),
                    validator: _required,
                  ),
                  gap,
                  const _Label('Нэмэлт тэмдэглэл'),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Орцны код, хүргүүлэх цаг гэх мэт',
                      suffixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _company,
                    onChanged: (v) => setState(() => _company = v),
                    title: const Text('Байгууллагаар И-баримт авах',
                        style: TextStyle(fontSize: 15)),
                  ),
                  if (_company)
                    TextFormField(
                      controller: _register,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      maxLength: 7,
                      decoration: const InputDecoration(
                          hintText: 'Байгууллагын регистр (7 орон)',
                          counterText: ''),
                      validator: (v) => RegExp(r'^\d{7}$').hasMatch(v ?? '')
                          ? null
                          : '7 оронтой регистр оруулна уу',
                    ),
                ]),
                const SizedBox(height: 22),
                const _SectionTitle(
                    icon: Icons.local_shipping, title: 'Хүргэлтийн сонголт'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    for (var i = 0; i < cfg.deliveryOptions.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      _OptionTile(
                        option: cfg.deliveryOptions[i],
                        fee: cfg.feeFor(cfg.deliveryOptions[i], cart.subtotal),
                        selected: cfg.deliveryOptions[i].id == option.id,
                        onTap: () => setState(
                            () => _optionId = cfg.deliveryOptions[i].id),
                      ),
                    ],
                  ]),
                ),
                if (cfg.freeDeliveryFrom > 0 &&
                    cart.subtotal < cfg.freeDeliveryFrom)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${formatMnt(cfg.freeDeliveryFrom)}-с дээш захиалгад стандарт хүргэлт үнэгүй.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 22),
                const _SectionTitle(icon: Icons.stars_rounded, title: 'Оноо'),
                _Card(children: [
                  if (!auth.isLoggedIn) ...[
                    Text(
                      willEarn > 0
                          ? 'Нэвтэрвэл энэ захиалгаас $willEarn оноо авна.'
                          : 'Нэвтэрч худалдан авалт бүрээс оноо цуглуулаарай.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _login, child: const Text('Нэвтрэх')),
                  ] else ...[
                    Row(children: [
                      const Text('Таны оноо', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      Text('${formatNumber(auth.points)} оноо',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.blue)),
                    ]),
                    if (maxPoints > 0)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _usePoints,
                        onChanged: (v) => setState(() => _usePoints = v),
                        title: Text('$maxPoints оноо ашиглах',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Нийт дүнгээс ${formatMnt(maxPoints * cfg.loyalty.pointValue)} хасагдана'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _eligibleSubtotal(cart) == 0
                              ? 'Сагсанд "Оноогоор авч болно" тэмдэгтэй бараа алга.'
                              : 'Ашиглах оноо хуримтлагдаагүй байна.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    if (willEarn > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Энэ захиалгаас +$willEarn оноо авна.',
                            style: const TextStyle(
                                color: AppColors.blue, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ]),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(
                  child: Text('Нийт төлөх дүн',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                Text(formatMnt(total),
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blue)),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Бараа ${formatMnt(cart.subtotal)} + хүргэлт ${fee == 0 ? 'үнэгүй' : formatMnt(fee)}'
                  '${discount > 0 ? ' − оноо ${formatMnt(discount)}' : ''}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: vm,
                builder: (_, __) => SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        vm.submitting || cart.isEmpty ? null : () => _submit(cfg),
                    icon: vm.submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.lock),
                    label: const Text('Захиалга баталгаажуулах'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.blue,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Container(width: 52, height: 2.5, color: AppColors.blue),
          ]),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false, this.hint});
  final String text;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: text,
              style:
                  const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
          if (required)
            const TextSpan(
                text: '  *',
                style: TextStyle(
                    color: AppColors.blue, fontWeight: FontWeight.w800)),
          if (hint != null)
            TextSpan(
                text: '\n$hint',
                style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        ])),
      );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: const TextStyle(fontSize: 14.5)),
          ),
          child,
        ],
      );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String Function(String)? itemLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) => _LabeledField(
        label: label,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          hint: const Text('Сонгоно уу',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 14)),
          icon: const Icon(Icons.keyboard_arrow_down),
          menuMaxHeight: 360,
          items: [
            for (final v in items)
              DropdownMenuItem(
                value: v,
                child: Text(itemLabel?.call(v) ?? v,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          selectedItemBuilder: (_) => [
            for (final v in items)
              Text(v, overflow: TextOverflow.ellipsis),
          ],
          onChanged: enabled ? onChanged : null,
          validator: (v) => v == null ? 'Сонгоно уу' : null,
          decoration: const InputDecoration(
              contentPadding: EdgeInsets.fromLTRB(12, 14, 6, 14)),
        ),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.fee,
    required this.selected,
    required this.onTap,
  });

  final DeliveryOption option;
  final int fee;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected ? AppColors.sky : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? AppColors.blue : AppColors.muted,
                    width: 2),
              ),
              alignment: Alignment.center,
              child: selected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.blue))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (option.eta.isNotEmpty)
                    Text(option.eta,
                        style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            Text(fee == 0 ? 'Үнэгүй' : formatMnt(fee),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: fee == 0 ? AppColors.blue : AppColors.ink)),
            if (selected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle_outline, color: AppColors.blue),
            ],
          ]),
        ),
      ),
    );
  }
}
