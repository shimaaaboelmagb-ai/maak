import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatWithHelperScreen extends StatefulWidget {
  final String chatId;           // ID من كولكشن sos_requests
  final String chatWithHelperId; // ID الشخص التاني (سواء كان مريض أو مساعد)

  const ChatWithHelperScreen({
    super.key,
    required this.chatId,
    required this.chatWithHelperId,
  });

  @override
  State<ChatWithHelperScreen> createState() => _ChatWithHelperScreenState();
}

class _ChatWithHelperScreenState extends State<ChatWithHelperScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // دالة تحديث الحالة لـ Arrived في كولكشن sos_requests
  Future<void> _updateChatWithHelperStatus() async {
    await _firestore.collection('sos_requests').doc(widget.chatId).update({
      'status': 'arrived',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Arrival Confirmed!"), backgroundColor: Colors.green),
      );
    }
  }

  // ✨ تعديل 1: فتح الخريطة بالإحداثيات الديناميكية الصح
  Future<void> _openChatWithHelperMap(double lat, double lng) async {
    final String googleMapsUrl = "http://maps.google.com/maps?q=$lat,$lng";
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Emergency Chat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // الاستماع لبيانات الحدث من sos_requests
        stream: _firestore.collection('sos_requests').doc(widget.chatId).snapshots(),
        builder: (context, sosSnapshot) {
          if (!sosSnapshot.hasData || !sosSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          var sosData = sosSnapshot.data!.data() as Map<String, dynamic>;
          double lat = (sosData['location']?['lat'] ?? 0.0).toDouble(); // تأكيد إنها بتقرا الماب الصح
          double lng = (sosData['location']?['lng'] ?? 0.0).toDouble();
          String status = sosData['status'] ?? "pending";
          
          // ✨ تعديل 2 و 3: تحديد مين اللي فاتح الشاشة عشان نجيب بيانات الطرف التاني صح
          bool isMeHelper = currentUser?.uid == sosData['helperId']; 
          String otherPersonCollection = isMeHelper ? 'users' : 'helpers'; // لو أنا المساعد، هجيب بيانات المريض من users، والعكس

          return Column(
            children: [
              // 1. كارت الموقع 
              GestureDetector(
                onTap: () => _openChatWithHelperMap(lat, lng),
                child: _buildChatWithHelperLocationCard(lat, lng, status),
              ),

              // 2. بروفايل الطرف التاني (ديناميكي بيقرا من الكولكشن الصح)
              FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection(otherPersonCollection).doc(widget.chatWithHelperId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    return _buildChatWithHelperProfile(
                      userData['fullName'] ?? "Unknown User",
                      userData['phone'] ?? "No Phone",
                    );
                  }
                  return const LinearProgressIndicator(color: Color(0xFFE3F2FD));
                },
              ),

              // 3. منطقة الرسائل
              Expanded(child: _buildChatWithHelperMessages()),

              // 4. منطقة الإدخال وزر الوصول
              _buildChatWithHelperBottomArea(status, isMeHelper), // باصينا المتغير هنا عشان نتحكم في الزرار
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatWithHelperLocationCard(double lat, double lng, String status) {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2196F3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Color(0xFFBBDEFB), child: Icon(Icons.location_on, color: Color(0xFF1976D2))),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Emergency Location", style: TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
                Text("Tap to navigate: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}", style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.circle, color: status == "arrived" ? Colors.green : Colors.orange, size: 12),
        ],
      ),
    );
  }

  Widget _buildChatWithHelperProfile(String name, String phone) {
    return ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFFF5F5F5), child: Icon(Icons.person, color: Colors.grey)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Phone: $phone"),
      trailing: IconButton(
        icon: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.phone, color: Colors.white, size: 18)),
        onPressed: () async {
          final Uri url = Uri.parse("tel:$phone");
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
      ),
    );
  }

  Widget _buildChatWithHelperMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var docs = snapshot.data!.docs;
        return ListView.builder(
          reverse: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index];
            bool isMe = data['senderId'] == currentUser?.uid;
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1A4D7A) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(data['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatWithHelperBottomArea(String status, bool isMeHelper) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
      ),
      child: Column(
        children: [
          // ✨ تعديل 4: الزرار هيظهر للمساعد بس، وطالما لسه موصلش
          if (isMeHelper && status != "arrived")
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: _updateChatWithHelperStatus,
                child: const Text("I HAVE ARRIVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          
          if (isMeHelper && status != "arrived")
            const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: "Type a message...", 
                    filled: true, 
                    fillColor: const Color(0xFFF5F5F5), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const CircleAvatar(backgroundColor: Color(0xFF1A4D7A), child: Icon(Icons.send, color: Colors.white, size: 20)),
                onPressed: () {
                  if (_messageController.text.isNotEmpty) {
                    _firestore.collection('chats').doc(widget.chatId).collection('messages').add({
                      'text': _messageController.text.trim(),
                      'senderId': currentUser?.uid,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}