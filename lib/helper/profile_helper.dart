import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileHelperScreen extends StatefulWidget {
  const ProfileHelperScreen({super.key});

  @override
  State<ProfileHelperScreen> createState() => _ProfileHelperScreenState();
}

class _ProfileHelperScreenState extends State<ProfileHelperScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;

  // ✨ دالة الرفع السحرية بنفس فكرة كود صاحبك (حفظ مباشر في Firestore بدون Storage)
  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // تقليل الجودة لتصغير حجم النص المحفوظ
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
      });

      String? uid = _auth.currentUser?.uid;
      if (uid == null) return;

      // 1. قراءة الملف وتحويله إلى سطر نصي (Base64 String)
      File file = File(pickedFile.path);
      List<int> imageBytes = await file.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // 2. الحفظ المباشر داخل ديسيومنت Firestore زي كود صاحبك بالظبط
      await _firestore.collection('helpers').doc(uid).update({
        'profilePic': base64Image, // بنخزن النص هنا
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تحديث الصورة الشخصية بنجاح!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("فشل في حفظ الصورة: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showImageSourceBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2B92E4)),
              title: const Text('التقاط صورة الكاميرا'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF2B92E4),
              ),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    String currentName,
    String currentBio,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentName,
    );
    final TextEditingController bioController = TextEditingController(
      text: currentBio,
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "تعديل الحساب",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "الاسم بالكامل",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: bioController,
              decoration: InputDecoration(
                labelText: "تاريخ الانضمام / نبذة تظهر بجانب الاسم",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.dispose();
              bioController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B92E4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              String? uid = _auth.currentUser?.uid;
              if (uid != null) {
                await _firestore.collection('helpers').doc(uid).update({
                  'fullName': nameController.text.trim(),
                  'bio': bioController.text.trim(),
                });
              }

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              nameController.dispose();
              bioController.dispose();
            },
            child: const Text("حفظ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not Logged In")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9FC),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('helpers').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2B92E4)),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile data not found."));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text("No data available."));
          }

          String name = data['fullName'] ?? "Name Not Set";
          String bio = data['bio'] ?? "Joined Oct 2023";
          String? profilePic = data['profilePic'];
          int livesImpacted = data['peopleHelped'] ?? 0;

          double avgRating = 0.0;
          if (data['avgRating'] != null) {
            avgRating = (data['avgRating'] as num).toDouble();
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD6EFFE),
                            image:
                                (!_isUploading &&
                                    profilePic != null &&
                                    profilePic.isNotEmpty)
                                ? DecorationImage(
                                    // ✨ تعديل عرض الصورة عشان يقرا النص المشفر (Base64) مباشرة
                                    image: MemoryImage(
                                      base64Decode(profilePic),
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF2B92E4),
                                    strokeWidth: 3,
                                  ),
                                )
                              : (profilePic == null || profilePic.isEmpty)
                              ? Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "S",
                                    style: const TextStyle(
                                      fontSize: 46,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B75BB),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        GestureDetector(
                          onTap: () => _showImageSourceBottomSheet(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2B92E4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: () => _showEditProfileDialog(context, name, bio),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      child: Column(
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1E1E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Verified Volunteer",
                                style: TextStyle(
                                  color: Color(0xFF2B92E4),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "  •  $bio",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      _buildStatBox(
                        livesImpacted.toString(),
                        "Lives Impacted",
                        Icons.people_rounded,
                        const Color(0xFFF3F9FF),
                      ),
                      const SizedBox(width: 16),
                      _buildStatBox(
                        avgRating.toString(),
                        "Avg Rating",
                        Icons.star_rounded,
                        const Color(0xFFFAF5FF),
                        iconColor: const Color(0xFF9146FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildHeader("Badges Earned", "8 Total"),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBadge(
                        Icons.home_rounded,
                        "First Responder",
                        "Active",
                        const Color(0xFFD6EFFE),
                        const Color(0xFF007AFF),
                      ),
                      _buildBadge(
                        Icons.hourglass_bottom_rounded,
                        "50+ Hours",
                        "Achieved",
                        const Color(0xFFFFF7E3),
                        const Color(0xFFFFB900),
                      ),
                      _buildBadge(
                        Icons.star_rounded,
                        "Top Rated",
                        "Elite",
                        const Color(0xFFFAF5FF),
                        const Color(0xFF9146FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  _buildHeader("Past Assists", ""),
                  const SizedBox(height: 14),

                  _buildAssistCard(
                    title: "Mobility Assistance",
                    timeLocation: "Today, 2:30 PM • Main St Station",
                    rating: "5.0",
                    icon: Icons.accessible_rounded,
                    iconBgColor: const Color(0xFFEBF5FF),
                    iconColor: const Color(0xFF007AFF),
                  ),
                  _buildAssistCard(
                    title: "Emergency Support",
                    timeLocation: "Oct 24, 2023 • Central Park",
                    rating: "4.8",
                    icon: Icons.medical_services_outlined,
                    iconBgColor: const Color(0xFFEFFFF6),
                    iconColor: const Color(0xFF00B661),
                  ),
                  _buildAssistCard(
                    title: "Navigation Aid",
                    timeLocation: "Oct 21, 2023 • City Library",
                    rating: "5.0",
                    icon: Icons.stars_rounded,
                    iconBgColor: const Color(0xFFFFF3ED),
                    iconColor: const Color(0xFFFF6B00),
                  ),
                  _buildAssistCard(
                    title: "Daily Task Assist",
                    timeLocation: "Oct 18, 2023 • Market Sq.",
                    rating: "5.0",
                    icon: Icons.shopping_cart_outlined,
                    iconBgColor: const Color(0xFFF3EFFF),
                    iconColor: const Color(0xFF7042F2),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatBox(
    String value,
    String label,
    IconData icon,
    Color bgColor, {
    Color iconColor = const Color(0xFF007AFF),
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E1E1E),
          ),
        ),
        if (trailing.isNotEmpty)
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF2B92E4),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildBadge(
    IconData icon,
    String title,
    String subtitle,
    Color bgColor,
    Color iconColor,
  ) {
    return Column(
      children: [
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistCard({
    required String title,
    required String timeLocation,
    required String rating,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLocation,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB900),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                rating,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
