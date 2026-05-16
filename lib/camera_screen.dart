/*

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart'; 
import 'Ai/ai_model_service.dart';
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  
  final AiModelService _aiService = AiModelService();
  final HandPreprocessing _preprocessing = HandPreprocessing();
  
  // 👈 الحل للخطأ الأول: استخدام .create()
  final HandLandmarkerPlugin _handLandmarker = HandLandmarkerPlugin.create(); 

  String _translatedText = "في انتظار الإشارة...";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeProject();
  }

  Future<void> _initializeProject() async {
    await _aiService.loadModel(isArabic: true);

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
        _cameraController!.startImageStream((CameraImage image) {
          _processFrame(image);
        });
      }
    } catch (e) {
      print("Camera initialization error: $e");
    }
  }

  // 👈 تعديلات دالة المعالجة هنا
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final result = _handLandmarker.detect(
        image,
        _cameraController!.description.sensorOrientation,
      );

      // 1. اختبار MediaPipe
      if (result.isNotEmpty) {
        print("🖐️ ممتاز! MediaPipe شايف إيدك دلوقتي"); 
        
        final landmarks = result[0].landmarks; 
        bool isRightHand = true; 

        var inputData = _preprocessing.prepareDataForModel(landmarks, isRightHand);
        
        // 2. اختبار الموديل
        String? prediction = await _aiService.predictShape(inputData);

        if (prediction != null && prediction != "غير معروف") {
          setState(() {
            _translatedText = prediction;
          });
        } else {
          print("⚠️ الموديل حلل الحركة بس مش واثق من النتيجة (أقل من 80%)");
        }
      } 
      // تم إزالة else الخاصة بعدم رؤية اليد حتى لا تمتلئ الشاشة بالرسائل
    } catch (e) {
      print("❌ Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quick Sign - مترجم الإشارة"),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Text(
                _translatedText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

*/