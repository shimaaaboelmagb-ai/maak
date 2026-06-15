import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class AiTranslatorScreen extends StatefulWidget {
  const AiTranslatorScreen({super.key});

  @override
  State<AiTranslatorScreen> createState() => _AiTranslatorScreenState();
}

class _AiTranslatorScreenState extends State<AiTranslatorScreen> {
  final TextEditingController _textController = TextEditingController();
  late final WebViewController _webViewController;
  bool _isLoading = false;
  String _statusText = '';

  // رابط الـ API الخاص بك على Hugging Face Spaces
  static const String _apiUrl =
      'https://ismailabdulsalam-avater-api.hf.space/translate';

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8F9FA))
      ..addJavaScriptChannel(
        'FlutterDebug',
        onMessageReceived: (msg) => _showDebugDialog(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            debugPrint('[WebView] page ready — sending model...');
            _sendModelToWebView();
          },
          onWebResourceError: (e) =>
              debugPrint('[WebView] resource error: ${e.description}'),
        ),
      );
    _loadViewerHtml();
  }

  Future<void> _loadViewerHtml() async {
    final String html = await rootBundle.loadString('assets/viewer.html');
    await _webViewController.loadHtmlString(html);
  }

  Future<void> _sendModelToWebView() async {
    try {
      final data = await rootBundle.load('assets/pro.glb');
      final String b64 = base64Encode(data.buffer.asUint8List());
      debugPrint('[GLB] ${data.lengthInBytes ~/ 1024} KB — sending to JS...');
      await _webViewController.runJavaScript(
        'window.loadModelFromBase64("$b64")',
      );
    } catch (e) {
      debugPrint('[error] _sendModelToWebView: $e');
    }
  }

  void _showDebugDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Debug Result', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _runDebug(String jsCall) =>
      _webViewController.runJavaScript(jsCall).catchError((_) {});

  void _showDebugPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🔍 اختبر أنهي mapping صح',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'جرب كل واحد وشوف أنهي بيرفع الذراع لفوق صح لـ hello',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _debugBtn(
              'E — -p,-h,r  (عكس pitch + heading)',
              "window.testHelloMapping('-p,-h,r')",
            ),
            _debugBtn(
              'F — p,-h,r  (عكس heading بس)',
              "window.testHelloMapping('p,-h,r')",
            ),
            _debugBtn(
              'G — -p,-h,-r  (عكس كل حاجة)',
              "window.testHelloMapping('-p,-h,-r')",
            ),
            _debugBtn(
              'A — p,h,r  (الأصلي للمقارنة)',
              "window.testHelloMapping('p,h,r')",
            ),
            const Divider(),
            _debugBtn(
              '📷 إعادة الكاميرا للأمام',
              'window.resetCamera && window.resetCamera()',
            ),
            _debugBtn('↩ إعادة وضع الجسم الأصلي', 'window.resetPose()'),
          ],
        ),
      ),
    );
  }

  Widget _debugBtn(String label, String js) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      onPressed: () {
        Navigator.pop(context);
        _runDebug(js);
      },
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.left,
      ),
    ),
  );

  Future<void> _playAnimation(List<Map<String, dynamic>> frames) async {
    if (frames.isEmpty) return;

    final String framesJson = jsonEncode(frames);
    final double totalSec = (frames.last['time'] as double) + 0.3;

    await _webViewController
        .runJavaScript('window.playAnimation(${jsonEncode(framesJson)})')
        .catchError((e) => debugPrint('[JS] playAnimation error: $e'));

    await Future.delayed(
      Duration(milliseconds: (totalSec * 1000).round() + 100),
    );
  }

  // 🎯 الدالة المحدثة كلياً لتتوافق مع الـ API الجديد وتمنع خطأ الـ Format
  Future<void> _translate() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusText = 'جاري الاتصال بالسيرفر...';
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('[API] ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic json = jsonDecode(response.body);

        // هنا بنقرأ مصفوفة الـ frames مباشرة من السيرفر الجديد
        if (json is Map<String, dynamic> && json['frames'] is List) {
          final List<Map<String, dynamic>> allFrames = [];
          double timeOffset = 0.0;
          final rawFrames = json['frames'] as List;

          for (int i = 0; i < rawFrames.length; i++) {
            final frame = rawFrames[i];
            if (frame is! Map<String, dynamic>) continue;

            final Map<String, List<double>> bones = {};

            // نلف على الـ Bones مباشرة لأن العظام أصبحت في الـ Root بتاع الـ frame
            frame.forEach((name, angles) {
              if (angles is Map<String, dynamic>) {
                final double h =
                    ((angles['h'] ?? 0) as num).toDouble() * (math.pi / 180);
                final double p =
                    ((angles['p'] ?? 0) as num).toDouble() * (math.pi / 180);
                final double r =
                    ((angles['r'] ?? 0) as num).toDouble() * (math.pi / 180);

                // تنظيف الـ Key من النقطتين (:) لتتوافق مع الـ Three.js في الـ WebView
                bones[name.replaceAll(':', '')] = [p, h, r];
              }
            });

            // حساب التوقيت الزمني لكل فريم تلقائياً (50 فريم في الثانية = 0.02 ثانية لكل فريم)
            allFrames.add({'time': timeOffset + (i * 0.02), 'bones': bones});
          }

          if (allFrames.isNotEmpty) {
            setState(() => _statusText = 'جاري التحريك...');
            await _playAnimation(allFrames);
            setState(() => _statusText = 'تم ✓');
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _statusText = '');
          }
        } else {
          _showError("تنسيق بيانات غير متوقع");
          debugPrint('[API] Unexpected format: ${json.runtimeType}');
        }
      } else {
        _showError("خطأ من السيرفر: ${response.statusCode}");
      }
    } on TimeoutException {
      _showError("انتهى الوقت — جرب مرة تانية");
    } catch (e) {
      _showError("خطأ في الاتصال");
      debugPrint('[error] $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _statusText = '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
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
          'MAAK - AI Avatar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'إعادة الوضع الأصلي',
            onPressed: () =>
                _runDebug('window.resetPose && window.resetPose()'),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white70),
            tooltip: 'تشخيص الحركة',
            onPressed: _showDebugPanel,
          ),
        ],
      ),
      body: Column(
        children: [
          // 3D viewer
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: WebViewWidget(controller: _webViewController),
              ),
            ),
          ),
          // Input panel
          Container(
            padding: const EdgeInsets.fromLTRB(25, 24, 25, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _textController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'اكتب كلمة مثال: hello',
                    filled: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: const Icon(Icons.keyboard, color: Colors.teal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_isLoading) _translate();
                  },
                ),
                if (_statusText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.teal[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _translate,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.sign_language, size: 26),
                    label: Text(
                      _isLoading ? 'جاري المعالجة...' : 'ابدأ الإشارة',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.teal[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
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
