import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/calibration_data.dart';
import '../../services/auth_service.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _logout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.w700, color: CalColors.error)),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CalColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  String _initials(String? name, String? email) {
    final source = (name != null && name.trim().isNotEmpty) ? name.trim() : email ?? '?';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final isGuest = auth.isGuest;
    final name = auth.currentName;
    final email = auth.currentEmail;

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
          title: Text('Hesap Bilgileri', style: TextStyle(color: CalColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: CalColors.outlineVariant)),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: CalColors.primaryContainer,
                        child: Text(
                          isGuest ? '?' : _initials(name, email),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isGuest ? 'Misafir Kullanıcı' : (name ?? '—'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CalColors.onSurface),
                      ),
                      if (!isGuest && email != null) ...[
                        const SizedBox(height: 2),
                        Text(email, style: TextStyle(fontSize: 13, color: CalColors.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                if (isGuest) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CalColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Misafir olarak oturum açtınız. Hesap bilgilerinizi görüntülemek ve şifre yönetmek için kayıt olun ya da mevcut hesabınızla oturum açın.',
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CalColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                      label: const Text('Kayıt Ol', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CalColors.primary,
                        side: BorderSide(color: CalColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text('Oturum Aç', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  Container(
                    decoration: BoxDecoration(
                      color: CalColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CalColors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(icon: Icons.badge_outlined, label: 'Ad Soyad', value: name ?? '—'),
                        Divider(height: 1, color: CalColors.outlineVariant),
                        _InfoRow(icon: Icons.email_outlined, label: 'E-posta', value: email ?? '—'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CalColors.primary,
                        side: BorderSide(color: CalColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_reset_outlined, size: 20),
                      label: const Text('Şifre Değiştir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CalColors.error,
                      side: BorderSide(color: CalColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Çıkış Yap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: CalColors.onSurfaceVariant, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: CalColors.onSurfaceVariant))),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CalColors.onSurface))),
        ],
      ),
    );
  }
}
