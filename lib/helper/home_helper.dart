import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:projectgrad/helper/ai_translator_screen.dart';

// Screens imports
import 'all_nearby_alerts.dart';
import 'chat_with_helper.dart';
import 'quick_signs_screen.dart';
import 'profile_helper.dart';
import 'package:projectgrad/community_screen.dart';

class HelperHomeScreen extends StatefulWidget {
  const HelperHomeScreen({super.key});

  @override
  State<HelperHomeScreen> createState() => _HelperHomeScreenState();
}

class _HelperHomeScreenState extends State<HelperHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userName = "Volunteer";
  int peopleHelped = 0;
  bool isOnline = false;
  String activeHours = "0m";
  String currentAddress = "Locating...";

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _updateFCMToken();
    _updateLocationIfOnline();

    // Foreground messaging handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data.isNotEmpty && message.data['type'] == 'sos_alert') {
        if (mounted) {
          _showEmergencyDialog(context, message);
        }
      }
    });

    // Background/Terminated click handler
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty && message.data['type'] == 'sos_alert') {
        _openMap(
          message.data['lat']?.toString(),
          message.data['lng']?.toString(),
        );
      }
    });
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          currentAddress = "${place.street ?? ''}, ${place.locality ?? ''}"
              .trim();
          if (currentAddress.startsWith(',')) {
            currentAddress = currentAddress.substring(1).trim();
          }
          if (currentAddress.isEmpty) {
            currentAddress = "Unknown Location";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentAddress = "Address not found";
        });
      }
    }
  }

  Future<void> _openMap(String? lat, String? lng) async {
    if (lat == null || lng == null || lat.isEmpty || lng.isEmpty) return;

    final String googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch maps application target.");
      }
    } catch (e) {
      debugPrint("Error opening map: $e");
    }
  }

  void _showEmergencyDialog(BuildContext context, RemoteMessage message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text("🚨 SOS ALERT", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message.notification?.body ?? "Someone needs help near you!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("IGNORE"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              _openMap(
                message.data['lat']?.toString(),
                message.data['lng']?.toString(),
              );
            },
            child: const Text(
              "I AM COMING",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLocationIfOnline() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _getAddressFromLatLng(position);

        await _firestore.collection('helpers').doc(uid).set({
          'location': {'lat': position.latitude, 'lng': position.longitude},
          'lastUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  void _updateFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      String? uid = _auth.currentUser?.uid;
      if (uid != null && token != null) {
        await _firestore.collection('helpers').doc(uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }

  Widget _buildHomeView(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('helpers').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic> helperData = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          helperData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        }

        userName = helperData['fullName'] ?? "Volunteer";
        isOnline = helperData['isOnline'] ?? false;
        peopleHelped = helperData['peopleHelped'] ?? 0;

        int totalMins = helperData['totalActiveMinutes'] ?? 0;
        if (isOnline && helperData['sessionStartTime'] != null) {
          var sessionTime = helperData['sessionStartTime'];
          if (sessionTime is Timestamp) {
            totalMins += DateTime.now()
                .difference(sessionTime.toDate())
                .inMinutes;
          }
        }
        int hours = totalMins ~/ 60;
        int mins = totalMins % 60;
        activeHours = hours > 0 ? "${hours}h ${mins}m" : "${mins}m";

        return SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: 100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(userName),
              const SizedBox(height: 15),
              _buildLocationCard(currentAddress),
              const SizedBox(height: 20),
              _buildAvailabilityCard(isOnline, uid),
              const SizedBox(height: 25),
              _buildAlertsHeader(context),
              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('sos_requests')
                    .where('status', whereIn: ['searching', 'accepted'])
                    .snapshots(),
                builder: (context, sosSnapshot) {
                  if (!sosSnapshot.hasData || sosSnapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No nearby alerts right now.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  var alerts = sosSnapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;
                    String status = data['status'] ?? '';
                    String helperId = data['helperId'] ?? '';

                    if (status == 'searching') return true;
                    if (status == 'accepted' && helperId == uid) return true;
                    return false;
                  }).toList();

                  if (alerts.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          "No nearby alerts right now.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return _buildAlertCard(context, alerts.first, uid);
                },
              ),

              const SizedBox(height: 25),
              const Text(
                "Your Impact",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  _buildImpactCard(
                    peopleHelped.toString(),
                    "People Helped",
                    Icons.group_outlined,
                  ),
                  const SizedBox(width: 15),
                  _buildImpactCard(
                    activeHours,
                    "Active Hours",
                    Icons.access_time,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationCard(String address) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF1A4D7A).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.location_on, color: Color(0xFF1A4D7A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Location",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4D7A),
                  ),
                ),
                Text(
                  address,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: Colors.green, size: 10),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    DocumentSnapshot sosDoc,
    String currentUid,
  ) {
    var data = sosDoc.data() as Map<String, dynamic>?;
    if (data == null) return const SizedBox.shrink();

    bool isMyAcceptedMission =
        (data['status'] == 'accepted' && data['helperId'] == currentUid);

    double targetLat = 0.0;
    double targetLng = 0.0;
    if (data['location'] != null) {
      targetLat = (data['location']['lat'] ?? 0.0).toDouble();
      targetLng = (data['location']['lng'] ?? 0.0).toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isMyAcceptedMission ? const Color(0xFFF1F8E9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyAcceptedMission
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isMyAcceptedMission
                          ? Icons.verified
                          : Icons.warning_amber_rounded,
                      color: isMyAcceptedMission ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isMyAcceptedMission ? "YOUR MISSION" : "Critical Alert",
                      style: TextStyle(
                        color: isMyAcceptedMission ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  data['emergencyType'] ?? "Assistance Needed",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isMyAcceptedMission ? "Chat is Open" : "Active Request",
                  style: TextStyle(
                    color: isMyAcceptedMission ? Colors.grey : Colors.green,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () async {
                    if (!isMyAcceptedMission) {
                      await _firestore
                          .collection('sos_requests')
                          .doc(sosDoc.id)
                          .update({
                            'status': 'accepted',
                            'helperId': currentUid,
                            'helperName': userName,
                          });
                      await _firestore
                          .collection('helpers')
                          .doc(currentUid)
                          .update({'peopleHelped': FieldValue.increment(1)});
                    }
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatWithHelperScreen(
                          chatId: sosDoc.id,
                          chatWithHelperId: data['userId'] ?? "",
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMyAcceptedMission
                        ? Colors.green
                        : const Color(0xFF5BA3C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isMyAcceptedMission ? "Resume Chat" : "Accept Request",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _openMap(targetLat.toString(), targetLng.toString()),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.map_outlined, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Color(0xFF1A4D7A),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Volunteer",
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
                Text(
                  "Welcome back, $name",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
        const Icon(Icons.notifications_none),
      ],
    );
  }

  Widget _buildAvailabilityCard(bool onlineStatus, String uid) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FD),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                color: onlineStatus ? Colors.green : Colors.grey,
                size: 10,
              ),
              const SizedBox(width: 8),
              const Text(
                "Availability Status",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: onlineStatus,
              activeThumbColor: const Color(0xFF1A4D7A),
              onChanged: (value) async {
                try {
                  if (value == true) {
                    await _firestore.collection('helpers').doc(uid).set({
                      'isOnline': true,
                      'sessionStartTime': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
                    _updateLocationIfOnline();
                  } else {
                    var doc = await _firestore
                        .collection('helpers')
                        .doc(uid)
                        .get();
                    if (doc.exists && doc.data()?['sessionStartTime'] != null) {
                      Timestamp startTime = doc.data()!['sessionStartTime'];
                      int minutesSpent = DateTime.now()
                          .difference(startTime.toDate())
                          .inMinutes;
                      await _firestore.collection('helpers').doc(uid).set({
                        'isOnline': false,
                        'totalActiveMinutes': FieldValue.increment(
                          minutesSpent,
                        ),
                        'sessionStartTime': null,
                      }, SetOptions(merge: true));
                    } else {
                      await _firestore.collection('helpers').doc(uid).set({
                        'isOnline': false,
                      }, SetOptions(merge: true));
                    }
                  }
                } catch (e) {
                  debugPrint("Error switching status: $e");
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Nearby Alerts",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AllNearbyAlertsScreen(),
            ),
          ),
          child: const Text("See all"),
        ),
      ],
    );
  }

  Widget _buildImpactCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F7FD),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1A4D7A)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(icon: Icons.home_filled, index: 0),
            _buildNavItem(icon: Icons.sign_language, index: 1),
            _buildNavItem(icon: Icons.translate, index: 2),
            _buildNavItem(
              icon: Icons
                  .people_alt_outlined, // 👈 تم التعديل هنا لتكون أيقونة أشخاص بجانب بعضهم
              index: 3,
            ),
            _buildNavItem(icon: Icons.person_outline, index: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5BA3C1).withValues(alpha: 0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xFF5BA3C1) : Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text("User not authenticated")),
      );
    }

    final List<Widget> screens = [
      _buildHomeView(uid),
      const QuickSignsScreen(),
      const AiTranslatorScreen(),
      const CommunityScreen(isDarkMode: false),
      const ProfileHelperScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }
}
