import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class AiTranslatorScreen extends StatefulWidget {
  const AiTranslatorScreen({super.key});

  @override
  State<AiTranslatorScreen> createState() => _AiTranslatorScreenState();
}

class _AiTranslatorScreenState extends State<AiTranslatorScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isAnimating = false;

  // 🎯 تعريف الـ Controller الأساسي لحقن الجافا سكريبت
  WebViewController? _webViewController;
  final String viewerId = "avatar-viewer";

  // 🦴 دالة تدوير العظام عبر الـ WebViewController المدمج
  void _rotateBoneDirect(String boneName, double h, double p, double r) {
    if (_webViewController == null) {
      debugPrint("⚠️ تنبيه: الـ WebViewController لسه مجهزش!");
      return;
    }

    double radH = h * (math.pi / 180); // Yaw
    double radP = p * (math.pi / 180); // Pitch
    double radR = r * (math.pi / 180); // Roll

    // سكريبت مباشر يضمن الوصول لـ Three.js الداخلي داخل المحرك
    final String jsCode =
        '''
      (function() {
        try {
          const viewer = document.getElementById('$viewerId');
          if (!viewer) return;
          
          const model = viewer.model;
          if (!model) return;

          // البحث عن العظمة جوه الـ Scene Graph
          const bone = model.getElementBySceneGraphName('$boneName');
          if (bone) {
            bone.rotation.set($radP, $radH, $radR);
            viewer.queueRender(); 
          } else {
            // لو الاسم فيه اختلاف بسيط (مثلاً البريفكس) بيحاول يطابق بالنهاية
            const symbols = Object.getOwnPropertySymbols(model);
            const sceneSymbol = symbols.find(s => s.description === 'scene');
            const scene = sceneSymbol ? model[sceneSymbol] : (model.scenes ? model.scenes[0] : null);
            
            if (scene) {
              scene.traverse((obj) => {
                if (obj.isBone && (obj.name === "$boneName" || obj.name.endsWith("$boneName"))) {
                  obj.rotation.set($radP, $radH, $radR);
                  obj.updateMatrixWorld(true);
                  viewer.queueRender();
                }
              });
            }
          }
        } catch (err) {
          console.error(err);
        }
      })();
    ''';

    // حقن السكريبت بشكل صريح ومباشر في المتصفح الداخلي
    _webViewController!.runJavaScript(jsCode).catchError((err) {
      debugPrint("🚨 خطأ أثناء حقن الـ JS: \$err");
    });
  }

  // 📡 دالة استدعاء الـ API وقراءة البيانات المفرودة
  Future<void> _processTranslation() async {
    final String textToSend = _textController.text.trim();
    if (textToSend.isEmpty) return;

    setState(() => _isAnimating = true);
    debugPrint("🚀 جاري إرسال الطلب لترجمة: \$textToSend");

    try {
      final response = await http
          .post(
            Uri.parse('https://ismailabdulsalam-avater-api.hf.space/translate'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'text': textToSend}),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint("📡 كود رد السيرفر: \${response.statusCode}");

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);
        debugPrint("📦 الداتا المستلمة: \$decodedData");

        if (decodedData is Map<String, dynamic>) {
          debugPrint("✅ تم فك الداتا بنجاح، جاري تحريك العظام...");

          // الالتفاف حول الماب المفرودة مباشرة وتمريرها للدالة
          decodedData.forEach((boneName, angles) {
            if (angles is Map<String, dynamic>) {
              double h = (angles['h'] ?? 0).toDouble();
              double p = (angles['p'] ?? 0).toDouble();
              double r = (angles['r'] ?? 0).toDouble();

              _rotateBoneDirect(boneName, h, p, r);
            }
          });
        }

        await Future.delayed(const Duration(milliseconds: 1000));
      } else {
        _showError("السيرفر رد بخطأ: \${response.statusCode}");
      }
    } catch (e) {
      _showError("حدث خطأ في الاتصال بالإنترنت");
      debugPrint("🚨 الإيرور هو: \$e");
    } finally {
      if (mounted) {
        setState(() => _isAnimating = false);
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          "MAAK - AI Avatar",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: ModelViewer(
                  id: viewerId,
                  src: 'assets/pro.glb',
                  alt: "AI Sign Language Avatar",
                  autoRotate: false,
                  cameraControls: true,
                  backgroundColor: Colors.white,
                  // 🎯 هنا بنربط الـ Controller وبنخليه Unrestricted عشان الجافا سكريبت تشتغل
                  onWebViewCreated: (Object controller) {
                    if (controller is WebViewController) {
                      _webViewController = controller;
                      _webViewController!.setJavaScriptMode(
                        JavaScriptMode.unrestricted,
                      );
                      debugPrint(
                        "🌐 تم تهيئة الـ WebViewController بنجاح تام!",
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: "Enter a word (e.g., hello)",
                    filled: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: const Icon(Icons.keyboard, color: Colors.teal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isAnimating ? null : _processTranslation,
                    icon: _isAnimating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.run_circle_outlined, size: 28),
                    label: Text(
                      _isAnimating ? "جاري التحريك..." : "ابدأ الإشارة",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
