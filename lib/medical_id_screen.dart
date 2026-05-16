import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MedicalIDScreen extends StatefulWidget {
  const MedicalIDScreen({super.key});

  @override
  State<MedicalIDScreen> createState() => _MedicalIDScreenState();
}

class _MedicalIDScreenState extends State<MedicalIDScreen> {
  bool _isLoading = true;
  bool _isEditing = false; // التحكم في وضع التعديل
  bool _isSaving = false;

  // Controllers للبيانات
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  String? _selectedBloodType;

  Map<String, dynamic> userData = {};
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _loadMedicalData();
  }

  // 1. سحب البيانات من Firebase
  Future<void> _loadMedicalData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          userData = userDoc.data() as Map<String, dynamic>;
          _conditionsController.text = userData['chronicConditions'] ?? '';
          _allergiesController.text = userData['allergies'] ?? '';
          _medicationsController.text = userData['medications'] ?? '';
          _selectedBloodType = userData['bloodType'];
          _isLoading = false;
        });
      }
    }
  }

  // 2. دالة الحفظ
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'chronicConditions': _conditionsController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'bloodType': _selectedBloodType,
      }, SetOptions(merge: true));

      await _loadMedicalData(); // إعادة تحميل البيانات للعرض
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medical ID Updated!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _isSaving = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isEditing ? Icons.close : Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            if (_isEditing) {
              setState(() => _isEditing = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text("Edit", style: TextStyle(color: Color(0xFF4A98B4), fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 30),

                  // القسم الأول: الحالات الطبية
                  _buildSectionHeader(Icons.analytics_outlined, "Medical Conditions--الحالات"),
                  _isEditing
                      ? _buildEditField(_conditionsController, "e.g. Asthma, Diabetes")
                      : _buildDisplayItem(Icons.air, Colors.blue, "Conditions", userData['chronicConditions'] ?? "None"),
                  const SizedBox(height: 25),

                  // القسم الثاني: الحساسية
                  _buildSectionHeader(Icons.warning_amber_rounded, "Allergies--الحساسيه والامراض"),
                  _isEditing
                      ? _buildEditField(_allergiesController, "e.g. Peanuts, Penicillin")
                      : _buildDisplayItem(Icons.coronavirus_outlined, Colors.redAccent, "Allergies", userData['allergies'] ?? "No allergies"),
                  const SizedBox(height: 25),

                  // القسم الثالث: الأدوية
                  _buildSectionHeader(Icons.medication_liquid_rounded, "Medications"),
                  _isEditing
                      ? _buildEditField(_medicationsController, "e.g. Insulin, Inhaler")
                      : _buildDisplayItem(Icons.medication_outlined, Colors.green, "Medications", userData['medications'] ?? "No medications"),

                  const SizedBox(height: 40),

                  // زرار الحفظ بيظهر بس في وضع التعديل
                  if (_isEditing)
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
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // 🎨 ويدجت الهيدر (صورة وبروفايل)
  Widget _buildProfileHeader() {
    String? imgBase64 = userData['profileImageBase64'];
    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.grey.shade100,
          backgroundImage: (imgBase64 != null && imgBase64.isNotEmpty) ? MemoryImage(base64Decode(imgBase64)) : null,
          child: (imgBase64 == null || imgBase64.isEmpty) ? const Icon(Icons.person, size: 60, color: Colors.blue) : null,
        ),
        const SizedBox(height: 15),
        Text(userData['fullName'] ?? "User", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // في وضع التعديل، فصيلة الدم بتكون Dropdown
        _isEditing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBloodType,
                    hint: const Text("Blood Type"),
                    items: _bloodTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedBloodType = val),
                  ),
                ),
              )
            : Text("Age: ${userData['birthDate'] ?? '--'}  •  Blood: ${userData['bloodType'] ?? '--'}",
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // 🎨 ويدجت عنوان القسم
  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5E7A91), size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5E7A91))),
        ],
      ),
    );
  }

  // 🎨 ويدجت العرض (نفس شكل الصورة اللي بعتها)
  Widget _buildDisplayItem(IconData icon, Color color, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          // ignore: deprecated_member_use
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(value, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade300),
      ],
    );
  }

  // 🎨 ويدجت خانة الكتابة (بتظهر بس لما تدوس Edit)
  Widget _buildEditField(TextEditingController controller, String hint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        maxLines: 2,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.all(15)),
      ),
    );
  }
}