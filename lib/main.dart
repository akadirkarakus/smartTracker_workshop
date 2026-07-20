import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/calibration_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';

void main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  runApp(const TachographApp());
}

class TachographApp extends StatelessWidget 
{
  const TachographApp({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp(
      title: 'Takograf İzleme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5F7A),
          brightness: Brightness.light,
          surface: Colors.white,
          onSurface: const Color(0xFF0D3347),
        ),
        scaffoldBackgroundColor: const Color(0xFFE8F4F8),
        cardColor: Colors.white,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: SplashScreen(
        next: AuthService.instance.isLoggedIn ? const CalibrationScreen() : const LoginScreen(),
      ),
    );
  }
}
