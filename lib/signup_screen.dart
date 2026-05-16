import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  final String role; // 👈 ضفنا استقبال الدور هنا
  const SignUpScreen({super.key, required this.role}); // 👈 لازم الدور يتبعت

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isObscure = true;        // لإخفاء الباسورد
  bool _isConfirmObscure = true; // لإخفاء تأكيد الباسورد
  bool _isLoading = false; // 👈 ضفتلك المتغير ده عشان نلفف الزرار وقت التحميل

  // =========================================================
  // 1. تعريف الـ Controllers عشان نمسك البيانات اللي اليوزر بيكتبها
  // =========================================================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // =========================================================
  // 2. ✨ دالة إنشاء الحساب الذكية في Firebase و Firestore
  // =========================================================
  Future<void> _signUp() async {
    // التأكد أولاً إن كلمتين المرور متطابقتين
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("كلمة المرور غير متطابقة!"),
          backgroundColor: Colors.red,
        ),
      );
      return; 
    }

    setState(() => _isLoading = true);

    try {
      // إنشاء الحساب في Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await userCredential.user!.updateDisplayName(_nameController.text.trim());
      // الحصول على الـ uid الخاص بالمستخدم الجديد
      String uid = userCredential.user!.uid;

      // ✨ اللوجيك بتاع فصل الداتابيز
      String collectionName = widget.role == 'helper' ? 'helpers' : 'users';

      // حفظ باقي البيانات في Firestore في الكولكشن الصح
      await FirebaseFirestore.instance.collection(collectionName).doc(uid).set({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': widget.role, // 👈 نحفظ دوره عشان نكون متأكدين
        'createdAt': FieldValue.serverTimestamp(), 
      });

      if (!mounted) return; 
      setState(() => _isLoading = false);

      // رسالة النجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إنشاء الحساب وحفظ البيانات بنجاح!"),
          backgroundColor: Colors.green,
        ),
      );

      // الرجوع للشاشة السابقة (الـ AuthWrapper هيلقط إنك سجلت دخول ويوديك للـ Home المناسب)
      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      if (!mounted) return; 
      setState(() => _isLoading = false);

      String errorMessage = '';
      if (e.code == 'weak-password') {
        errorMessage = 'كلمة المرور ضعيفة جداً.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'هذا الحساب موجود بالفعل.';
      } else {
        errorMessage = 'حدث خطأ: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return; 
      setState(() => _isLoading = false);
      // ignore: avoid_print
      print("خطأ في حفظ البيانات: $e");
    }
  }

  // =========================================================
  // 3. تنظيف الذاكرة لما نخرج من الشاشة
  // =========================================================
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4B94B1); // الأزرق بتاعنا

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= الجزء العلوي =================
            SizedBox(
              height: 150, 
              child: Stack(
                children: [
                  Positioned(
                    top: -80,
                    left: -100,
                    child: Image.asset(
                      'assets/123.png', 
                      width: 400,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // زرار الرجوع اللي فوق على الشمال
                  Positioned(
                    top: 50,
                    left: 10,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            
            // ================= اللوجو والعنوان =================
            Image.asset(
              'assets/logo2.png', 
              height: 50, 
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            
            Text(
              // 👈 بنغير العنوان ديناميكياً عشان اليوزر يحس إنه في المكان الصح
              widget.role == 'helper' ? "Join as Helper" : "Create Account",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Text(
              "Join us now!",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // ================= الخانات =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  // --- الاسم كامل ---
                  _buildTextField(
                    icon: Icons.person_outline, 
                    hint: "Full Name", 
                    controller: _nameController, 
                  ),
                  const SizedBox(height: 15),

                  // --- البريد الإلكتروني ---
                  _buildTextField(
                    icon: Icons.email_outlined, 
                    hint: "Email Address", 
                    controller: _emailController, 
                  ),
                  const SizedBox(height: 15),

                  // --- رقم الهاتف ---
                  _buildTextField(
                    icon: Icons.phone_android, 
                    hint: "Phone Number", 
                    controller: _phoneController, 
                  ),
                  const SizedBox(height: 15),

                  // --- كلمة المرور ---
                  TextField(
                    controller: _passwordController, 
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- تأكيد كلمة المرور ---
                  TextField(
                    controller: _confirmPasswordController, 
                    obscureText: _isConfirmObscure,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: Icon(_isConfirmObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _isConfirmObscure = !_isConfirmObscure),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ================= زر التسجيل =================
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isLoading ? null : _signUp, // بنوقف الزرار لو بيحمل
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "SIGN UP",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================= الرجوع لصفحة الدخول =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Log in",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // دالة بناء الخانات
  // =========================================================
  Widget _buildTextField({required IconData icon, required String hint, required TextEditingController controller}) {
    return TextField(
      controller: controller, 
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF2F2F2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}