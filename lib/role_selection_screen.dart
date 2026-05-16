import 'package:flutter/material.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key}); // السطر ده مهم عشان الأداء وبيمنع تحذيرات تانية
  
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // المتغير ده هيحفظ اختيار المستخدم (helper أو disabled)
  String selectedRole = ''; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // زرار الرجوع للصفحة السابقة
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0, top: 10.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // العنوان الرئيسي
            const Text(
              "How would you\nlike to join us?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // اختيارات الأدوار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRoleOption(
                  role: 'helper',
                  title: 'Helper',
                  imagePath: 'assets/helper.png', // ضيف صورة الـ Helper هنا
                ),
                _buildRoleOption(
                  role: 'disabled',
                  title: 'Disabled',
                  imagePath: 'assets/disable.png', // ضيف صورة الـ Disabled هنا
                ),
              ],
            ),
            
            const Spacer(),
            
            // زرار الـ SELECT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // لو مفيش دور متحدد، الزرار هيكون null (معطل)
                  onPressed: selectedRole.isEmpty 
                      ? null 
                      : () {
                          // 👇 التعديل هنا: بنوجه المستخدم لصفحة الدخول وبنبعتله الدور اللي اختاره
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(role: selectedRole)
                            )
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A98B4), // لون الزرار الأزرق
                    disabledBackgroundColor: Colors.grey.shade300, // لون الزرار وهو معطل
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SELECT",
                        style: TextStyle(
                          fontSize: 16, 
                          color: selectedRole.isEmpty ? Colors.grey.shade500 : Colors.white, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward, 
                        color: selectedRole.isEmpty ? Colors.grey.shade500 : Colors.white, 
                        size: 20
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // دالة (Widget) مخصصة عشان تبني شكل الاختيار الدائري وتوفر تكرار الكود
  Widget _buildRoleOption({required String role, required String title, required String imagePath}) {
    bool isSelected = selectedRole == role;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRole = role; // تحديث الحالة بالدور اللي تم اختياره
        });
      },
      child: Column(
        children: [
          Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
              // عمل إطار أزرق لو الاختيار متفعل
              border: Border.all(
                color: isSelected ? const Color.fromARGB(255, 35, 175, 226) : Colors.transparent,
                width: 3,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: Image.asset(imagePath), // اعرض الصورة
            ),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color.fromARGB(255, 31, 172, 223) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
