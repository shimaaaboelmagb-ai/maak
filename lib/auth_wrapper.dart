import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projectgrad/home_screen.dart'; // مسار الشاشة الرئيسية بتاعك
import 'package:projectgrad/login_screen.dart'; // مسار شاشة تسجيل الدخول

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key}); // تم إضافة الـ Key هنا

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        // ده السطر اللي بيراقب حالة المستخدم لحظة بلحظة
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // لو في بيانات (يعني المستخدم مسجل دخول بالفعل)
          if (snapshot.hasData) {
            return const HomeScreen(); // تم إضافة const هنا
          } 
          // لو مفيش بيانات (يعني محتاج يسجل دخول)
          else {
            return const LoginScreen(role: 'disable',); // تم إضافة const هنا
          }
        },
      ),
    );
  }
}