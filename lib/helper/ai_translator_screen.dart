import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // عشان نقرأ الملف من الـ assets
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
  bool _isAvatarLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWebViewWithAvatar();
  }

  // 🌐 دالة تقرأ ملف الـ GLB وتحوله لـ Base64 عشان يتشحن جوه الـ HTML فوراً
  Future<void> _loadWebViewWithAvatar() async {
    try {
      // 1. قراءة ملف الـ glb من الـ assets وتحويله لـ bytes
      ByteData bytesData = await rootBundle.load('assets/pro.glb');
      Uint8List avatarBytes = bytesData.buffer.asUint8List();

      // 2. تحويل البايتس لـ صيغة Base64 عشان الـ WebView يقدر يقراها كـ نص
      String base64Avatar = base64Encode(avatarBytes);
      String dataUrl = "data:model/gltf-binary;base64,$base64Avatar";

      // 3. بناء الـ WebViewController وتشريب كود الـ HTML الأفاتار جواه
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFAFAFA))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (String url) {
              setState(() {
                _isAvatarLoaded = true;
              });
              debugPrint("🌐 تم تحميل مشهد الأفاتار ثلاثي الأبعاد بنجاح تـام!");
            },
          ),
        )
        ..loadHtmlString(_getHtmlContent(dataUrl)); // باصينا الموديل مشحون جاهز
    } catch (e) {
      debugPrint("🚨 خطأ في تحميل ملف الـ GLB من الـ Assets: $e");
    }
  }

  // 📡 دالة الـ API والـ Loop لإرسال الكلمة للأفاتار
  Future<void> _processTranslation() async {
    final String textToSend = _textController.text.trim();
    if (textToSend.isEmpty) return;
    if (_webViewController == null || !_isAvatarLoaded) {
      _showError("برجاء الانتظار حتى يتم تحميل الأفاتار بالكامل");
      return;
    }

    setState(() => _isAnimating = true);
    debugPrint("🚀 جاري إرسال طلب الترجمة للكلمة: $textToSend");

    try {
      final response = await http
          .post(
            Uri.parse('https://ismailabdulsalam-avater-api.hf.space/translate'),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'text': textToSend}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);

        List<dynamic> frames = [];
        if (decodedData is Map<String, dynamic>) {
          if (decodedData['data'] != null &&
              decodedData['data'] is List &&
              decodedData['data'].isNotEmpty) {
            frames = decodedData['data'][0]['frames'] ?? [];
          } else if (decodedData['frames'] != null) {
            frames = decodedData['frames'] ?? [];
          }
        }

        if (frames.isEmpty) {
          _showError("لم يتم العثور على إطارات حركة.");
          return;
        }

        debugPrint(
          "🎬 تم استلام ${frames.length} إطار حركي. جاري تشغيل الأنيميشن لايف...",
        );

        // تحويل الفريمات لـ String آمن وإرسالها للجافا سكريبت دفعة واحدة
        String jsonFrames = jsonEncode(frames);
        await _webViewController!.runJavaScript(
          "startAvatarAnimation($jsonFrames);",
        );

        // انتظام وقت الأنيميشن المتوقع بناء على عدد الفريمات
        await Future.delayed(Duration(milliseconds: frames.length * 45));
      } else {
        _showError("السيرفر رد بخطأ: ${response.statusCode}");
      }
    } catch (e) {
      _showError("حدث خطأ في الاتصال أو التحليل");
      debugPrint("🚨 الإيرور: $e");
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: _webViewController != null
                    ? WebViewWidget(controller: _webViewController!)
                    : const Center(child: CircularProgressIndicator()),
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

  // 📜 دالة الـ HTML اللي بتستقبل الموديل كـ Base64 وتشغله فوراً بدون قيود حماية المتصفح
  String _getHtmlContent(String base64ModelUrl) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: #fafafa; }
        #canvas3d { width: 100%; height: 100%; }
      </style>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js"></script>
    </head>
    <body>
      <div id="canvas3d"></div>
      <script>
        function getCoreBoneName(fullName) {
          if (!fullName) return "";
          let clean = fullName.replace(/\\s+/g, '').toLowerCase();
          if (clean.includes(':')) { clean = clean.split(':').pop(); }
          return clean.replace(/^mixamorig\\d*/, '').replace(/^mixamorig/, '');
        }

        const container = document.getElementById('canvas3d');
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0xfafafa);

        const camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 100);
        camera.position.set(0, 1.4, 2.0); 

        const renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(renderer.domElement);

        scene.add(new THREE.AmbientLight(0xffffff, 0.9));
        const dirLight = new THREE.DirectionalLight(0xffffff, 0.6);
        dirLight.position.set(5, 10, 7);
        scene.add(dirLight);

        let avatarModel = null;
        const bonesMap = new Map(); 

        const loader = new THREE.GLTFLoader();
        
        // 🔥 تحميل الموديل الممرر مباشرة كـ Base64 Data URL لتخطي مشاكل الحماية
        loader.load('$base64ModelUrl', (gltf) => {
            avatarModel = gltf.scene;
            scene.add(avatarModel);
            avatarModel.traverse((child) => {
                if (child.isBone) {
                    const coreName = getCoreBoneName(child.name);
                    if (coreName) bonesMap.set(coreName, child);
                }
            });
        }, undefined, (err) => {
            console.error("Error rendering model: " + err);
        });

        function animate() {
            requestAnimationFrame(animate);
            renderer.render(scene, camera);
        }
        animate();

        const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

        // 🦴 دالة التحريك السحرية المستقرة
        async function startAvatarAnimation(frames) {
            if (!avatarModel || !frames) return;
            
            for (let i = 0; i < frames.length; i++) {
                const currentFramePose = frames[i].pose || {}; 

                for (const [boneName, angles] of Object.entries(currentFramePose)) {
                    const coreServerBoneName = getCoreBoneName(boneName);
                    const bone = bonesMap.get(coreServerBoneName);
                    
                    if (bone) {
                        const radH = (angles.h || 0) * (Math.PI / 180); 
                        const radP = (angles.p || 0) * (Math.PI / 180); 
                        const radR = (angles.r || 0) * (Math.PI / 180); 
                        
                        bone.quaternion.setFromEuler(new THREE.Euler(radP, radH, radR, 'YXZ'));
                    }
                }
                avatarModel.updateMatrixWorld(true);
                await sleep(45);
            }
        }
      </script>
    </body>
    </html>
    ''';
  }
}
