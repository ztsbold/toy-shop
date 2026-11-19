import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';

/// Нэвтрэх урсгалыг нээнэ. Амжилттай нэвтэрвэл true.
Future<bool> showLogin(BuildContext context) async {
  final ok = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok == true;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  int _step = 0; // 0 утас, 1 код, 2 нэр
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^[6-9]\d{7}$').hasMatch(phone)) {
      setState(() => _error = '8 оронтой утасны дугаар оруулна уу');
      return;
    }
    await _run(() async {
      final wait = await context.read<AuthViewModel>().requestOtp(phone);
      if (!mounted) return;
      setState(() => _step = 1);
      _startCountdown(wait);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = '6 оронтой код оруулна уу');
      return;
    }
    await _run(() async {
      final needsName =
          await context.read<AuthViewModel>().verify(_phone.text.trim(), code);
      if (!mounted) return;
      if (needsName) {
        setState(() => _step = 2);
      } else {
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Нэрээ оруулна уу');
      return;
    }
    await _run(() async {
      await context.read<AuthViewModel>().updateName(name);
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      0 => ('Нэвтрэх', 'Утасны дугаараа оруулбал баталгаажуулах код SMS-ээр очно.'),
      1 => ('Код оруулах', '${_phone.text} дугаарт илгээсэн 6 оронтой кодыг оруулна уу.'),
      _ => ('Таны нэр', 'Захиалга хүргэхэд ашиглана.'),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Буцах',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 1) {
              setState(() {
                _step = 0;
                _code.clear();
                _error = null;
              });
            } else {
              Navigator.pop(context, _step == 2);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (_step == 0) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sky,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(children: [
                      Icon(Icons.stars_rounded, color: AppColors.blue, size: 36),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Бүртгүүлээд худалдан авалт бүрээсээ оноо цуглуулж, '
                          'захиалгаа хянаарай.',
                          style: TextStyle(fontSize: 14.5, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                const SizedBox(height: 22),
                if (_step == 0)
                  TextField(
                    controller: _phone,
                    autofocus: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 8,
                    style: const TextStyle(fontSize: 20, letterSpacing: 1),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '9911 2233',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    onSubmitted: (_) => _sendCode(),
                  )
                else if (_step == 1)
                  TextField(
                    controller: _code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    style: const TextStyle(
                        fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
                    decoration:
                        const InputDecoration(counterText: '', hintText: '••••••'),
                    onChanged: (v) {
                      if (v.length == 6) _verify();
                    },
                  )
                else
                  TextField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Бүтэн нэр',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : switch (_step) { 0 => _sendCode, 1 => _verify, _ => _saveName },
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(switch (_step) {
                          0 => 'Код авах',
                          1 => 'Баталгаажуулах',
                          _ => 'Хадгалах',
                        }),
                ),
                if (_step == 1) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _wait > 0 || _busy ? null : _sendCode,
                    child: Text(_wait > 0
                        ? 'Код дахин авах ($_wait сек)'
                        : 'Код дахин авах'),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Нэвтэрснээр $brandMark $brandName дэлгүүрээс таны утсанд захиалгын мэдээлэл SMS-ээр ирнэ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
