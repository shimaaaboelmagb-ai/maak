import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:projectgrad/helper/chat_with_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; 

class HelperTrackingScreen extends StatefulWidget {
  final String helperId;
  final String requestId; 
  final double patientLat;
  final double patientLng;

  const HelperTrackingScreen({
    super.key, 
    required this.helperId, 
    required this.requestId,
    required this.patientLat, 
    required this.patientLng
  });

  @override
  State<HelperTrackingScreen> createState() => _HelperTrackingScreenState();
}

class _HelperTrackingScreenState extends State<HelperTrackingScreen> {
  final MapController _mapController = MapController();

  Future<void> _openGoogleMaps(double destLat, double destLng) async {
    final String googleUrl = 'http://googleusercontent.com/maps.google.com/maps?daddr=$destLat,$destLng';
    if (await canLaunchUrl(Uri.parse(googleUrl))) {
      await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Helper Tracking", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('helpers').doc(widget.helperId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF5BA3C1)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Helper data not available."));
          }

          var helperData = snapshot.data!.data() as Map<String, dynamic>;
          String name = helperData['fullName'] ?? "Volunteer";
          String bio = helperData['bio'] ?? "Active Volunteer";
          
          double helperLat = 0.0;
          double helperLng = 0.0;
          if (helperData['location'] != null) {
            helperLat = (helperData['location']['lat'] ?? 0.0).toDouble();
            helperLng = (helperData['location']['lng'] ?? 0.0).toDouble();
          }

          double distanceInMeters = Geolocator.distanceBetween(widget.patientLat, widget.patientLng, helperLat, helperLng);
          String distanceText = "${(distanceInMeters / 1000).toStringAsFixed(1)} km";
          int etaMinutes = (distanceInMeters / 150).ceil(); 
          String etaText = etaMinutes < 1 ? "Arriving now" : "$etaMinutes min";

          return Column(
            children: [
              // ==========================================
              // 1. الخريطة المدمجة (OpenStreetMap) مجانية 100%
              // ==========================================
              Expanded(
                flex: 5, 
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(widget.patientLat, widget.patientLng),
                    initialZoom: 14.0, // مستوى التقريب
                  ),
                  children: [
                    // طبقة الخريطة الأساسية
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.projectgrad.app', // اسم الباكدج بتاعتك
                    ),
                    // طبقة الماركرز (العلامات)
                    MarkerLayer(
                      markers: [
                        // علامة المريض (أحمر)
                        Marker(
                          point: LatLng(widget.patientLat, widget.patientLng),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                        // علامة المساعد (أزرق)
                        Marker(
                          point: LatLng(helperLat, helperLng),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.person_pin, color: Colors.blue, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==========================================
              // 2. كارت بيانات المساعد والزراير (زي ما هو)
              // ==========================================
              Expanded(
                flex: 4, 
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(radius: 25, backgroundImage: AssetImage('assets/logo2.png')),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(bio, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(etaText, style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(distanceText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context, 
                                    MaterialPageRoute(builder: (context) => ChatWithHelperScreen(
                                      chatId: widget.requestId, 
                                      chatWithHelperId: widget.helperId
                                    ))
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                                label: const Text("Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openGoogleMaps(helperLat, helperLng),
                                icon: const Icon(Icons.directions, color: Colors.white, size: 20),
                                label: const Text("Directions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5BA3C1),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}