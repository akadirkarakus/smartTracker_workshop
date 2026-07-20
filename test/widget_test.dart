import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takograpp_d1/main.dart';
import 'package:takograpp_d1/screens/auth/change_password_screen.dart';
import 'package:takograpp_d1/screens/auth/login_screen.dart';
import 'package:takograpp_d1/screens/auth/profile_screen.dart';
import 'package:takograpp_d1/screens/auth/signup_screen.dart';
import 'package:takograpp_d1/screens/calibration_screen.dart';
import 'package:takograpp_d1/services/auth_service.dart';

// Avoids pumpAndSettle: the dashboard's DashboardTab runs a repeating pulse
// AnimationController, which would make pumpAndSettle time out whenever the
// splash screen's destination is already the (logged-in) CalibrationScreen.
Future<void> _skipSplash(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await _settle(tester);
}

// Same reasoning as _skipSplash: once CalibrationScreen exists anywhere in
// the tree (even under a pushed route), its dashboard's repeating pulse
// animation makes pumpAndSettle time out, so bounded pumps are used instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches into the Login screen when no session is persisted', (tester) async {
    await AuthService.instance.init();
    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Misafir Olarak Devam Et'), findsOneWidget);
  });

  testWidgets('Continuing as guest navigates to the dashboard', (tester) async {
    await AuthService.instance.init();
    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.text('Misafir Olarak Devam Et'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CalibrationScreen), findsOneWidget);
    expect(AuthService.instance.isGuest, isTrue);
  });

  testWidgets('Sign up creates an account and navigates to the dashboard, then re-login works', (tester) async {
    await AuthService.instance.init();
    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad Soyad'), 'Test Kullanıcı');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'secret123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre (Tekrar)'), 'secret123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CalibrationScreen), findsOneWidget);
    expect(AuthService.instance.currentEmail, 'test@example.com');

    // Log back in with the same credentials against a fresh AuthService session.
    await AuthService.instance.logout();
    final error = await AuthService.instance.login(email: 'test@example.com', password: 'secret123');
    expect(error, isNull);
    expect(AuthService.instance.currentEmail, 'test@example.com');
  });

  testWidgets('Wrong password is rejected with an error message', (tester) async {
    await AuthService.instance.init();
    await AuthService.instance.signUp(email: 'wrongpw@example.com', password: 'correct123', name: 'Wrong Pw');
    await AuthService.instance.logout();

    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), 'wrongpw@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'wrongpassword');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('hatalı'), findsOneWidget);
  });

  testWidgets('Account icon on the dashboard shows the profile with name and email', (tester) async {
    await AuthService.instance.init();
    await AuthService.instance.signUp(email: 'profile@example.com', password: 'secret123', name: 'Ada Lovelace');

    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await _settle(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('profile@example.com'), findsWidgets);
  });

  testWidgets('Change password updates credentials so the old password no longer works', (tester) async {
    await AuthService.instance.init();
    await AuthService.instance.signUp(email: 'changepw@example.com', password: 'oldpass123', name: 'Grace Hopper');

    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await _settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Şifre Değiştir'));
    await _settle(tester);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Mevcut Şifre'), 'oldpass123');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni Şifre'), 'newpass456');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni Şifre (Tekrar)'), 'newpass456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Şifreyi Güncelle'));
    await _settle(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);

    await AuthService.instance.logout();
    final oldPasswordError = await AuthService.instance.login(email: 'changepw@example.com', password: 'oldpass123');
    expect(oldPasswordError, isNotNull);
    final newPasswordError = await AuthService.instance.login(email: 'changepw@example.com', password: 'newpass456');
    expect(newPasswordError, isNull);
  });

  testWidgets('Logout button on the profile screen ends the session and returns to Login', (tester) async {
    await AuthService.instance.init();
    await AuthService.instance.signUp(email: 'logout@example.com', password: 'secret123', name: 'Log Out');

    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await _settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Çıkış Yap'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Çıkış Yap'));
    await _settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(AuthService.instance.isLoggedIn, isFalse);
  });

  testWidgets('Guest profile screen offers both Kayıt Ol and Oturum Aç', (tester) async {
    await AuthService.instance.init();
    await tester.pumpWidget(const TachographApp());
    await _skipSplash(tester);

    await tester.tap(find.text('Misafir Olarak Devam Et'));
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await _settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Kayıt Ol'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Oturum Aç'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Oturum Aç'));
    await _settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
