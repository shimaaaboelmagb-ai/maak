import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiTranslatorScreen extends StatefulWidget {
  const AiTranslatorScreen({super.key});

  @override
  State<AiTranslatorScreen> createState() => _AiTranslatorScreenState();
}

class _AiTranslatorScreenState extends State<AiTranslatorScreen> {
  static const Color appPrimaryColor = Color(0xFF4E9BB6);
  static const Color appBackgroundColor = Color(0xFFF3F7F9);
  static const Color appSoftBlue = Color(0xFFD6E6ED);

  final TextEditingController _textController = TextEditingController();
  late final WebViewController _webViewController;
  bool _isLoading = false;
  String _statusText = '';

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isArabic = true;

  static const String _apiUrl =
      'https://ismailabdulsalam-avater-api.hf.space/translate';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(appBackgroundColor)
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

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (val) => debugPrint('Speech Error: $val'),
        onStatus: (val) => debugPrint('Speech Status: $val'),
      );
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _statusText = _isArabic ? 'جاري الاستماع...' : 'Listening...';
        });
        _speech.listen(
          localeId: _isArabic ? 'ar-EG' : 'en-US',
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
            if (val.finalResult) {
              setState(() {
                _isListening = false;
              });
              _translate();
            }
          },
        );
      } else {
        _showError(
          _isArabic
              ? "خاصية التعرف على الصوت غير متاحة"
              : "Speech recognition not available",
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
    }
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

      // 🔍 محاولة تقريب الكاميرا تلقائياً للموديل عند التحميل
      // يمكنك تعديل الرقم 2.5 (تقليله يقرب أكثر، زيادته يبعد الأفاتار)
      await _webViewController
          .runJavaScript(
            'if(window.camera) { window.camera.position.z = 2.5; if(window.controls) window.controls.update(); }',
          )
          .catchError((_) {});
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
              '📷 إعادة الكاميرا للأمام والتقريب',
              'if(window.camera) { window.camera.position.set(0, 1.2, 2.5); if(window.controls) window.controls.update(); }',
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
      style: OutlinedButton.styleFrom(foregroundColor: appPrimaryColor),
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

  Future<void> _translate() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _statusText = _isArabic
          ? 'جاري الاتصال بالسيرفر...'
          : 'Connecting to server...';
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

        if (json is Map<String, dynamic> && json['frames'] is List) {
          final List<Map<String, dynamic>> allFrames = [];
          double timeOffset = 0.0;
          final rawFrames = json['frames'] as List;

          for (int i = 0; i < rawFrames.length; i++) {
            final frame = rawFrames[i];
            if (frame is! Map<String, dynamic>) continue;

            final Map<String, List<double>> bones = {};

            frame.forEach((name, angles) {
              if (angles is Map<String, dynamic>) {
                final double h =
                    ((angles['h'] ?? 0) as num).toDouble() * (math.pi / 180);
                final double p =
                    ((angles['p'] ?? 0) as num).toDouble() * (math.pi / 180);
                final double r =
                    ((angles['r'] ?? 0) as num).toDouble() * (math.pi / 180);

                bones[name.replaceAll(':', '')] = [p, h, r];
              }
            });

            allFrames.add({'time': timeOffset + (i * 0.02), 'bones': bones});
          }

          if (allFrames.isNotEmpty) {
            setState(
              () =>
                  _statusText = _isArabic ? 'جاري التحريك...' : 'Animating...',
            );
            await _playAnimation(allFrames);
            setState(() => _statusText = _isArabic ? 'تم ✓' : 'Done ✓');
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _statusText = '');
          }
        } else {
          _showError(
            _isArabic ? "تنسيق بيانات غير متوقع" : "Unexpected data format",
          );
          debugPrint('[API] Unexpected format: ${json.runtimeType}');
        }
      } else {
        _showError(
          "${_isArabic ? 'خطأ من السيرفر' : 'Server Error'}: ${response.statusCode}",
        );
      }
    } on TimeoutException {
      _showError(
        _isArabic ? "انتهى الوقت — جرب مرة تانية" : "Timeout — try again",
      );
    } catch (e) {
      _showError(_isArabic ? "خطأ في الاتصال" : "Connection error");
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
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'MAAK - AI Avatar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: appPrimaryColor,
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
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: appSoftBlue, width: 1.5),
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
          Container(
            padding: const EdgeInsets.fromLTRB(25, 16, 25, 28),
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
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: appSoftBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isArabic ? 'العربية' : 'English',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appPrimaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 30,
                          child: Switch(
                            value: _isArabic,
                            activeColor: appPrimaryColor,
                            onChanged: (v) => setState(() => _isArabic = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _textController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: _isArabic
                        ? 'اكتب كلمة أو اضغط على المايك'
                        : 'Type a word or press mic',
                    filled: true,
                    fillColor: appBackgroundColor,
                    prefixIcon: const Icon(
                      Icons.keyboard,
                      color: appPrimaryColor,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : appPrimaryColor,
                      ),
                      onPressed: _listen,
                    ),
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
                      color: _isListening ? Colors.red[700] : appPrimaryColor,
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
                      _isLoading
                          ? (_isArabic ? 'جاري المعالجة...' : 'Processing...')
                          : (_isArabic ? 'ابدأ الإشارة' : 'Start Signing'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appPrimaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: appSoftBlue,
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
