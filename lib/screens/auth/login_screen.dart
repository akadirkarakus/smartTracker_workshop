import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/calibration_data.dart';
import '../../services/auth_service.dart';
import '../calibration_screen.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await AuthService.instance.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
  }

  Future<void> _continueAsGuest() async {
    setState(() => _submitting = true);
    await AuthService.instance.continueAsGuest();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppTheme.instance.darkNotifier,
      builder: (_, _) => Scaffold(
        backgroundColor: CalColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Image.asset('assets/logo.png', height: 96)),
                    const SizedBox(height: 8),
                    Text(
                      'Takograf Servis Uygulaması',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CalColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
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
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    AuthPrimaryButton(
                      label: 'Giriş Yap',
                      loading: _submitting,
                      onPressed: _submitting ? null : _login,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Hesabınız yok mu?', style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant)),
                        TextButton(
                          onPressed: _submitting ? null : _openSignup,
                          child: Text('Kayıt Ol', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Divider(color: CalColors.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('veya', style: TextStyle(fontSize: 12, color: CalColors.outline)),
                        ),
                        Expanded(child: Divider(color: CalColors.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _continueAsGuest,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CalColors.primary,
                          side: BorderSide(color: CalColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.person_outline, size: 20),
                        label: const Text('Misafir Olarak Devam Et', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
