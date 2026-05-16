import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 استدعاء مكتبة الذاكرة
import 'package:projectgrad/role_selection_screen.dart'; // تأكد إن المسار ده صح عندك

// 💡 الكود ده لو بتشغل الشاشة لوحدها للتجربة، لو عندك main.dart تاني امسح الجزء ده
// void main() => runApp(
//   const MaterialApp(
//     home: OnboardingScreen(),
//     debugShowCheckedModeBanner: false,
//   ),
// );

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // قائمة البيانات باستخدام أسماء الصور من مشروعك
  final List<Map<String, String>> _pages = [
    {
      "image": "assets/image2.png", 
      "title": "Emergency\nSupport for All", 
      "desc":
          "Fast assistance and clear communication\nfor people with disabilities when every\nsecond matters.", 
    },
    {
      "image": "assets/image1.png", 
      "title": "You’re Not\nAlone", 
      "desc":
          "Connecting people with disabilities to\nimmediate help during emergencies.", 
    },
    {
      "image": "assets/image3.png", 
      "title": "Help, When It\nMatters Most", 
      "desc":
          "Smart emergency response designed for\naccessibility and safety.", 
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // صورة اللوجو ثابتة في كل الصفحات
            Image.asset('assets/logo2.png', height: 45),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return buildPageContent(
                    image: _pages[index]["image"]!,
                    title: _pages[index]["title"]!,
                    description: _pages[index]["desc"]!,
                    // الدائرة تظهر خلف أول صورتين فقط
                    showCircle: index == 1,
                  );
                },
              ),
            ), 
            // التحكم السفلي (المؤشر والزرار)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 5),
                        height: 4,
                        width: _currentPage == index ? 20 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF5499BC)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    // ✨ التعديل هنا: خلينا الزرار async وضفنا حفظ الذاكرة
                    onPressed: () async {
                      if (_currentPage < _pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        // ✨ حفظنا إنه شاف الاونبوردينج في الذاكرة
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('seenOnboard', true);

                        if (!context.mounted) return;

                        // ✨ استخدمنا pushReplacement عشان ميعرفش يرجع للشاشة دي تاني
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5499BC),
                      minimumSize: const Size(180, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // 💡 حركة UX بسيطة: غيرنا الكلمة لـ GET STARTED في آخر صفحة بدل NEXT
                          _currentPage == _pages.length - 1 ? "GET STARTED" : "NEXT", 
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
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

  Widget buildPageContent({
    required String image,
    required String title,
    required String description,
    bool showCircle = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (showCircle)
              Image.asset('assets/image.png', width: 300), 
            Image.asset(image, width: 260),
          ],
        ),
        const SizedBox(height: 40),
        // عرض النصوص رأسياً أسفل بعضها
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3142),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}