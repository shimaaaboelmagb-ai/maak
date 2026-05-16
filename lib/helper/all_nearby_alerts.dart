import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:projectgrad/helper/chat_with_helper.dart'; 

class AllNearbyAlertsScreen extends StatelessWidget {
  const AllNearbyAlertsScreen({super.key});

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permission denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? ""; 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Nearby Emergency Alerts", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<Position>(
        future: _getCurrentLocation(),
        builder: (context, locationSnapshot) {
          if (locationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5BA3C1)));
          }
          if (locationSnapshot.hasError) {
            return const Center(child: Text("Please enable location permissions to see alerts."));
          }

          Position helperPos = locationSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_requests')
                // ✨ التعديل 1: شيلنا 'active' عشان الشاشة تحترم التايمر زي الهوم بالظبط
                .where('status', whereIn: ['searching', 'accepted']) 
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No emergency alerts nearby at the moment.", 
                    style: TextStyle(color: Colors.grey))
                );
              }

              // ✨ التعديل 2: الفلترة بقت بتسمح بـ searching والطلبات اللي هو قبلها بس
              var alerts = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String status = data['status'] ?? '';
                String helperId = data['helperId'] ?? '';
                
                if (status == 'searching') return true; 
                if (status == 'accepted' && helperId == currentUid) return true; 
                return false; 
              }).toList();

              if (alerts.isEmpty) {
                return const Center(
                  child: Text("No emergency alerts nearby at the moment.", style: TextStyle(color: Colors.grey))
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  var data = alerts[index].data() as Map<String, dynamic>;
                  String docId = alerts[index].id;

                  double targetLat = 0.0;
                  double targetLng = 0.0;

                  if (data['location'] != null) {
                    targetLat = (data['location']['lat'] ?? 0.0).toDouble();
                    targetLng = (data['location']['lng'] ?? 0.0).toDouble();
                  }

                  double distanceInMeters = Geolocator.distanceBetween(
                    helperPos.latitude, helperPos.longitude, targetLat, targetLng,
                  );
                  
                  String distanceLabel = "${(distanceInMeters / 1000).toStringAsFixed(1)} km away";

                  return _buildDetailedCard(context, docId, data, distanceLabel, currentUid);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailedCard(BuildContext context, String docId, Map<String, dynamic> data, String distance, String currentUid) {
    bool isMyAcceptedMission = (data['status'] == 'accepted' && data['helperId'] == currentUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isMyAcceptedMission ? const Color(0xFFF1F8E9) : Colors.white, 
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: isMyAcceptedMission ? Colors.green.withOpacity(0.3) : const Color(0xFFEEEEEE)),
        boxShadow: [
          // ignore: deprecated_member_use
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isMyAcceptedMission ? Icons.verified : Icons.warning_amber_rounded, 
                      color: isMyAcceptedMission ? Colors.green : Colors.red, size: 16),
                    const SizedBox(width: 5),
                    Text(isMyAcceptedMission ? "YOUR MISSION" : "CRITICAL SOS", 
                      style: TextStyle(color: isMyAcceptedMission ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(data['userName'] ?? "Emergency Case", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text(distance, 
                  style: const TextStyle(color: Color(0xFF5BA3C1), fontSize: 13, fontWeight: FontWeight.bold)),
                Text(isMyAcceptedMission ? "Chat is open" : "Needs immediate assistance", 
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      if (!isMyAcceptedMission) {
                        await FirebaseFirestore.instance.collection('sos_requests').doc(docId).update({
                          'status': 'accepted', 
                          'helperId': currentUid,
                        });

                        await FirebaseFirestore.instance.collection('helpers').doc(currentUid).update({
                          'peopleHelped': FieldValue.increment(1),
                        });
                      }

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatWithHelperScreen(
                              chatId: docId, 
                              chatWithHelperId: data['userId'] ?? "", 
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Could not accept request."))
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyAcceptedMission ? Colors.green : const Color(0xFF5BA3C1), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: Text(isMyAcceptedMission ? "Resume Chat" : "Accept Request", 
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              double lat = (data['location']['lat'] ?? 0.0).toDouble();
              double lng = (data['location']['lng'] ?? 0.0).toDouble();
              String googleUrl = 'http://googleusercontent.com/maps.google.com/maps?q=$lat,$lng';
              if (await canLaunchUrl(Uri.parse(googleUrl))) {
                await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5), 
                borderRadius: BorderRadius.circular(15)
              ),
              child: const Icon(Icons.directions_rounded, color: Color(0xFF5BA3C1), size: 35),
            ),
          ),
        ],
      ),
    );
  }
}