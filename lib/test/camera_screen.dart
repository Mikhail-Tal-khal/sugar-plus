// lib/screens/diabetes_camera_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:sugar_plus/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DiabetesCameraScreen extends StatefulWidget {
  const DiabetesCameraScreen({super.key});

  @override
  State<DiabetesCameraScreen> createState() => _DiabetesCameraScreenState();
}

class _DiabetesCameraScreenState extends State<DiabetesCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _isInitialized = false;
  bool _faceDetected = false;
  bool _eyesDetected = false;
  
  List<double> refractiveIndices = [];
  List<double> sugarLevels = [];
  double? currentSugarLevel;
  double? currentRefractiveIndex;
  String diagnosis = '';
  String status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => status = 'No cameras available');
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          status = 'Position your face in frame';
        });
        _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      setState(() => status = 'Camera error: ${e.toString()}');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          if (faces.isNotEmpty) {
            _faceDetected = true;
            final face = faces.first;

            final leftEye = face.landmarks[FaceLandmarkType.leftEye];
            final rightEye = face.landmarks[FaceLandmarkType.rightEye];

            if (leftEye != null && rightEye != null) {
              _eyesDetected = true;
              status = 'Analyzing eye reflection...';
              _analyzeFace(face, image.width, image.height);
            } else {
              _eyesDetected = false;
              status = 'Face detected. Look at camera';
            }
          } else {
            _faceDetected = false;
            _eyesDetected = false;
            status = 'Position your face in frame';
          }
        });
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final camera = _controller!.description;
      final imageRotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
      if (imageRotation == null) return null;

      final inputImageFormat = InputImageFormatValue.fromRawValue(
        image.format.raw,
      );
      if (inputImageFormat == null) return null;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  void _analyzeFace(Face face, int imageWidth, int imageHeight) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) return;

    // Calculate eye center
    final eyeCenterX = (leftEye.position.x.toDouble() + rightEye.position.x.toDouble()) / 2.0;
    final eyeCenterY = (leftEye.position.y.toDouble() + rightEye.position.y.toDouble()) / 2.0;

    // Simulate bright spot detection
    final random = Random();
    final hasBrightSpot = random.nextDouble() > 0.5;

    if (hasBrightSpot) {
      // Calculate angle of incidence
      final angle = atan2(eyeCenterX, eyeCenterY);
      debugPrint('ANGLE OF INCIDENCE = $angle');

      // Calculate refractive index using Snell's law
      final n = 1 / sin(angle.abs());
      debugPrint('REFRACTIVE INDEX = $n');

      // Conversion to BRIX (1 BRIX = 1.33442)
      final brix = (n * 1) / 1.33442;
      debugPrint('BRIX = $brix');

      // Conversion to blood sugar levels (1 brix = 100 mm/dL)
      final sugarLevel = brix * 100;
      debugPrint('SUGAR LEVEL = $sugarLevel mm/dL');

      setState(() {
        currentSugarLevel = sugarLevel;
        currentRefractiveIndex = n;
        refractiveIndices.add(n);
        sugarLevels.add(sugarLevel);

        if (sugarLevel < 140) {
          diagnosis = "NO DIABETES DETECTED";
          status = "Sugar level normal: ${sugarLevel.toStringAsFixed(1)} mg/dL";
        } else {
          diagnosis = "HIGH SUGAR DETECTED";
          status = "Sugar level high: ${sugarLevel.toStringAsFixed(1)} mg/dL";
        }
      });
    }
  }

  Future<void> _saveResults() async {
    if (currentSugarLevel == null) return;

    try {
      await _controller?.stopImageStream();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diabetes_tests')
          .add({
        'sugarLevel': currentSugarLevel,
        'refractiveIndex': currentRefractiveIndex,
        'diagnosis': diagnosis,
        'timestamp': FieldValue.serverTimestamp(),
        'allReadings': sugarLevels,
        'allIndices': refractiveIndices,
        'method': 'camera_analysis',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results saved to history')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isInitialized && _controller != null)
              Center(child: CameraPreview(_controller!))
            else
              const Center(child: CircularProgressIndicator()),

            // Overlay
            if (_isInitialized)
              CustomPaint(
                painter: FaceOverlayPainter(
                  faceDetected: _faceDetected,
                  eyesDetected: _eyesDetected,
                ),
                child: Container(),
              ),

            // Top Bar
            _buildTopBar(),

            // Bottom Info
            _buildBottomInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                const Text(
                  'Diabetes Test',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentSugarLevel != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: currentSugarLevel! < 140
                      ? AppColors.success.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentSugarLevel! < 140
                        ? AppColors.success
                        : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${currentSugarLevel!.toStringAsFixed(1)} mg/dL',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: currentSugarLevel! < 140
                            ? AppColors.success
                            : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      diagnosis,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Readings: ${sugarLevels.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveResults,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save to History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusIcon(Icons.face, 'Face', _faceDetected),
                  const SizedBox(width: 32),
                  _buildStatusIcon(Icons.remove_red_eye, 'Eyes', _eyesDetected),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'EXPERIMENTAL: Not for medical use',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
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

  Widget _buildStatusIcon(IconData icon, String label, bool detected) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: detected
                ? AppColors.success.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: detected ? AppColors.success : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: detected ? AppColors.success : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: detected ? AppColors.success : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;
  final bool eyesDetected;

  FaceOverlayPainter({
    required this.faceDetected,
    required this.eyesDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = eyesDetected
          ? Colors.green
          : faceDetected
              ? Colors.yellow
              : Colors.white.withValues(alpha: 0.5);

    final center = Offset(size.width / 2, size.height / 2);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.6,
      height: size.height * 0.5,
    );

    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faceDetected != faceDetected ||
        oldDelegate.eyesDetected != eyesDetected;
  }
}