import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'medical_id_screen.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'fcm_config.dart'; // تأكد إن الملف ده موجود وفيه بيانات الـ JSON
import 'helper_tracking_screen.dart'; // ✨ استدعاء شاشة التتبع الجديدة
import 'helper/quick_signs_screen.dart'; // ✨ استدعاء شاشة الإشارات السريعة الخاصة بكِ

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // 🌙 متغير الدارك مود
  bool _isDarkMode = false;

  Timer? _sosTimer;
  int _countdown = 3;
  bool _isPressed = false;

  // بيانات جهات الاتصال
  List<Map<String, dynamic>> _emergencyContacts = [];
  int _activeContactIndex = 0;

  String _currentLocationText = "searching your location...";
  String _userName = "User";

  // ✨ متغيرات تتبع المساعد
  bool isHelperOnTheWay = false;
  String acceptedHelperId = "";
  double _patientLat = 0.0;
  double _patientLng = 0.0;
  String _currentRequestId = "";

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _loadEmergencyContacts();
    _fetchCurrentLocation();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // ==========================================
  // جزء جهات الاتصال (Contacts) - لم يتغير
  // ==========================================
  Future<void> _loadEmergencyContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contactsJson = prefs.getString('emergency_contacts_list');
    if (contactsJson != null) {
      setState(() {
        _emergencyContacts = List<Map<String, dynamic>>.from(
          jsonDecode(contactsJson),
        );
        _activeContactIndex = prefs.getInt('active_contact_index') ?? 0;
      });
    }
  }

  Future<void> _saveContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'emergency_contacts_list',
      jsonEncode(_emergencyContacts),
    );
    await prefs.setInt('active_contact_index', _activeContactIndex);
  }

  void _showContactsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: Text(
                  "HOLD TO REMOVE NUMBER",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.grey : Colors.grey,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _emergencyContacts.isEmpty
                    ? const Center(
                        child: Text(
                          "No contacts added yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        itemCount: _emergencyContacts.length,
                        itemBuilder: (context, index) {
                          bool isActive = _activeContactIndex == index;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(
                                      0xFF4A98B4,
                                    ).withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isActive
                                    ? const Color(0xFF4A98B4)
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  color: isActive ? Colors.white : Colors.grey,
                                ),
                              ),
                              title: Text(
                                _emergencyContacts[index]['name'],
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                _emergencyContacts[index]['phone'],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              trailing: isActive
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF4A98B4),
                                    )
                                  : const Icon(
                                      Icons.circle_outlined,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                              onTap: () {
                                setState(() => _activeContactIndex = index);
                                setModalState(() {});
                                _saveContacts();
                                Navigator.pop(context);
                              },
                              onLongPress: () {
                                setModalState(() {
                                  _emergencyContacts.removeAt(index);
                                  if (_activeContactIndex >=
                                      _emergencyContacts.length)
                                    _activeContactIndex = 0;
                                });
                                _saveContacts();
                              },
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A98B4),
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                  label: const Text(
                    "ADD NEW CONTACT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  onPressed: () => _addNewContactDialog(setModalState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewContactDialog(Function setModalState) {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Add Contact",
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: const InputDecoration(
                labelText: "Name (e.g. Brother)",
              ),
            ),
            TextField(
              controller: phoneController,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone (e.g. 2010...)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                setState(() {
                  _emergencyContacts.add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                  });
                });
                setModalState(() {});
                _saveContacts();
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // بيانات المستخدم والموقع - لم يتغير
  // ==========================================
  Future<void> _fetchUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          if (mounted)
            setState(
              () =>
                  _userName = (userDoc.get('fullName') as String).split(' ')[0],
            );
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      _patientLat = position.latitude;
      _patientLng = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (mounted)
        setState(
          () => _currentLocationText =
              "${placemarks.first.street}, ${placemarks.first.locality}",
        );
    } catch (e) {
      if (mounted) setState(() => _currentLocationText = "Location unknown");
    }
  }

  // ==========================================
  // نظام الـ SOS والتصعيد (Escalation System) - لم يتغير
  // ==========================================
  void _startCountdown() {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add an emergency contact first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isPressed = true;
      _countdown = 3;
    });
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 1) {
            _countdown--;
          } else {
            _sosTimer?.cancel();
            _isPressed = false;
            _countdown = 3;
            _sendSOSRequest();
          }
        });
      }
    });
  }

  void _cancelCountdown() {
    _sosTimer?.cancel();
    if (mounted)
      setState(() {
        _isPressed = false;
        _countdown = 3;
      });
  }

  Future<void> _sendSOSRequest() async {
    if (_emergencyContacts.isEmpty) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    DocumentReference docRef = await FirebaseFirestore.instance
        .collection('sos_requests')
        .add({
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'userName': _userName,
          'status': 'active',
          'location': {'lat': position.latitude, 'lng': position.longitude},
          'createdAt': FieldValue.serverTimestamp(),
          'isSafe': false,
        });

    String requestId = docRef.id;
    _currentRequestId = requestId;

    String activePhone = _emergencyContacts[_activeContactIndex]['phone'];

    String maakWebLink = "https://saadp-88043.web.app/?id=$requestId";
    String googleMapsLink =
        "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

    String script =
        "🚨 EMERGENCY SOS! 🚨\n\n"
        "I am $_userName and I need your help immediately.\n\n"
        "📍 My Location:\n$googleMapsLink\n"
        "✅ If you are coming to help, PLEASE PRESS HERE:\n$maakWebLink\n"
        "(If you don't respond in 1 minute, help will be requested from nearby app volunteers).";

    String url =
        "https://wa.me/$activePhone?text=${Uri.encodeComponent(script)}";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    _startEscalationTimer(requestId, position);
    _listenToWebResponse(requestId);
  }

  void _startEscalationTimer(String requestId, Position patientPos) {
    _sosTimer?.cancel();
    _sosTimer = Timer(const Duration(minutes: 1), () async {
      var doc = await FirebaseFirestore.instance
          .collection('sos_requests')
          .doc(requestId)
          .get();

      if (doc.exists && doc.data()?['status'] == 'active') {
        debugPrint(
          "⚠️ No response from family. Escalating to nearby helpers...",
        );

        await FirebaseFirestore.instance
            .collection('sos_requests')
            .doc(requestId)
            .update({'status': 'searching'});

        await _findAndNotifyNearbyHelpers(patientPos, requestId);
      }
    });
  }

  Future<void> _findAndNotifyNearbyHelpers(
    Position patientPos,
    String requestId,
  ) async {
    try {
      var helpersSnapshot = await FirebaseFirestore.instance
          .collection('helpers')
          .where('isOnline', isEqualTo: true)
          .get();

      int notifiedCount = 0;

      for (var helperDoc in helpersSnapshot.docs) {
        var helperData = helperDoc.data();

        if (helperData['location'] != null && helperData['fcmToken'] != null) {
          double helperLat = helperData['location']['lat'];
          double helperLng = helperData['location']['lng'];

          double distance = Geolocator.distanceBetween(
            patientPos.latitude,
            patientPos.longitude,
            helperLat,
            helperLng,
          );

          if (distance <= 5000) {
            await _sendFCMToSpecificHelper(helperData['fcmToken'], requestId);
            notifiedCount++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Family didn't respond. Notified $notifiedCount nearby helpers.",
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('🚨 Error in Escalation: $e');
    }
  }

  Future<void> _sendFCMToSpecificHelper(
    String targetToken,
    String requestId,
  ) async {
    try {
      final client = await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(
          FirebaseServiceAccount.credentials,
        ),
        ['https://www.googleapis.com/auth/firebase.messaging'],
      );

      final String url =
          'https://fcm.googleapis.com/v1/projects/${FirebaseServiceAccount.credentials['project_id']}/messages:send';

      final notificationData = {
        'message': {
          'token': targetToken,
          'notification': {
            'title': '🚨 EMERGENCY: Helper Needed!',
            'body':
                'A Disable near you needs help. Their family hasn\'t responded!',
          },
          'data': {
            'type': 'sos_alert',
            'requestId': requestId,
            'lat': _currentLocationText,
          },
        },
      };

      await client.post(Uri.parse(url), body: jsonEncode(notificationData));
      client.close();
    } catch (e) {
      debugPrint('🚨 FCM Error: $e');
    }
  }

  void _listenToWebResponse(String requestId) {
    FirebaseFirestore.instance
        .collection('sos_requests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            var data = snapshot.data();
            String status = data?['status'] ?? '';

            if (status == 'resolved' || status == 'arrived') {
              _sosTimer?.cancel();
              if (mounted) {
                setState(() {
                  isHelperOnTheWay = false;
                  acceptedHelperId = "";
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      status == 'arrived'
                          ? "Helper has arrived! Stay safe."
                          : "Family responded!",
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else if (status == 'accepted') {
              _sosTimer?.cancel();
              if (mounted && !isHelperOnTheWay) {
                String helperName = data?['helperName'] ?? '❤️';

                setState(() {
                  isHelperOnTheWay = true;
                  acceptedHelperId = data?['helperId'] ?? "";
                });

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 30),
                        SizedBox(width: 10),
                        Text(
                          "Help is Coming!",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    content: Text(
                      "$helperName has accepted your request and is on the way to help you.",
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5BA3C1),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "OK",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  // ==========================================
  // تصميم واجهة المستخدم (UI) - تم ربط كارت الـ Quick Signs برقم الـ Index الجديد
  // ==========================================
  Widget _buildHomeContent() {
    final bgColor = _isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFF4F9FD);
    final cardColor = _isDarkMode
        ? const Color.fromARGB(255, 27, 27, 27)
        : Colors.white;
    final primaryTextColor = _isDarkMode ? Colors.white : Colors.black87;

    return Container(
      color: bgColor,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF4A98B4),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Current Location",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _currentLocationText,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const CircleAvatar(
                            radius: 5,
                            backgroundColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.orangeAccent
                            : const Color(0xFF4A98B4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isDarkMode
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              Text(
                "Good Morning, $_userName.",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),

              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "System Operational. You are in a Safe Zone.",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.grey : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Center(
                child: Column(
                  children: [
                    Text(
                      "Request Help",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Press and hold for 3 seconds",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: GestureDetector(
                        onTapDown: (_) => _startCountdown(),
                        onTapUp: (_) => _cancelCountdown(),
                        onTapCancel: () => _cancelCountdown(),
                        child: Container(
                          height: 230,
                          width: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.1),
                              width: 10,
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isPressed
                                    ? [Colors.red.shade900, Colors.redAccent]
                                    : [
                                        const Color(0xFFFF4B4B),
                                        const Color(0xFFFF8E8E),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isPressed)
                                  Text(
                                    "$_countdown",
                                    style: const TextStyle(
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                else ...[
                                  const Text(
                                    "SOS",
                                    style: TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const Text(
                                    "HOLD TO HELP",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Emergency contacts will be notified automatically with your live location.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isDarkMode
                              ? Colors.grey
                              : const Color(0xFF7C8B99),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),
              Text(
                "Quick Access",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 15),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  bool isEmergency = index == 0;
                  bool hasContacts = _emergencyContacts.isNotEmpty;
                  bool isHelperCard = index == 4;
                  bool isHelperActive = isHelperCard && isHelperOnTheWay;

                  var item = [
                    {
                      'icon': Icons.contact_emergency,
                      'title': 'Emergency Contacts',
                      'subtitle': _emergencyContacts.isEmpty
                          ? 'Add contacts'
                          : 'Active: ${_emergencyContacts[_activeContactIndex]['name']}',
                      'color': Colors.redAccent,
                    },
                    {
                      'icon': Icons.translate,
                      'title': 'AI Translator',
                      'subtitle': 'Ai model',
                      'color': _isDarkMode ? Colors.white70 : Colors.black87,
                    },
                    {
                      'icon': Icons.sign_language,
                      'title': 'Sign Language',
                      'subtitle': 'Dictionary',
                      'color': Colors.orange,
                    },
                    {
                      'icon': Icons.medical_services,
                      'title': 'Medical ',
                      'subtitle': 'Health info',
                      'color': Colors.blue,
                    },
                    {
                      'icon': isHelperActive
                          ? Icons.accessible_forward
                          : Icons.support_agent,
                      'title': 'Helper',
                      'subtitle': isHelperActive ? 'On the way!' : 'Assistant',
                      'color': isHelperActive ? Colors.green : Colors.teal,
                    },
                  ][index];

                  return GestureDetector(
                    onTap: () {
                      if (index == 0) {
                        _showContactsSheet();
                      } else if (index == 2) {
                        // ✨ التعديل هنا: عند الضغط على الكارت هينقلك للـ Index رقم 1 المخصص لشاشتك تحت
                        setState(() => _selectedIndex = 1);
                      } else if (index == 3) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MedicalIDScreen(),
                          ),
                        );
                      } else if (index == 4 &&
                          isHelperActive &&
                          acceptedHelperId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HelperTrackingScreen(
                              helperId: acceptedHelperId,
                              requestId: _currentRequestId,
                              patientLat: _patientLat,
                              patientLng: _patientLng,
                            ),
                          ),
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isHelperActive
                            ? (_isDarkMode
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : const Color(0xFFE8F5E9))
                            : ((isEmergency && hasContacts)
                                  ? (_isDarkMode
                                        ? const Color.fromARGB(66, 69, 202, 255)
                                        : const Color(0xFFE3F2FD))
                                  : cardColor),
                        borderRadius: BorderRadius.circular(20),
                        border: isHelperActive
                            ? Border.all(color: Colors.green, width: 2)
                            : ((isEmergency && hasContacts)
                                  ? Border.all(
                                      color: const Color.fromARGB(
                                        255,
                                        35,
                                        244,
                                        255,
                                      ).withValues(alpha: 0.3),
                                      width: 2,
                                    )
                                  : null),
                        boxShadow: [
                          BoxShadow(
                            color: isHelperActive
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (item['color'] as Color).withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: item['color'] as Color,
                                  size: 26,
                                ),
                              ),
                              if (isEmergency && hasContacts)
                                const Icon(
                                  Icons.check_box_rounded,
                                  color: Color.fromARGB(255, 0, 187, 255),
                                  size: 18,
                                ),
                              if (isHelperActive)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isHelperActive
                                  ? (_isDarkMode
                                        ? Colors.greenAccent
                                        : Colors.green[800])
                                  : primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              item['subtitle'] as String,
                              key: ValueKey(item['subtitle']),
                              style: TextStyle(
                                color: isHelperActive
                                    ? Colors.green
                                    : ((isEmergency && hasContacts)
                                          ? const Color.fromARGB(
                                              255,
                                              86,
                                              210,
                                              255,
                                            )
                                          : Colors.grey.shade500),
                                fontSize: 11,
                                fontWeight:
                                    (isEmergency && hasContacts) ||
                                        isHelperActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // الـ Build الأساسي - تم دمج شاشتك هنا بـ index 1 وإضافة الأيقونة تحت في النص متناسقة تماماً
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // ✨ الـ screens متطابقة مع الأزرار والـ Indexes تحت بالترتيب لضمان عدم حدوث أي لغبطة
    final List<Widget> screens = [
      _buildHomeContent(), // index 0
      const QuickSignsScreen(), // index 1 👈 شاشتك ضفناها هنا بشكل كامل
      CommunityScreen(isDarkMode: _isDarkMode), // index 2
      ProfileScreen(isDarkMode: _isDarkMode), // index 3
    ];

    return Scaffold(
      backgroundColor: _isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF4F9FD),
      extendBody: true,
      body: screens[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
          height: 65,
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(icon: Icons.home_filled, index: 0),
              _buildNavItem(
                icon: Icons.sign_language,
                index: 1,
              ), // ✨ أيقونة لغة الإشارة المضافة في النص بالظبط زي الصورة لتفتح شاشتك
              _buildNavItem(icon: Icons.people_alt, index: 2),
              _buildNavItem(
                icon: Icons.person_outline,
                index: 3,
              ), // الـ Index بقى متطابق مع اللستة فوق
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A98B4).withValues(alpha: 0.12)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 28,
          color: isSelected ? const Color(0xFF4A98B4) : Colors.grey.shade400,
        ),
      ),
    );
  }
}
