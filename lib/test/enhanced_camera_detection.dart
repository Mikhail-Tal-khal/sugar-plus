// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sugar_plus/utils/colors.dart';

class FixedDiabetesDetectionScreen extends StatefulWidget {
  const FixedDiabetesDetectionScreen({super.key});

  @override
  State<FixedDiabetesDetectionScreen> createState() =>
      _FixedDiabetesDetectionScreenState();
}

class _FixedDiabetesDetectionScreenState
    extends State<FixedDiabetesDetectionScreen> with WidgetsBindingObserver {
  // Camera and detection
  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  
  // State variables
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _faceDetected = false;
  bool _eyesDetected = false;
  
  // Camera properties
  double _cameraAspectRatio = 9 / 16;
  bool _isCameraBusy = false;
  
  // Readings storage (like Python lists)
  final List<double> _refractiveIndices = [];
  final List<double> _sugarLevels = [];
  final List<int> _nValues = [];
  double? _currentSugarLevel;
  
  // Status
  String _statusMessage = 'Initializing camera...';
  String _diagnosisMessage = '';
  
  // Processing control
  DateTime? _lastProcessTime;
  static const _processingDelay = Duration(milliseconds: 1000);
  static const _maxReadings = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeFaceDetector();
    _requestPermissionAndInitialize();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<void> _requestPermissionAndInitialize() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initializeCamera();
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    } else {
      setState(() {
        _statusMessage = 'Camera permission denied';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found');
      }

      // Get front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _cameraAspectRatio = _cameraController!.value.aspectRatio;
          _statusMessage = 'Position your face in the frame';
        });
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera error: $e';
        });
      }
    }
  }

  void _startImageStream() {
    _cameraController?.startImageStream((CameraImage image) {
      if (_shouldSkipFrame()) return;
      _processImage(image);
    });
  }

  bool _shouldSkipFrame() {
    if (_isProcessing || _isCameraBusy) return true;
    if (_lastProcessTime != null) {
      final elapsed = DateTime.now().difference(_lastProcessTime!);
      if (elapsed < _processingDelay) return true;
    }
    return false;
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isCameraBusy) return;
    
    _isProcessing = true;
    _isCameraBusy = true;
    _lastProcessTime = DateTime.now();

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        _isCameraBusy = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _faceDetected = false;
          _eyesDetected = false;
          _statusMessage = 'No face detected - move closer';
        });
      } else {
        final face = faces.first;
        final leftEye = face.landmarks[FaceLandmarkType.leftEye];
        final rightEye = face.landmarks[FaceLandmarkType.rightEye];
        final hasEyes = leftEye != null && rightEye != null;

        setState(() {
          _faceDetected = true;
          _eyesDetected = hasEyes;
          
          if (!hasEyes) {
            _statusMessage = 'Face detected - look at camera';
          } else if (_sugarLevels.length < _maxReadings) {
            _statusMessage = 'Analyzing... ${_sugarLevels.length}/$_maxReadings';
            _calculateSugarLevel(face, image.width, image.height);
          } else {
            _statusMessage = 'Analysis complete!';
            _calculateFinalDiagnosis();
          }
        });
      }
    } catch (e) {
      debugPrint('Processing error: $e');
    } finally {
      _isProcessing = false;
      _isCameraBusy = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    try {
      final camera = _cameraController!.description;
      
      // Get proper rotation
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation rotation;
      
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
      }

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Input image error: $e');
      return null;
    }
  }

  void _calculateSugarLevel(Face face, int imageWidth, int imageHeight) {
    if (_sugarLevels.length >= _maxReadings) return;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    
    if (leftEye == null || rightEye == null) return;

    // Get eye center coordinates (similar to Python's cx, cy)
    final eyeCenterX = (leftEye.position.x + rightEye.position.x) / 2;
    final eyeCenterY = (leftEye.position.y + rightEye.position.y) / 2;

    // Calculate angle of incidence (like Python's np.arctan2(cx, cy))
    final angle = math.atan2(eyeCenterX, eyeCenterY);
    debugPrint('ANGLE OF INCIDENCE = $angle');

    // Calculate refractive index using Snell's law (like Python: n = 1 / sin(angle))
    // Add small epsilon to avoid division by zero
    final n = 1 / (math.sin(angle.abs()) + 0.001);
    debugPrint('REFRACTIVE INDEX = $n');

    // Store refractive index
    _refractiveIndices.add(n);

    // Calculate area of triangle using Heron's formula (like Python code)
    final a = 50.0; // fixed side a
    final b = 50.0; // fixed side b
    final c = math.sqrt(a * a + b * b - 2 * a * b * math.cos(angle));
    final s = (a + b + c) / 2;
    final area = math.sqrt(s * (s - a) * (s - b) * (s - c));

    // CONVERSION TO BRIX (like Python: 1 BRIX = 1.33442)
    final brix = (n * 1) / 1.33442;
    debugPrint('BRIX = $brix');

    // Conversion to blood sugar levels (like Python: 1 brix = 100 mm/dL)
    final sugarLevel = (brix * 100).clamp(70.0, 220.0);
    debugPrint('YOUR SUGAR LEVEL IS = $sugarLevel mm/dL');

    // Store values for final calculation
    setState(() {
      _sugarLevels.add(sugarLevel);
      _nValues.add(_sugarLevels.length);
      _currentSugarLevel = sugarLevel;
    });

    // Individual reading diagnosis
    if (sugarLevel < 140) {
      debugPrint("NO DIABETES DETECTED IN THIS READING");
    } else {
      debugPrint("HIGH SUGAR LEVEL DETECTED IN THIS READING");
    }
  }

  void _calculateFinalDiagnosis() {
    if (_sugarLevels.isEmpty) return;

    // Calculate average sugar level from all readings
    final averageSugarLevel = _sugarLevels.reduce((a, b) => a + b) / _sugarLevels.length;
    
    setState(() {
      _currentSugarLevel = averageSugarLevel;
      
      if (averageSugarLevel < 140) {
        _diagnosisMessage = "NO DIABETES DETECTED\nTake a healthy diet, THANK YOU FOR USING THE DIABETIC APP";
      } else {
        _diagnosisMessage = "Your sugar levels are high work on your diet\nHere are the recommended foods for your diet, also take a lot of water";
      }
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera access to scan your eyes. '
          'Please enable camera permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveResults() async {
    if (_currentSugarLevel == null) return;

    try {
      await _cameraController?.stopImageStream();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('Please login to save results');
        return;
      }

      final isNormal = _currentSugarLevel! < 140;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('diabetes_tests')
          .add({
        'sugarLevel': _currentSugarLevel,
        'diagnosis': isNormal ? 'Normal Range' : 'Elevated Level',
        'isNormal': isNormal,
        'timestamp': FieldValue.serverTimestamp(),
        'allReadings': _sugarLevels,
        'readingCount': _sugarLevels.length,
        'refractiveIndices': _refractiveIndices,
        'method': 'eye_scan_analysis',
        'diagnosisMessage': _diagnosisMessage,
      });

      if (mounted) {
        _showMessage('Results saved successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('Error saving: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Diabetic Eye Scan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: _buildCameraPreview(),
        ),

        // Dark overlay
        Container(
          color: Colors.black.withOpacity(0.3),
        ),

        // Face guide
        Center(
          child: Container(
            width: 280,
            height: 350,
            decoration: BoxDecoration(
              border: Border.all(
                color: _getGuideColor(),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),

        // Top status
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: _getGuideColor(),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _getGuideColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_sugarLevels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _sugarLevels.length / _maxReadings,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation(_getGuideColor()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Progress: ${_sugarLevels.length}/$_maxReadings',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Detection indicators
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIndicator('Face', _faceDetected),
              const SizedBox(width: 24),
              _buildIndicator('Eyes', _eyesDetected),
            ],
          ),
        ),

        // Results display
        if (_currentSugarLevel != null) _buildResultsOverlay(),

        // Bottom button
        if (_sugarLevels.length >= 5) _buildSaveButton(),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return AspectRatio(
          aspectRatio: _cameraAspectRatio,
          child: CameraPreview(_cameraController!),
        );
      },
    );
  }

  Widget _buildIndicator(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.success : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.circle_outlined,
            color: active ? AppColors.success : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? AppColors.success : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsOverlay() {
    final isNormal = _currentSugarLevel! < 140;
    
    return Positioned(
      bottom: _diagnosisMessage.isNotEmpty ? 180 : 120,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Sugar level display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isNormal
                  ? AppColors.success.withOpacity(0.9)
                  : Colors.orange.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNormal ? AppColors.success : Colors.orange,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${_currentSugarLevel!.toStringAsFixed(1)} mg/dL',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isNormal ? 'Normal Range' : 'Elevated Level',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on ${_sugarLevels.length} readings',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          // Diagnosis message
          if (_diagnosisMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isNormal ? AppColors.success : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                _diagnosisMessage,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: ElevatedButton(
        onPressed: _saveResults,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Color _getGuideColor() {
    if (_eyesDetected) return AppColors.success;
    if (_faceDetected) return Colors.yellow;
    return Colors.white.withOpacity(0.5);
  }

  IconData _getStatusIcon() {
    if (_eyesDetected) return Icons.check_circle;
    if (_faceDetected) return Icons.face;
    return Icons.search;
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use - Diabetic Eye Scan'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Technology:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Uses eye reflection analysis'),
              Text('• Calculates refractive index'),
              Text('• Converts to blood sugar levels'),
              SizedBox(height: 16),
              Text(
                'Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('1. Position your face in the frame'),
              Text('2. Look directly at the camera'),
              Text('3. Keep your face steady'),
              Text('4. Wait for 10 readings to complete'),
              Text('5. Save results to history'),
              SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}