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
  WebViewController? _webViewController;

  // دالة تحريك العظام عبر حقن كود جافاسكريبت متوافق مع Three.js المدمج في ModelViewer
  void _rotateBone(String boneName, double h, double p, double r) {
    double radH = h * (math.pi / 180);
    double radP = p * (math.pi / 180);
    double radR = r * (math.pi / 180);

    final String jsCode =
        '''
      (function() {
        const mv = document.querySelector('#avatar-viewer');
        if (mv && mv.model) {
          const sceneSymbol = Object.getOwnPropertySymbols(mv.model).find(s => s.description === 'scene');
          const scene = sceneSymbol ? mv.model[sceneSymbol] : (mv.model.scenes ? mv.model.scenes[0] : null);
          
          if (scene) {
            let foundBone = null;
            scene.traverse((obj) => {
              if (obj.isBone && obj.name === "$boneName") {
                foundBone = obj;
              }
            });

            if (foundBone) {
              foundBone.rotation.set($radP, $radH, $radR);
              foundBone.updateMatrixWorld(true);
              mv.queueRender(); 
            }
          }
        }
      })();
    ''';

    if (_webViewController != null) {
      _webViewController!.runJavaScript(jsCode).catchError((err) {
        debugPrint("JS Execution Error: \$err");
      });
    }
  }

  // استدعاء الـ API الجديد باستخدام طلب POST وإرسال الكلمة في الـ Body
  Future<void> _processTranslation() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isAnimating = true);
    final String word = _textController.text.trim().toLowerCase();

    try {
      // تم التعديل هنا إلى http.post لتجنب خطأ Method Not Allowed
      final response = await http.post(
        Uri.parse('https://ismailabdulsalam-avater-api.hf.space/translate'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'word': word}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data.containsKey('frames') && data['frames'] is List) {
          List frames = data['frames'];

          for (var frame in frames) {
            if (frame is Map) {
              frame.forEach((boneName, angles) {
                if (angles is Map) {
                  _rotateBone(
                    boneName.toString(),
                    (angles['h'] ?? 0).toDouble(),
                    (angles['p'] ?? 0).toDouble(),
                    (angles['r'] ?? 0).toDouble(),
                  );
                }
              });
            }
            // فرق زمني لضمان سلاسة حركة الـ 3D Avatar
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      } else {
        _showError("عذراً، الـ API لا يستجيب حالياً");
        debugPrint("Server Error Code: ${response.statusCode}");
        debugPrint("Server Response: ${response.body}");
      }
    } catch (e) {
      _showError("تأكد من اتصالك بالإنترنت");
      debugPrint("Translation pipeline error: \$e");
    } finally {
      if (mounted) setState(() => _isAnimating = false);
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
        elevation: 0,
      ),
      body: Column(
        children: [
          // منطقة عرض الأفاتار ثلاثي الأبعاد
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: ModelViewer(
                  id: "avatar-viewer",
                  src: 'assets/pro.glb',
                  alt: "AI Sign Language Avatar",
                  autoRotate: false,
                  cameraControls: true,
                  backgroundColor: Colors.white,
                  onWebViewCreated: (Object controller) {
                    if (controller is WebViewController) {
                      _webViewController = controller;
                    }
                  },
                ),
              ),
            ),
          ),

          // لوحة التحكم السفلية ومدخلات النص
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
                    hintText: "Enter a word (e.g., hello, a, b, z)",
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
