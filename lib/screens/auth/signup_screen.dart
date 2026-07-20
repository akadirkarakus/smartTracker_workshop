import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/calibration_data.dart';
import '../../services/auth_service.dart';
import '../calibration_screen.dart';
import 'auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await AuthService.instance.signUp(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      name: _nameCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance.darkNotifier,
      builder: (_, _) => Scaffold(
        backgroundColor: CalColors.background,
        appBar: AppBar(
          backgroundColor: CalColors.background,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: CalColors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Kayıt Ol', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    AuthErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  AuthTextField(
                    controller: _nameCtrl,
                    label: 'Ad Soyad',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.name,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Ad soyad giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _emailCtrl,
                    label: 'E-posta',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'E-posta adresi giriniz';
                      if (!v.contains('@') || !v.contains('.')) return 'Geçerli bir e-posta giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _passwordCtrl,
                    label: 'Şifre',
                    icon: Icons.lock_outline,
                    obscureText: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CalColors.outline),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Şifre giriniz';
                      if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmCtrl,
                    label: 'Şifre (Tekrar)',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CalColors.outline),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v != _passwordCtrl.text) return 'Şifreler eşleşmiyor';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Kayıt Ol',
                    loading: _submitting,
                    onPressed: _submitting ? null : _signUp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
