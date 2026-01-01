import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';
import 'utils.dart';

/// State provider for available cameras
final camerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

/// Main view for pose detection with live camera feed
class PoseDetectorView extends ConsumerStatefulWidget {
  const PoseDetectorView({super.key});

  @override
  ConsumerState<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends ConsumerState<PoseDetectorView> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  List<Pose> _poses = [];
  int _currentCameraIndex = 0;
  List<CameraDescription> _cameras = [];
  String _debugMessage = '';
  String? _errorMessage;
  bool _showCalibration = false;
  double _calibrationOffsetX = 0.0;
  double _calibrationOffsetY = -82.0;
  double _calibrationScale = 0.91;

  @override
  void initState() {
    super.initState();
    _initializePoseDetector();
  }

  /// Initialize the ML Kit Pose Detector
  /// Using ACCURATE mode for better precision (can switch to STREAM for FPS)
  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream, // Use stream mode for real-time performance
      model: PoseDetectionModel.accurate, // Accurate model for better detection
    );
    _poseDetector = PoseDetector(options: options);
  }

  /// Initialize camera with the given index
  Future<void> _initializeCamera(int cameraIndex) async {
    if (_cameras.isEmpty) return;

    // Dispose previous controller if exists
    await _cameraController?.dispose();

    final camera = _cameras[cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Efficient format for ML processing
    );

    try {
      await _cameraController!.initialize();
      
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _currentCameraIndex = cameraIndex;
      });

      // Start image stream for real-time processing
      _cameraController!.startImageStream(_processImage);
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  /// Process each camera frame for pose detection
  Future<void> _processImage(CameraImage image) async {
    // Skip if already processing to avoid frame backlog
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to convert camera image';
          });
        }
        _isProcessing = false;
        return;
      }

      // Run pose detection
      final poses = await _poseDetector!.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _poses = poses;
          _debugMessage = 'Processing: ${poses.length} pose(s) detected';
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('Error processing image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Detection error: $e';
        });
      }
    }

    _isProcessing = false;
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertToInputImage(CameraImage image) {
    final rotation = rotationIntToImageRotation(
      getRotation(_cameraController!),
    );

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      print('Unsupported image format: ${image.format.raw}');
      return null;
    }

    // For Android, we need to handle NV21 format properly
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  /// Flip between front and back camera
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    final newIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initializeCamera(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(camerasProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AI Gym Coach - Vision Layer'),
        backgroundColor: Colors.black87,
        actions: [
          // Calibration button
          IconButton(
            icon: Icon(
              _showCalibration ? Icons.tune : Icons.tune_outlined,
              color: _showCalibration ? Colors.green : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showCalibration = !_showCalibration;
              });
            },
            tooltip: 'Calibrate Skeleton',
          ),
          // Camera flip button
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _isCameraInitialized ? _flipCamera : null,
            tooltip: 'Flip Camera',
          ),
        ],
      ),
      body: camerasAsync.when(
        data: (cameras) {
          if (_cameras.isEmpty) {
            _cameras = cameras;
            // Initialize with back camera (index 0 is usually back)
            _initializeCamera(0);
          }

          if (!_isCameraInitialized || _cameraController == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          return _buildCameraView();
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'Camera Error: $error',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the camera view with pose overlay
  Widget _buildCameraView() {
    final size = MediaQuery.of(context).size;
    final cameraController = _cameraController!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(cameraController),

        // Pose overlay
        if (_poses.isNotEmpty)
          CustomPaint(
            painter: PosePainter(
              poses: _poses,
              translator: CoordinateTranslator(
                imageSize: getImageSize(cameraController),
                screenSize: size,
                rotation: rotationIntToImageRotation(
                  getRotation(cameraController),
                ),
                cameraLensDirection: cameraController.description.lensDirection,
                calibrationOffsetX: _calibrationOffsetX,
                calibrationOffsetY: _calibrationOffsetY,
                calibrationScale: _calibrationScale,
              ),
            ),
          ),

        // Calibration controls
        if (_showCalibration)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calibration Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Horizontal Offset: ${_calibrationOffsetX.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _calibrationOffsetX,
                    min: -100,
                    max: 100,
                    divisions: 200,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _calibrationOffsetX = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vertical Offset: ${_calibrationOffsetY.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _calibrationOffsetY,
                    min: -100,
                    max: 100,
                    divisions: 200,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _calibrationOffsetY = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scale: ${_calibrationScale.toStringAsFixed(2)}x',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Slider(
                    value: _calibrationScale,
                    min: 0.5,
                    max: 1.5,
                    divisions: 100,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setState(() {
                        _calibrationScale = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _calibrationOffsetX = 0;
                            _calibrationOffsetY = -82.0;
                            _calibrationScale = 0.91;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showCalibration = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // FPS and detection info overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Poses Detected: ${_poses.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_poses.isNotEmpty)
                  Text(
                    'Landmarks: ${_poses.first.landmarks.length}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                    ),
                  ),
                if (_debugMessage.isNotEmpty)
                  Text(
                    _debugMessage,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                    ),
                  ),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }
}
