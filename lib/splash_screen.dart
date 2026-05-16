import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'onboarding_screen.dart';
import 'main.dart'; // 👈 عشان نقدر نوصل للـ AuthWrapper

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTimeAndLoginState();
  }

  Future<void> _checkFirstTimeAndLoginState() async {
    await Future.delayed(const Duration(seconds: 3)); // 3 ثواني كفاية جداً

    if (!mounted) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seenOnboard = prefs.getBool('seenOnboard') ?? false;

    if (!mounted) return;

    if (seenOnboard) {
      // 🌟 لو شاف الاونبوردينج، نبعته للموزع الذكي وهو يتصرف
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    } else {
      // أول مرة يفتح التطبيق -> يروح للاونبوردينج
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 450,
              height: 450,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/logo.jpeg'), 
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Color.fromARGB(255, 94, 183, 255),
            ),
          ],
        ),
      ),
    );
  }
}