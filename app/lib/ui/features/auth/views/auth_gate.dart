import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../shell/home_shell.dart';
import '../view_models/auth_view_model.dart';
import 'login_screen.dart';
import 'profile_form.dart';

/// Апп-ын эхлэл: нэвтрээгүй бол нэвтрэх/бүртгүүлэх, нэр-утас дутуу бол бөглүүлэх,
/// бүгд бэлэн бол дэлгүүр. Ингэснээр бүх захиалга хэрэглэгчийн бүртгэлтэй холбогдоно.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Гарах / бүртгэл устгах / token хүчингүй болох үед дээр нээлттэй байсан
  /// дэлгэцүүдийг (сагс, захиалга г.м) хаана.
  void _popToRoot(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (!auth.ready) return const _Splash();
    if (auth.offline) return _Offline(onRetry: auth.init);
    if (!auth.isLoggedIn) {
      _popToRoot(context);
      return const LoginScreen(gate: true);
    }
    if (auth.needsProfile) {
      _popToRoot(context);
      return const _CompleteProfile();
    }
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandHeader(),
            SizedBox(height: 28),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ачаалж байна...\nАнх нээхэд түр хугацаа шаардагдаж магадгүй.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.wifi_off,
          message: 'Сервертэй холбогдож чадсангүй.\nИнтернэтээ шалгаад дахин оролдоно уу.',
          actionLabel: 'Дахин оролдох',
          onAction: onRetry,
        ),
      );
}

/// Шинэ бүртгэл: нэр, утас бөглөхөөс нааш дэлгүүр рүү оруулахгүй
class _CompleteProfile extends StatelessWidget {
  const _CompleteProfile();

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthViewModel>().customer?.email ?? '';
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  const Text('Таны мэдээлэл',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Захиалга хүргэхэд нэр, утасны дугаар заавал шаардлагатай.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15)),
                  const SizedBox(height: 22),
                  // Хадгалмагц AuthGate дэлгүүр рүү шилжүүлнэ
                  ProfileForm(submitLabel: 'Үргэлжлүүлэх', onSaved: () {}),
                  const SizedBox(height: 24),
                  if (email.isNotEmpty)
                    Text('$email хаягаар нэвтэрсэн',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  TextButton(
                    onPressed: () => context.read<AuthViewModel>().logout(),
                    child: const Text('Өөр и-мэйлээр нэвтрэх'),
                  ),
                  const SizedBox(height: 8),
                  const Text('$brandMark $brandName',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
