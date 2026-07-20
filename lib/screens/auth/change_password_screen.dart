import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/calibration_data.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await AuthService.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Şifreniz başarıyla değiştirildi.'), behavior: SnackBarBehavior.floating),
    );
    Navigator.of(context).pop();
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
          title: Text('Şifre Değiştir', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
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
                    controller: _currentCtrl,
                    label: 'Mevcut Şifre',
                    icon: Icons.lock_outline,
                    obscureText: _obscureCurrent,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CalColors.outline),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mevcut şifrenizi giriniz';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _newCtrl,
                    label: 'Yeni Şifre',
                    icon: Icons.lock_reset_outlined,
                    obscureText: _obscureNew,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CalColors.outline),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Yeni şifre giriniz';
                      if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmCtrl,
                    label: 'Yeni Şifre (Tekrar)',
                    icon: Icons.lock_reset_outlined,
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CalColors.outline),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v != _newCtrl.text) return 'Şifreler eşleşmiyor';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: 'Şifreyi Güncelle',
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
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
