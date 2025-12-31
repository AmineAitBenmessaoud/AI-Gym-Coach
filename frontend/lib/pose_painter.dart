import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'utils.dart';

/// CustomPainter that draws the pose skeleton overlay.
/// 
/// Renders:
/// - Yellow dots for landmarks (joints)
/// - Bright green lines for connections (bones)
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final CoordinateTranslator translator;

  PosePainter({
    required this.poses,
    required this.translator,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint for landmarks (joints) - Yellow dots
    final landmarkPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;

    // Paint for connections (bones) - Bright green lines
    final connectionPaint = Paint()
      ..color = const Color(0xFF00FF00) // Bright green
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    for (final pose in poses) {
      // Draw all connections (bones) first, so dots appear on top
      _drawConnections(canvas, pose, connectionPaint);
      
      // Draw all landmarks (joints)
      _drawLandmarks(canvas, pose, landmarkPaint);
    }
  }

  /// Draws all pose landmarks as yellow dots
  void _drawLandmarks(Canvas canvas, Pose pose, Paint paint) {
    pose.landmarks.forEach((type, landmark) {
      final offset = translator.getOffset(landmark);
      
      // Draw larger dots for major joints, smaller for minor ones
      double radius = _getLandmarkRadius(type);
      
      canvas.drawCircle(offset, radius, paint);
    });
  }

  /// Draws connections between landmarks as green lines
  void _drawConnections(Canvas canvas, Pose pose, Paint paint) {
    // Define the skeleton structure (which landmarks connect to which)
    final connections = _getPoseConnections();

    for (final connection in connections) {
      final startLandmark = pose.landmarks[connection.start];
      final endLandmark = pose.landmarks[connection.end];

      if (startLandmark != null && endLandmark != null) {
        // Only draw if both landmarks are detected with reasonable confidence
        if (startLandmark.likelihood > 0.5 && endLandmark.likelihood > 0.5) {
          final startOffset = translator.getOffset(startLandmark);
          final endOffset = translator.getOffset(endLandmark);

          canvas.drawLine(startOffset, endOffset, paint);
        }
      }
    }
  }

  /// Returns the radius for a landmark based on its importance
  double _getLandmarkRadius(PoseLandmarkType type) {
    // Major joints get larger dots
    const majorJoints = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    return majorJoints.contains(type) ? 8.0 : 5.0;
  }

  /// Defines the skeleton structure - which landmarks connect to form bones
  List<_Connection> _getPoseConnections() {
    return [
      // Face
      _Connection(PoseLandmarkType.leftEar, PoseLandmarkType.leftEye),
      _Connection(PoseLandmarkType.leftEye, PoseLandmarkType.nose),
      _Connection(PoseLandmarkType.nose, PoseLandmarkType.rightEye),
      _Connection(PoseLandmarkType.rightEye, PoseLandmarkType.rightEar),

      // Upper body - left side
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
      _Connection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky),
      _Connection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex),

      // Upper body - right side
      _Connection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
      _Connection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky),
      _Connection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex),

      // Shoulders to hips
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
      _Connection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
      _Connection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
      _Connection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),

      // Lower body - left side
      _Connection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
      _Connection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      _Connection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel),
      _Connection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex),

      // Lower body - right side
      _Connection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
      _Connection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
      _Connection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel),
      _Connection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex),
    ];
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    // Repaint if poses have changed
    return oldDelegate.poses != poses;
  }
}

/// Helper class to define a connection between two landmarks
class _Connection {
  final PoseLandmarkType start;
  final PoseLandmarkType end;

  _Connection(this.start, this.end);
}
