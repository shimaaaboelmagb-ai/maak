import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class QuickSignsScreen extends StatefulWidget {
  const QuickSignsScreen({super.key});

  @override
  State<QuickSignsScreen> createState() => _QuickSignsScreenState();
}

class _QuickSignsScreenState extends State<QuickSignsScreen> {
  final FlutterTts flutterTts = FlutterTts();
  String selectedTab = "All Actions";
  String searchQuery = "";

  // القائمة الشاملة لجميع العناصر بناءً على المجلدات في الصور
  final List<Map<String, String>> signs = [
    // --- قسم الأرقام (Numbers) ---
    {"title": "One", "subtitle": "Numbers", "path": "assets/Numbers/1.png"},
    {"title": "Two", "subtitle": "Numbers", "path": "assets/Numbers/2.png"},
    {"title": "Three", "subtitle": "Numbers", "path": "assets/Numbers/3.png"},
    {"title": "Four", "subtitle": "Numbers", "path": "assets/Numbers/4.png"},
    {"title": "Five", "subtitle": "Numbers", "path": "assets/Numbers/5.png"},
    {"title": "Six", "subtitle": "Numbers", "path": "assets/Numbers/6.png"},
    {"title": "Seven", "subtitle": "Numbers", "path": "assets/Numbers/7.png"},
    {"title": "Eight", "subtitle": "Numbers", "path": "assets/Numbers/8.png"},
    {"title": "Nine", "subtitle": "Numbers", "path": "assets/Numbers/9.png"},
    {"title": "Ten", "subtitle": "Numbers", "path": "assets/Numbers/10.png"},

    // --- قسم الطوارئ (Emergency) ---
    {
      "title": "Call Ambulance",
      "subtitle": "Emergency",
      "path": "assets/Emergency/call ambulance.png",
    },
    {
      "title": "Danger",
      "subtitle": "Emergency",
      "path": "assets/Emergency/danger.png",
    },
    {
      "title": "Help",
      "subtitle": "Emergency",
      "path": "assets/Emergency/help.gif",
    },
    {
      "title": "Police",
      "subtitle": "Emergency",
      "path": "assets/Emergency/police.png",
    },

    // --- قسم الاحتياجات اليومية (Daily signals) ---
    {
      "title": "Good Morning",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/good-morning.gif",
    },
    {
      "title": "Good Night",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/good-night.gif",
    },
    {
      "title": "Hello",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/hello.gif",
    },
    {
      "title": "Hungry",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/hungry.gif",
    },
    {
      "title": "Ok",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/ok.gif",
    },
    {
      "title": "Please",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/please.gif",
    },
    {
      "title": "Sorry",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/sorry.gif",
    },
    {
      "title": "Thank You",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/thank.gif",
    },
    {
      "title": "Thirsty",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/thirsty.gif",
    },
    {
      "title": "Friday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Friday.png",
    },
    {
      "title": "Monday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Monday.png",
    },
    {
      "title": "Saturday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Saturday.png",
    },
    {
      "title": "Sunday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Sunday.png",
    },
    {
      "title": "Thursday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Thursday.png",
    },
    {
      "title": "Tuesday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Tuesday.png",
    },
    {
      "title": "Wednesday",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Rectangle 39.png",
    },
    {
      "title": "Peace Be Upon You",
      "subtitle": "Daily signals",
      "path": "assets/Daily signals/Peace Be Upon You.png",
    },
  ];

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Emergency":
        return Colors.redAccent;
      case "Daily signals":
        return Colors.green.shade600;
      case "Numbers":
        return Colors.purple.shade600;
      default:
        return const Color(0xFF1A4D7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSigns = signs.where((sign) {
      final matchesTab =
          selectedTab == "All Actions" || sign["subtitle"] == selectedTab;
      final matchesSearch = sign["title"]!.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      return matchesTab && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Quick Signs",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                decoration: const InputDecoration(
                  hintText: "Search signs...",
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Tabs (All Actions, Emergency, Daily signals, Numbers)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                "All Actions",
                "Emergency",
                "Daily signals",
                "Numbers",
              ].map((label) => _buildTab(label)).toList(),
            ),
          ),

          // Grid Display
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.8,
              ),
              itemCount: filteredSigns.length,
              itemBuilder: (context, index) =>
                  _buildSignCard(filteredSigns[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label) {
    bool isSelected = selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = label),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _getCategoryColor(label) : Colors.white,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSignCard(Map<String, String> sign) {
    Color themeColor = _getCategoryColor(sign["subtitle"]!);
    return GestureDetector(
      onTap: () {
        flutterTts.speak(sign["title"]!); // نطق الصوت
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SignDetailScreen(sign: sign, color: themeColor),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Hero(
                  tag: sign["path"]!,
                  child: Image.asset(sign["path"]!, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    sign["title"]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      sign["subtitle"]!,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignDetailScreen extends StatelessWidget {
  final Map<String, String> sign;
  final Color color;
  const SignDetailScreen({super.key, required this.sign, required this.color});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: color),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 300,
              child: Hero(
                tag: sign["path"]!,
                child: Image.asset(sign["path"]!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              sign["title"]!,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              sign["subtitle"]!,
              style: TextStyle(
                fontSize: 18,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              onPressed: () => FlutterTts().speak(sign["title"]!),
              icon: const Icon(Icons.volume_up, size: 28),
              label: const Text(
                "Listen",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
