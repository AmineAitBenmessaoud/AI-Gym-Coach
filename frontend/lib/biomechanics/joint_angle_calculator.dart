import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Calculates joint angles from pose landmarks
/// Uses 3-point angle calculation: angle at point B formed by points A-B-C
class JointAngleCalculator {
  /// Calculate angle at point B formed by points A-B-C in degrees
  /// Returns angle in range [0, 180] degrees
  static double calculateAngle(
    PoseLandmark pointA,
    PoseLandmark pointB,
    PoseLandmark pointC,
  ) {
    // Vector from B to A
    final double baX = pointA.x - pointB.x;
    final double baY = pointA.y - pointB.y;

    // Vector from B to C
    final double bcX = pointC.x - pointB.x;
    final double bcY = pointC.y - pointB.y;

    // Calculate angle using dot product and cross product
    final double dotProduct = baX * bcX + baY * bcY;
    final double magnitudeBA = sqrt(baX * baX + baY * baY);
    final double magnitudeBC = sqrt(bcX * bcX + bcY * bcY);

    // Avoid division by zero
    if (magnitudeBA == 0 || magnitudeBC == 0) {
      return 0;
    }

    // Calculate cosine of angle
    double cosineAngle = dotProduct / (magnitudeBA * magnitudeBC);

    // Clamp to [-1, 1] to avoid numerical errors with acos
    cosineAngle = cosineAngle.clamp(-1.0, 1.0);

    // Convert to degrees
    final double angleRadians = acos(cosineAngle);
    return angleRadians * 180 / pi;
  }

  /// Calculate knee angle (hip-knee-ankle)
  /// Returns null if landmarks are missing or confidence too low
  static double? calculateKneeAngle(Pose pose, {bool isLeft = true}) {
    final hip = isLeft
        ? pose.landmarks[PoseLandmarkType.leftHip]
        : pose.landmarks[PoseLandmarkType.rightHip];
    final knee = isLeft
        ? pose.landmarks[PoseLandmarkType.leftKnee]
        : pose.landmarks[PoseLandmarkType.rightKnee];
    final ankle = isLeft
        ? pose.landmarks[PoseLandmarkType.leftAnkle]
        : pose.landmarks[PoseLandmarkType.rightAnkle];

    if (hip == null || knee == null || ankle == null) return null;

    // Filter by confidence
    if (hip.likelihood < 0.5 || knee.likelihood < 0.5 || ankle.likelihood < 0.5) {
      return null;
    }

    return calculateAngle(hip, knee, ankle);
  }

  /// Calculate hip angle (shoulder-hip-knee)
  static double? calculateHipAngle(Pose pose, {bool isLeft = true}) {
    final shoulder = isLeft
        ? pose.landmarks[PoseLandmarkType.leftShoulder]
        : pose.landmarks[PoseLandmarkType.rightShoulder];
    final hip = isLeft
        ? pose.landmarks[PoseLandmarkType.leftHip]
        : pose.landmarks[PoseLandmarkType.rightHip];
    final knee = isLeft
        ? pose.landmarks[PoseLandmarkType.leftKnee]
        : pose.landmarks[PoseLandmarkType.rightKnee];

    if (shoulder == null || hip == null || knee == null) return null;

    if (shoulder.likelihood < 0.5 || hip.likelihood < 0.5 || knee.likelihood < 0.5) {
      return null;
    }

    return calculateAngle(shoulder, hip, knee);
  }

  /// Calculate elbow angle (shoulder-elbow-wrist)
  static double? calculateElbowAngle(Pose pose, {bool isLeft = true}) {
    final shoulder = isLeft
        ? pose.landmarks[PoseLandmarkType.leftShoulder]
        : pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeft
        ? pose.landmarks[PoseLandmarkType.leftElbow]
        : pose.landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeft
        ? pose.landmarks[PoseLandmarkType.leftWrist]
        : pose.landmarks[PoseLandmarkType.rightWrist];

    if (shoulder == null || elbow == null || wrist == null) return null;

    if (shoulder.likelihood < 0.5 || elbow.likelihood < 0.5 || wrist.likelihood < 0.5) {
      return null;
    }

    return calculateAngle(shoulder, elbow, wrist);
  }

  /// Calculate shoulder angle (hip-shoulder-elbow)
  static double? calculateShoulderAngle(Pose pose, {bool isLeft = true}) {
    final hip = isLeft
        ? pose.landmarks[PoseLandmarkType.leftHip]
        : pose.landmarks[PoseLandmarkType.rightHip];
    final shoulder = isLeft
        ? pose.landmarks[PoseLandmarkType.leftShoulder]
        : pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeft
        ? pose.landmarks[PoseLandmarkType.leftElbow]
        : pose.landmarks[PoseLandmarkType.rightElbow];

    if (hip == null || shoulder == null || elbow == null) return null;

    if (hip.likelihood < 0.5 || shoulder.likelihood < 0.5 || elbow.likelihood < 0.5) {
      return null;
    }

    return calculateAngle(hip, shoulder, elbow);
  }

  /// Calculate torso angle relative to vertical (hip-shoulder line vs vertical)
  static double? calculateTorsoAngle(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      return null;
    }

    // Calculate midpoints
    final shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipMidX = (leftHip.x + rightHip.x) / 2;
    final hipMidY = (leftHip.y + rightHip.y) / 2;

    // Calculate angle from vertical (Y-axis)
    final dx = hipMidX - shoulderMidX;
    final dy = hipMidY - shoulderMidY;

    // atan2 gives angle from horizontal, so we adjust
    final angleFromHorizontal = atan2(dy, dx) * 180 / pi;
    
    // Convert to angle from vertical
    return (90 - angleFromHorizontal).abs();
  }

  /// Get all computed angles for a pose
  static Map<String, double?> computeAllAngles(Pose pose) {
    return {
      'leftKnee': calculateKneeAngle(pose, isLeft: true),
      'rightKnee': calculateKneeAngle(pose, isLeft: false),
      'leftHip': calculateHipAngle(pose, isLeft: true),
      'rightHip': calculateHipAngle(pose, isLeft: false),
      'leftElbow': calculateElbowAngle(pose, isLeft: true),
      'rightElbow': calculateElbowAngle(pose, isLeft: false),
      'leftShoulder': calculateShoulderAngle(pose, isLeft: true),
      'rightShoulder': calculateShoulderAngle(pose, isLeft: false),
      'torso': calculateTorsoAngle(pose),
    };
  }
}
