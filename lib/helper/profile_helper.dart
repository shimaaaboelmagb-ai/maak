import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileHelperScreen extends StatefulWidget {
  const ProfileHelperScreen({super.key});

  @override
  State<ProfileHelperScreen> createState() => _ProfileHelperScreenState();
}

class _ProfileHelperScreenState extends State<ProfileHelperScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // دالة لفتح نافذة تعديل البيانات
  void _showEditProfileDialog(BuildContext context, String currentName, String currentBio) {
    TextEditingController nameController = TextEditingController(text: currentName);
    TextEditingController bioController = TextEditingController(text: currentBio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: bioController,
              decoration: InputDecoration(
                labelText: "Bio / Status",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90B2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              String uid = _auth.currentUser!.uid;
              // ✨ حفظ البيانات الجديدة في الفايربيز
              await _firestore.collection('helpers').doc(uid).update({
                'fullName': nameController.text.trim(),
                'bio': bioController.text.trim(),
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Profile updated successfully!"), backgroundColor: Colors.green),
              );
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Not Logged In"));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // شيلنا سهم الرجوع عشان ده Navbar
        title: const Text(
          "Your Impact",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // ✨ StreamBuilder بيقرا البيانات لايف من الفايربيز
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('helpers').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A90B2)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Profile data not found."));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['fullName'] ?? "Volunteer";
          String bio = data['bio'] ?? "Active Volunteer"; // لو مفيش Bio بيكتب دي مؤقتاً
          int peopleHelped = data['peopleHelped'] ?? 0;
          
          // حساب الساعات
          int totalMins = data['totalActiveMinutes'] ?? 0;
          if (data['isOnline'] == true && data['sessionStartTime'] != null) {
            Timestamp startTs = data['sessionStartTime'];
            totalMins += DateTime.now().difference(startTs.toDate()).inMinutes;
          }
          String activeHours = totalMins ~/ 60 > 0 ? "${totalMins ~/ 60}h" : "${totalMins}m";

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('assets/logo2.png'), // تقدر تخليها صورة من الفايربيز بعدين
                      backgroundColor: Color(0xFFF4F9FD),
                    ),
                    // ✨ زرار تعديل البيانات
                    GestureDetector(
                      onTap: () => _showEditProfileDialog(context, name, bio),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4A90B2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  "$bio • Verified Helper",
                  style: const TextStyle(color: Color(0xFF4A90B2), fontSize: 13),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    _buildStatBox(
                      peopleHelped.toString(),
                      "Lives Impacted",
                      Icons.people_outline,
                    ),
                    const SizedBox(width: 15),
                    _buildStatBox(activeHours, "Active Time", Icons.access_time),
                  ],
                ),
                const SizedBox(height: 30),
                
                // --- الجزء ده (البادجات والماضي) لسه Static كـ UI ديكور لحد ما نربطه ---
                _buildHeader("Badges Earned", "3 Total"),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadge(Icons.local_fire_department, "Top Responder", Colors.orange),
                    _buildBadge(Icons.favorite, "Caring Heart", Colors.red),
                    _buildBadge(Icons.speed, "Fast Arriver", Colors.blue),
                  ],
                ),
                const SizedBox(height: 30),
                _buildHeader("Recent Activity", ""),
                const SizedBox(height: 10),
                _buildAssistTile("Medical Emergency", "Helped a patient nearby", "5.0", Icons.medical_services, const Color(0xFF4A90B2)),
                _buildAssistTile("Mobility Assist", "Wheelchair support", "4.8", Icons.accessible, const Color(0xFF4A90B2)),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "View All History",
                    style: TextStyle(color: Color(0xFF4A90B2), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets المساعدة ---
  Widget _buildStatBox(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE1F0FF)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4A90B2)),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(trailing, style: const TextStyle(color: Color(0xFF4A90B2), fontSize: 13)),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildAssistTile(String title, String subtitle, String rating, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}