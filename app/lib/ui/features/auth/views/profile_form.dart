import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../view_models/auth_view_model.dart';

/// Нэр ба утасны дугаар (хоёулаа заавал). Нэвтрэх болон профайл засахад ашиглана.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, required this.onSaved, this.submitLabel = 'Хадгалах'});

  final VoidCallback onSaved;
  final String submitLabel;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = context.read<AuthViewModel>().customer;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthViewModel>().updateProfile(_name.text.trim(), _phone.text.trim());
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          key: const ValueKey('name'),
          controller: _name,
          autofocus: _name.text.isEmpty,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Нэр *',
            hintText: 'Бүтэн нэр',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Нэрээ оруулна уу' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const ValueKey('phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 8,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Утасны дугаар *',
            hintText: '9911 2233',
            counterText: '',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          validator: (v) => RegExp(r'^[6-9]\d{7}$').hasMatch((v ?? '').trim())
              ? null
              : '8 оронтой утасны дугаар оруулна уу',
          onFieldSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(widget.submitLabel),
        ),
      ]),
    );
  }
}

/// Профайл засах дэлгэц (Бүртгэл таб → харандаа, эсвэл профайл дутуу үед)
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthViewModel>().customer?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Миний мэдээлэл')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (email.isNotEmpty) ...[
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'И-мэйл (нэвтрэх хаяг)',
                prefixIcon: Icon(Icons.mail_outline),
                enabled: false,
              ),
              child: Text(email),
            ),
            const SizedBox(height: 14),
          ],
          ProfileForm(onSaved: () => Navigator.pop(context, true)),
        ],
      ),
    );
  }
}
