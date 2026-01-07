import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'pose_painter.dart';
import 'utils.dart';
import 'services/pose_analysis_service.dart';
import 'rep_detector.dart';
import 'biomechanics/joint_angle_calculator.dart';
import 'biomechanics/angle_smoother.dart';
import 'biomechanics/exercise_spec.dart';
import 'biomechanics/form_anomaly_detector.dart';
import 'dart:async';

/// State provider for available cameras
final camerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

/// Main view for pose detection with live camera feed
class PoseDetectorView extends ConsumerStatefulWidget {
  final String? selectedExercise;

  const PoseDetectorView({super.key, this.selectedExercise});

  @override
  ConsumerState<PoseDetectorView> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends ConsumerState<PoseDetectorView> {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  RepetitionDetector? _repetitionDetector;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  List<Pose> _poses = [];
  int _currentCameraIndex = 0;
  List<CameraDescription> _cameras = [];
  String _debugMessage = '';
  String? _errorMessage;
  bool _showCalibration = false;
  String? _selectedExercise; // Exercise being performed
  bool _isAnalyzing = false;
  Map<String, dynamic>? _lastAnalysis;
  bool _enableRealTimeFeedback = false;
  double _calibrationOffsetX = 0.0;
  double _calibrationOffsetY = -82.0;
  double _calibrationScale = 0.91;
  RepState _currentRepState = RepState.idle;
  int _captureCount = 0;

  // Biomechanics layer
  AngleSmoother? _angleSmoother;
  FormAnomalyDetector? _formAnomalyDetector;
  StreamSubscription<FormIssue>? _formIssueSubscription;
  List<FormIssue> _currentFormIssues = [];
  Map<String, double> _currentAngles = {};
  Map<String, dynamic>? _aiCoaching; // Gemini coaching response

  @override
  void initState() {
    super.initState();
    _initializePoseDetector();
    _repetitionDetector = RepetitionDetector();
    _selectedExercise = widget.selectedExercise ?? 'squat';
    _initializeBiomechanicsLayer();
  }

  /// Initialize biomechanics analysis layer
  void _initializeBiomechanicsLayer() {
    _angleSmoother = AngleSmoother(bufferSize: 5, alpha: 0.3);
    
    final exerciseSpec = ExerciseSpecs.getSpec(_selectedExercise ?? 'squat');
    if (exerciseSpec != null) {
      _formAnomalyDetector = FormAnomalyDetector(exerciseSpec);
      
      // Listen to form issues
      _formIssueSubscription = _formAnomalyDetector!.issues.listen((issue) {
        if (mounted) {
          setState(() {
            _currentFormIssues.add(issue);
            // Keep only last 5 issues
            if (_currentFormIssues.length > 5) {
              _currentFormIssues.removeAt(0);
            }
          });
          
          // Call Gemini when critical or warning issues detected
          if (issue.severity == FormIssueSeverity.critical ||
              issue.severity == FormIssueSeverity.warning) {
            _analyzeFormIssue(issue);
          }
        }
      });
    }
  }

  /// Initialize the ML Kit Pose Detector
  /// Using ACCURATE mode for better precision (can switch to STREAM for FPS)
  void _initializePoseDetector() {
    final options = PoseDetectorOptions(
      mode:
          PoseDetectionMode.stream, // Use stream mode for real-time performance
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

    // Use platform-specific image format
    // Android works best with NV21, iOS with BGRA8888
    final imageFormat = Platform.isAndroid
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: imageFormat,
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
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera initialization failed: $e';
        });
      }
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

      // Process with biomechanics layer
      if (poses.isNotEmpty) {
        final pose = poses.first;
        
        // 1. Calculate joint angles
        final rawAngles = JointAngleCalculator.computeAllAngles(pose);
        
        // 2. Smooth angles to reduce noise
        final validAngles = <String, double>{};
        rawAngles.forEach((key, value) {
          if (value != null) {
            validAngles[key] = value;
          }
        });
        
        if (_angleSmoother != null && validAngles.isNotEmpty) {
          _currentAngles = _angleSmoother!.smoothAngles(validAngles);
          
          // 3. Detect form anomalies
          if (_formAnomalyDetector != null) {
            _formAnomalyDetector!.analyze(_currentAngles);
          }
        }
      }

      // Process with RepetitionDetector if pose detected
      if (poses.isNotEmpty && _repetitionDetector != null) {
        final detectionResult = _repetitionDetector!.processFrame(poses.first);

        // Check if we should capture at bottom of squat
        if (detectionResult['shouldCapture'] == true) {
          captureSnapshot(poses.first, inputImage);
        }

        // Update UI with detection state
        if (mounted) {
          setState(() {
            _poses = poses;
            _currentRepState = detectionResult['currentState'];
            final message = detectionResult['message'] ?? '';
            _debugMessage =
                'State: ${_currentRepState.name} | Captures: $_captureCount | $message';
            _errorMessage = detectionResult['error'];
          });
        }
      } else if (mounted) {
        setState(() {
          _poses = poses;
          _debugMessage = 'Processing: ${poses.length} pose(s) detected';
          _errorMessage = null;
        });

        // Send poses for real-time feedback if enabled
        if (_enableRealTimeFeedback &&
            poses.isNotEmpty &&
            _selectedExercise != null) {
          _getRealTimeFeedback(poses);
        }
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

  /// Capture snapshot at the bottom of the squat
  /// This function is called when the RepetitionDetector identifies the inflection point
  ///
  /// In Phase 3, this is where you'll:
  /// 1. Convert the image to a format suitable for Gemini API
  /// 2. Extract relevant pose data
  /// 3. Send to backend for AI analysis
  void captureSnapshot(Pose pose, InputImage image) {
    _captureCount++;

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📸 SNAPSHOT CAPTURED AT BOTTOM OF SQUAT #$_captureCount');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print(
      'Image: ${image.metadata?.size.width}x${image.metadata?.size.height}',
    );
    print('Pose landmarks: ${pose.landmarks.length}');

    // Extract key landmarks for analysis
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftKnee != null &&
        rightKnee != null &&
        leftHip != null &&
        rightHip != null) {
      print(
        'Hip position: L(${leftHip.x.toInt()}, ${leftHip.y.toInt()}) R(${rightHip.x.toInt()}, ${rightHip.y.toInt()})',
      );
      print(
        'Knee position: L(${leftKnee.x.toInt()}, ${leftKnee.y.toInt()}) R(${rightKnee.x.toInt()}, ${rightKnee.y.toInt()})',
      );
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');

    // TODO Phase 3: Replace this with actual API call to Gemini
    // Example:
    // final imageBytes = await convertInputImageToBytes(image);
    // final analysis = await sendToGeminiAPI(imageBytes, pose);
    // showAnalysisResults(analysis);
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertToInputImage(CameraImage image) {
    try {
      final rotation = rotationIntToImageRotation(
        getRotation(_cameraController!),
      );

      final format = InputImageFormatValue.fromRawValue(image.format.raw);

      if (format == null) {
        print('Error: Unsupported image format raw value: ${image.format.raw}');
        print('Image format group: ${image.format.group}');
        return null;
      }

      // Validate that format is supported by ML Kit
      if (format != InputImageFormat.nv21 &&
          format != InputImageFormat.yuv420 &&
          format != InputImageFormat.bgra8888) {
        print('Error: Format $format not supported by ML Kit');
        print('Supported formats: nv21, yuv420, bgra8888');
        return null;
      }

      // Build the complete image bytes from planes
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.isNotEmpty
            ? image.planes[0].bytesPerRow
            : image.width,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  /// Flip between front and back camera
  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;

    final newIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initializeCamera(newIndex);
  }

  /// Get real-time feedback from backend
  Future<void> _getRealTimeFeedback(List<Pose> poses) async {
    if (_selectedExercise == null) return;

    try {
      final result = await PoseAnalysisService.getRealTimeFeedback(
        poses,
        exerciseName: _selectedExercise!,
      );

      if (result['success'] == true && mounted) {
        final feedback = result['feedback'] ?? {};
        setState(() {
          _debugMessage =
              feedback['immediate_action'] ?? 'Analysis in progress...';
        });
      }
    } catch (e) {
      print('Error getting real-time feedback: $e');
    }
  }

  /// Send poses for detailed analysis (button action)
  Future<void> _analyzePoses() async {
    if (_poses.isEmpty) {
      setState(() {
        _errorMessage =
            'No poses detected. Please position yourself in front of the camera.';
      });
      return;
    }

    if (_selectedExercise == null) {
      setState(() {
        _errorMessage = 'Please select an exercise first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Send computed angles instead of raw landmarks
      final result = await PoseAnalysisService.analyzeWithAngles(
        angles: _currentAngles,
        formIssues: _currentFormIssues,
        exerciseName: _selectedExercise!,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          if (result['success'] == true) {
            _lastAnalysis = result['analysis'];
            _errorMessage = null;
          } else {
            _errorMessage = result['error'] ?? 'Analysis failed';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  /// Analyze a detected form issue with Gemini
  Future<void> _analyzeFormIssue(FormIssue issue) async {
    if (_poses.isEmpty || _selectedExercise == null) return;

    try {
      // Call Gemini for coaching
      final response = await PoseAnalysisService.analyzeFormIssue(
        issue: issue,
        angles: _currentAngles,
        exerciseName: _selectedExercise!,
      );
      
      // Store coaching response
      if (mounted && response['success'] == true) {
        setState(() {
          _aiCoaching = response['coaching'];
        });
        
        // Clear coaching after 8 seconds
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) {
            setState(() {
              _aiCoaching = null;
            });
          }
        });
      }
    } catch (e) {
      print('Error analyzing form issue: $e');
    }
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
          // Real-time feedback toggle
          IconButton(
            icon: Icon(
              _enableRealTimeFeedback
                  ? Icons.feedback
                  : Icons.feedback_outlined,
              color: _enableRealTimeFeedback ? Colors.green : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _enableRealTimeFeedback = !_enableRealTimeFeedback;
              });
            },
            tooltip: 'Real-time Feedback',
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
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.green)),
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
                if (_currentAngles.isNotEmpty)
                  Text(
                    'Knee: ${_currentAngles['leftKnee']?.toInt()}° | Hip: ${_currentAngles['leftHip']?.toInt()}°',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12,
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

        // Form issues overlay
        if (_currentFormIssues.isNotEmpty)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Form Issues Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._currentFormIssues.take(3).map((issue) {
                    final color = issue.severity == FormIssueSeverity.critical
                        ? Colors.red
                        : issue.severity == FormIssueSeverity.warning
                            ? Colors.orange
                            : Colors.yellow;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: color, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              issue.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

        // AI Coaching overlay (from Gemini)
        if (_aiCoaching != null)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade900.withOpacity(0.95),
                    Colors.purple.shade900.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'AI Coach Says:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_aiCoaching!['quick_fix'] != null) ...[
                    const Text(
                      '💡 Quick Fix:',
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiCoaching!['quick_fix'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_aiCoaching!['cue'] != null) ...[
                    const Text(
                      '🎯 Remember:',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _aiCoaching!['cue'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Exercise selection and analysis panel
        Positioned(
          top: 80,
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
                const Text(
                  'Exercise:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedExercise,
                    dropdownColor: Colors.black87,
                    style: const TextStyle(color: Colors.white),
                    items:
                        [
                              'squat',
                              'push-up',
                              'deadlift',
                              'bench press',
                              'pull-up',
                              'running',
                              'other',
                            ]
                            .map(
                              (exercise) => DropdownMenuItem(
                                value: exercise,
                                child: Text(exercise),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedExercise = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzePoses,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.analytics),
                  label: const Text('Analyze'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Analysis results panel
        if (_lastAnalysis != null)
          Positioned(
            top: 80,
            left: 16,
            right: 100,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Analysis Results',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Form Score: ${_lastAnalysis!['form_score'] ?? "N/A"}/10',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (_lastAnalysis!['issues'] != null &&
                        (_lastAnalysis!['issues'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Issues:',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...((_lastAnalysis!['issues'] as List)
                                    .cast<String>())
                                .map(
                                  (issue) => Text(
                                    '• $issue',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    if (_lastAnalysis!['corrections'] != null &&
                        (_lastAnalysis!['corrections'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Corrections:',
                              style: TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...((_lastAnalysis!['corrections'] as List)
                                    .cast<String>())
                                .map(
                                  (correction) => Text(
                                    '• $correction',
                                    style: const TextStyle(
                                      color: Colors.yellowAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _lastAnalysis = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
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
    _formIssueSubscription?.cancel();
    _formAnomalyDetector?.dispose();
    super.dispose();
  }
}
