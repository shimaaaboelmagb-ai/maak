import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:projectgrad/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'role_selection_screen.dart';
import 'home_screen.dart';
import 'helper/home_helper.dart';
//import 'camera_screen.dart';

// كلاس لتخطي شهادات الأمان (عشان الـ OTP يوصل)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseMessaging.instance.requestPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAAK',
      theme: ThemeData(
        primaryColor: const Color(0xFF4B94B1),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // البداية دايماً شاشة الاسبلاش
    );
  }
}

// ✨ الموزع الذكي (بالذاكرة القوية)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getInitialScreen(User user) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. نقرأ الدور من الذاكرة المحلية (سريعة جداً)
    String? cachedRole = prefs.getString('user_role_${user.uid}');

    if (cachedRole == 'helper') return const HelperHomeScreen();
    if (cachedRole == 'user') return const HomeScreen();

    // 2. لو دي أول مرة نفتح الأبلكيشن بعد التحديث ومفيش حاجة في الذاكرة، نسأل فايربيز
    try {
      var doc = await FirebaseFirestore.instance
          .collection('helpers')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        await prefs.setString('user_role_${user.uid}', 'helper');
        return const HelperHomeScreen();
      } else {
        await prefs.setString('user_role_${user.uid}', 'user');
        return const HomeScreen();
      }
    } catch (e) {
      return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4B94B1)),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const RoleSelectionScreen();
        }

        return FutureBuilder<Widget>(
          future: _getInitialScreen(snapshot.data!),
          builder: (context, screenSnapshot) {
            if (screenSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFF4B94B1)),
                ),
              );
            }
            return screenSnapshot.data ?? const HomeScreen();
          },
        );
      },
    );
  }
}
