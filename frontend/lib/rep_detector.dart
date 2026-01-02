import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:collection';

/// Enum representing the current state of the user's movement
enum RepState {
  idle, // User is standing still or moving erratically
  descending, // Hip Y is increasing (going down in screen coordinates)
  ascending, // Hip Y is decreasing (going up in screen coordinates)
}

/// Smart Trigger system for detecting the bottom of a squat
///
/// This detector uses:
/// - Moving average smoothing to reduce noise
/// - State machine to track descending/ascending motion
/// - Noise threshold to filter out small movements
/// - Debouncing to prevent multiple captures per rep
class RepetitionDetector {
  // Moving average buffer size (frames)
  static const int _bufferSize = 5;

  // Minimum descent threshold as percentage of body height
  static const double _minDescentThreshold = 0.15; // 15%

  // Debounce duration in milliseconds
  static const int _debounceDurationMs = 2000; // 2 seconds

  // State tracking
  RepState _currentState = RepState.idle;

  // Moving average buffer for smoothed hip Y-coordinate
  final Queue<double> _hipYBuffer = Queue<double>();

  // Track the highest point (smallest Y) during the current rep
  double? _startingHipY;

  // Track when last capture occurred for debouncing
  DateTime? _lastCaptureTime;

  // Store body height for threshold calculation
  double? _bodyHeight;

  /// Process a new pose and determine if we should capture
  ///
  /// Returns a map with:
  /// - shouldCapture: boolean indicating if this is the bottom of squat
  /// - currentState: the current RepState
  /// - smoothedHipY: the smoothed hip Y-coordinate (for debugging)
  Map<String, dynamic> processFrame(Pose pose) {
    // Get hip landmarks
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    // Validate landmarks exist
    if (leftHip == null || rightHip == null) {
      return {
        'shouldCapture': false,
        'currentState': _currentState,
        'smoothedHipY': null,
        'error': 'Hip landmarks not detected',
      };
    }

    // Calculate average hip Y-coordinate
    final rawHipY = (leftHip.y + rightHip.y) / 2.0;

    // Add to buffer and maintain size
    _hipYBuffer.addLast(rawHipY);
    if (_hipYBuffer.length > _bufferSize) {
      _hipYBuffer.removeFirst();
    }

    // Calculate smoothed hip Y (moving average)
    final smoothedHipY =
        _hipYBuffer.reduce((a, b) => a + b) / _hipYBuffer.length;

    // Calculate body height if not yet calculated
    // Using shoulder to ankle distance as approximate body height
    _bodyHeight ??= _calculateBodyHeight(pose);

    // Need enough frames in buffer and valid body height to proceed
    if (_hipYBuffer.length < _bufferSize ||
        _bodyHeight == null ||
        _bodyHeight! < 1.0) {
      return {
        'shouldCapture': false,
        'currentState': RepState.idle,
        'smoothedHipY': smoothedHipY,
        'message': 'Calibrating... Stand in frame',
      };
    }

    // Check if we're still in debounce period
    if (_lastCaptureTime != null) {
      final timeSinceLastCapture =
          DateTime.now().difference(_lastCaptureTime!).inMilliseconds;
      if (timeSinceLastCapture < _debounceDurationMs) {
        return {
          'shouldCapture': false,
          'currentState': _currentState,
          'smoothedHipY': smoothedHipY,
          'message':
              'Debouncing... ${(_debounceDurationMs - timeSinceLastCapture) ~/ 1000}s',
        };
      }
    }

    // Determine movement direction by comparing to previous smoothed value
    bool shouldCapture = false;

    // Get previous smoothed value for comparison
    if (_hipYBuffer.length >= 2) {
      // Calculate previous average (without the most recent frame)
      final prevBuffer = Queue<double>.from(_hipYBuffer.take(_bufferSize - 1));
      final prevSmoothedY =
          prevBuffer.reduce((a, b) => a + b) / prevBuffer.length;

      // Determine velocity (positive = descending in screen coordinates)
      final velocity = smoothedHipY - prevSmoothedY;

      // State machine transitions
      final previousState = _currentState;

      if (velocity > 0.5) {
        // Moving down significantly
        _currentState = RepState.descending;

        // Track the starting point of descent
        if (previousState != RepState.descending) {
          _startingHipY = prevSmoothedY;
        }
      } else if (velocity < -0.5) {
        // Moving up significantly

        // Check if we're transitioning from descending to ascending
        // This is the INFLECTION POINT - bottom of squat!
        if (previousState == RepState.descending) {
          // Validate the descent was significant enough
          if (_startingHipY != null) {
            final descentAmount = smoothedHipY - _startingHipY!;
            final descentPercentage = descentAmount / _bodyHeight!;

            if (descentPercentage >= _minDescentThreshold) {
              // Valid squat detected!
              shouldCapture = true;
              _lastCaptureTime = DateTime.now();
              print('🎯 INFLECTION POINT DETECTED!');
              print(
                  '   Descent: ${descentAmount.toStringAsFixed(1)}px (${(descentPercentage * 100).toStringAsFixed(1)}% of body height)');
            } else {
              print(
                  '⚠️  Descent too shallow: ${(descentPercentage * 100).toStringAsFixed(1)}% (need ${(_minDescentThreshold * 100).toStringAsFixed(1)}%)');
            }
          }
        }

        _currentState = RepState.ascending;
      } else {
        // Not moving much - check if we should reset to idle
        if (_currentState != RepState.idle) {
          // Only reset to idle if we've completed a full cycle
          if (_currentState == RepState.ascending) {
            _currentState = RepState.idle;
            _startingHipY = null;
          }
        }
      }
    }

    return {
      'shouldCapture': shouldCapture,
      'currentState': _currentState,
      'smoothedHipY': smoothedHipY,
      'bodyHeight': _bodyHeight,
      'startingY': _startingHipY,
    };
  }

  /// Calculate approximate body height using pose landmarks
  /// Uses the distance from shoulder to ankle as a proxy for body height
  double? _calculateBodyHeight(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder == null || leftAnkle == null) {
      return null;
    }

    // Use vertical distance (Y-axis) as approximate height
    final height = (leftAnkle.y - leftShoulder.y).abs();

    // Validate it's a reasonable value (should be several hundred pixels)
    if (height < 100) {
      return null; // Too small, probably not a full body in frame
    }

    return height;
  }

  /// Reset the detector state (useful for testing or manual resets)
  void reset() {
    _currentState = RepState.idle;
    _hipYBuffer.clear();
    _startingHipY = null;
    _lastCaptureTime = null;
    _bodyHeight = null;
  }

  /// Get the current state
  RepState get currentState => _currentState;

  /// Check if detector is currently debouncing
  bool get isDebouncing {
    if (_lastCaptureTime == null) return false;
    final timeSince =
        DateTime.now().difference(_lastCaptureTime!).inMilliseconds;
    return timeSince < _debounceDurationMs;
  }
}
