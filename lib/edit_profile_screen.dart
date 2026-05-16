import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // المتغيرات الجديدة لتاريخ الميلاد والنوع
  String? _birthDate;
  String? _gender;
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 1. سحب البيانات من الداتابيز
  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          var data = userDoc.data() as Map<String, dynamic>;
          
          if (mounted) {
            setState(() {
              _nameController.text = data['fullName'] ?? user.displayName ?? '';
              _phoneController.text = data['phone'] ?? '';
              _birthDate = data['birthDate']; // سحب تاريخ الميلاد القديم
              _gender = data['gender'];       // سحب النوع القديم
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // 2. حفظ التعديلات
  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name cannot be empty!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'birthDate': _birthDate, // حفظ تاريخ الميلاد
          'gender': _gender,       // حفظ النوع
        }, SetOptions(merge: true));

        await user.updateDisplayName(_nameController.text.trim());

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
          Navigator.pop(context, true); 
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // 3. دالة فتح نتيجة لاختيار تاريخ الميلاد
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // البداية الافتراضية
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF4A98B4)), // تلوين النتيجة باللون بتاعنا
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        // تظبيط شكل التاريخ (يوم/شهر/سنة)
        _birthDate = "${picked.day.toString().padLeft(2, '0')} / ${picked.month.toString().padLeft(2, '0')} / ${picked.year}";
      });
    }
  }

  // 4. دالة فتح قائمة لاختيار النوع
  void _selectGender(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Gender", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.male, color: Colors.blue),
                title: const Text("Male"),
                onTap: () {
                  setState(() => _gender = "Male");
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.female, color: Colors.pink),
                title: const Text("Female"),
                onTap: () {
                  setState(() => _gender = "Female");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text("Personal Details", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Update your personal information", style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 30),

                // خانة الاسم (بنفس الاستايل الرمادي الفاتح بتاعك)
                _buildTextField(icon: Icons.person_outline, hint: "Full Name", controller: _nameController),
                const SizedBox(height: 15),

                // خانة رقم التليفون
                _buildTextField(icon: Icons.phone_outlined, hint: "Phone Number", controller: _phoneController, isPhone: true),
                const SizedBox(height: 15),

                // 👇 خانة تاريخ الميلاد (زي الصورة بالظبط)
                _buildSelectionBox(
                  icon: Icons.cake_outlined, // غيرت الأيقونة لـ كيكة عشان تعبر عن الميلاد
                  title: "Birth",
                  value: _birthDate ?? "      /      /      ", // الشكل اللي في صورتك
                  trailing: const SizedBox(), // مفيش سهم هنا
                  onTap: () => _selectBirthDate(context),
                ),
                const SizedBox(height: 15),

                // 👇 خانة النوع (زي الصورة بالظبط)
                _buildSelectionBox(
                  icon: Icons.person_outline,
                  title: "Gender",
                  value: _gender ?? "",
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black87), // السهم اللي في صورتك
                  onTap: () => _selectGender(context),
                ),

                const SizedBox(height: 40),

                // زرار الحفظ
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A98B4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _isSaving ? null : _saveChanges,
                    child: _isSaving 
                        ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 🎨 دالة تصميم خانات الكتابة عشان تبقى شبه الصورة (خلفية رمادي فاتح)
  Widget _buildTextField({required IconData icon, required String hint, required TextEditingController controller, bool isPhone = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // لون رمادي فاتح زي الصورة
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey.shade700),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  // 🎨 دالة تصميم الخانات الجديدة (تاريخ الميلاد والنوع) مطابقة للصورة بتاعتك
  Widget _buildSelectionBox({required IconData icon, required String title, required String value, required Widget trailing, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // لون رمادي فاتح زي الصورة
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 24),
            const SizedBox(width: 15),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.black54)), // لون رمادي زي الصورة
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87)), // قيمة التاريخ أو النوع
            const SizedBox(width: 10),
            trailing, // السهم لو موجود
          ],
        ),
      ),
    );
  }
}