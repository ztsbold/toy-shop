import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';
import 'profile_form.dart';

/// Нэвтрэх урсгалыг нээнэ. Амжилттай нэвтэрч профайлаа бөглөсөн бол true.
Future<bool> showLogin(BuildContext context) async {
  final ok = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok == true;
}

final _emailRe = RegExp(r'^[^\s@]{1,64}@[^\s@]+\.[^\s@]{2,}$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  int _step = 0; // 0 и-мэйл, 1 код, 2 нэр + утас
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();

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
    if (!_emailRe.hasMatch(_emailValue)) {
      setState(() => _error = 'Зөв и-мэйл хаяг оруулна уу');
      return;
    }
    await _run(() async {
      final wait = await context.read<AuthViewModel>().requestOtp(_emailValue);
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
      final needsProfile =
          await context.read<AuthViewModel>().verify(_emailValue, code);
      if (!mounted) return;
      if (needsProfile) {
        setState(() => _step = 2);
      } else {
        Navigator.pop(context, true);
      }
    });
  }

  Future<bool> _onBack() async {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _code.clear();
        _error = null;
      });
      return false;
    }
    if (_step == 2) {
      // Нэвтэрсэн ч профайл дутуу: гарахаас өмнө анхааруулна
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Мэдээлэл дутуу байна'),
          content: const Text(
              'Захиалга өгөхийн тулд нэр, утасны дугаараа оруулах шаардлагатай. Дараа нь бөглөх үү?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Дараа')),
            FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Одоо бөглөх')),
          ],
        ),
      );
      if (leave == true && mounted) Navigator.pop(context, false);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (_step) {
      0 => ('Нэвтрэх', 'И-мэйл хаягаа оруулбал баталгаажуулах код илгээнэ.'),
      1 => ('Код оруулах', '$_emailValue хаягт илгээсэн 6 оронтой кодыг оруулна уу. Spam хавтсаа ч шалгаарай.'),
      _ => ('Таны мэдээлэл', 'Захиалга хүргэхэд нэр, утасны дугаар заавал шаардлагатай.'),
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Буцах',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onBack() && context.mounted) Navigator.pop(context, false);
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
                            'Бүртгүүлээд худалдан авалт бүрээсээ оноо цуглуулж, захиалгаа хянаарай.',
                            style: TextStyle(fontSize: 14.5, height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
                  const SizedBox(height: 22),
                  if (_step == 2)
                    ProfileForm(
                      key: const ValueKey('profile'),
                      submitLabel: 'Хадгалах',
                      onSaved: () => Navigator.pop(context, true),
                    )
                  else ...[
                    if (_step == 0)
                      TextField(
                        key: const ValueKey('email'),
                        controller: _email,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          hintText: 'name@gmail.com',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        onSubmitted: (_) => _sendCode(),
                      )
                    else
                      TextField(
                        key: const ValueKey('code'),
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                        onChanged: (v) {
                          if (v.length == 6) _verify();
                        },
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : (_step == 0 ? _sendCode : _verify),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_step == 0 ? 'Код авах' : 'Баталгаажуулах'),
                    ),
                    if (_step == 1) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _wait > 0 || _busy ? null : _sendCode,
                        child: Text(_wait > 0 ? 'Код дахин авах ($_wait сек)' : 'Код дахин авах'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _onBack(),
                        child: const Text('И-мэйл хаяг солих'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
