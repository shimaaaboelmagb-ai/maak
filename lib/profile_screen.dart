import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart'; 
import 'role_selection_screen.dart';
class ProfileScreen extends StatefulWidget {
  final bool isDarkMode; // 👈 استقبلنا حالة الدارك مود هنا
  const ProfileScreen({super.key, required this.isDarkMode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String? _profileImageBase64; 
  bool _isLocationEnabled = true;
  bool _isUploadingImage = false; 

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) setState(() => _userEmail = user.email ?? "No Email");
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          if (mounted) {
            setState(() {
              _userName = userDoc.get('fullName') ?? "User";
              var data = userDoc.data() as Map<String, dynamic>;
              if (data.containsKey('profileImageBase64')) {
                _profileImageBase64 = data['profileImageBase64'];
              }
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _userName = user.displayName ?? "User");
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30, maxWidth: 400);

    if (image != null) {
      setState(() => _isUploadingImage = true); 

      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          File imageFile = File(image.path);
          List<int> imageBytes = await imageFile.readAsBytes();
          String base64String = base64Encode(imageBytes);

          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'profileImageBase64': base64String},
            SetOptions(merge: true), 
          );

          if (mounted) {
            setState(() {
              _profileImageBase64 = base64String;
              _isUploadingImage = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green));
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingImage = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update picture: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 متغيرات الألوان بناءً على الدارك مود
    bool isDark = widget.isDarkMode;
    Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F9FD);
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color imageBorderColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color iconBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Profile", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: imageBorderColor, width: 3), // 🎨 البرواز بيتغير مع المود
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1), blurRadius: 10, offset: const Offset(0, 5))],
                      image: _profileImageBase64 != null && _profileImageBase64!.isNotEmpty
                          ? DecorationImage(
                              image: MemoryImage(base64Decode(_profileImageBase64!)), 
                              fit: BoxFit.cover,
                            )
                          : null, 
                    ),
                    child: _profileImageBase64 == null || _profileImageBase64!.isEmpty
                        ? const Icon(Icons.person, size: 55, color: Colors.blue) 
                        : null,
                  ),
                  
                  _isUploadingImage
                      ? Container(
                          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(4),
                          child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF4A98B4),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: _pickAndUploadImage, 
                          ),
                        )
                ],
              ),
            ),
            const SizedBox(height: 15),

            Center(child: Text(_userName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor))),
            const SizedBox(height: 5),
            Center(child: Text(_userEmail, style: TextStyle(fontSize: 15, color: isDark ? Colors.grey.shade400 : Colors.grey))),
            const SizedBox(height: 40),

            _buildCustomOption(
              icon: Icons.person, 
              title: "Personal Details", 
              isDark: isDark, 
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                ).then((value) {
                  if (value == true) {
                    _fetchUserData();
                  }
                });
              }
            ),
            const SizedBox(height: 10),
            _buildCustomOption(
              icon: Icons.medical_services_outlined, 
              title: "Medical ID", 
              subtitle: "Disability info & emergency notes", 
              isDark: isDark, 
              onTap: () {}
            ),
            
            const SizedBox(height: 35),
            
            const Text("Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5A7184))),
            const SizedBox(height: 15),

            _buildCustomOption(
              icon: Icons.location_on, 
              title: "Location Services", 
              isDark: isDark,
              trailing: Switch(
                value: _isLocationEnabled,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF4A98B4),
                inactiveThumbColor: isDark ? Colors.grey.shade400 : Colors.white,
                inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                onChanged: (value) => setState(() => _isLocationEnabled = value),
              ),
              onTap: () => setState(() => _isLocationEnabled = !_isLocationEnabled)
            ),

            const SizedBox(height: 40),
            
            Center(
              child: TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  // 🎨 تعديل الدالة دي عشان تستقبل isDark وتظبط ألوان النصوص
  Widget _buildCustomOption({required IconData icon, required String title, String? subtitle, Widget? trailing, required bool isDark, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 45, height: 45,
              decoration: BoxDecoration(color: const Color(0xFF4A98B4), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF7C8B99), fontSize: 13)),
                  ]
                ],
              ),
            ),
            trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey.shade600 : Colors.grey),
          ],
        ),
      ),
    );
  }
}