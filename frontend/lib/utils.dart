import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Utilities for coordinate transformation from MediaPipe normalized space
/// to screen pixel space, with proper aspect ratio handling.
class CoordinateTranslator {
  final Size imageSize;
  final Size screenSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final double calibrationOffsetX;
  final double calibrationOffsetY;
  final double calibrationScale;

  CoordinateTranslator({
    required this.imageSize,
    required this.screenSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.calibrationOffsetX = 0.0,
    this.calibrationOffsetY = 0.0,
    this.calibrationScale = 1.0,
  });

  /// Translates a PoseLandmark to screen coordinates.
  /// 
  /// This matches how CameraPreview scales the camera feed to the screen.
  Offset getOffset(PoseLandmark landmark) {
    double x = landmark.x;
    double y = landmark.y;

    // CameraPreview uses "cover" mode: scales to fill, crops overflow
    // We need to use the same scale factor to match
    
    double scaleX = screenSize.width / imageSize.width;
    double scaleY = screenSize.height / imageSize.height;
    
    // Use the LARGER scale (this fills the screen and crops overflow)
    double scale = scaleX > scaleY ? scaleX : scaleY;
    
    // Apply uniform scaling
    double scaledX = x * scale;
    double scaledY = y * scale;
    
    // Only apply offset for letterboxed dimension (positive offset)
    // For cropped dimension (negative offset), center the crop
    double offsetX = (screenSize.width - imageSize.width * scale) / 2;
    double offsetY = (screenSize.height - imageSize.height * scale) / 2;
    
    // Only add positive offsets (letterboxing), for negative (cropping) we need to shift
    if (offsetX < 0) {
      // Width is being cropped - center the crop
      scaledX += offsetX;
    }
    if (offsetY < 0) {
      // Height is being cropped - center the crop  
      scaledY += offsetY;
    }
    
    // Handle front camera mirroring
    if (cameraLensDirection == CameraLensDirection.front) {
      scaledX = screenSize.width - scaledX;
    }
    
    // Apply user scale adjustment (scale from center)
    if (calibrationScale != 1.0) {
      double centerX = screenSize.width / 2;
      double centerY = screenSize.height / 2;
      scaledX = centerX + (scaledX - centerX) * calibrationScale;
      scaledY = centerY + (scaledY - centerY) * calibrationScale;
    }
    
    // Apply user position adjustments
    scaledX += calibrationOffsetX;
    scaledY += calibrationOffsetY;
    
    return Offset(scaledX, scaledY);
  }

  /// Rotates an offset based on the image rotation
  Offset _rotateOffset(
    Offset offset,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation0deg:
        return offset;
      case InputImageRotation.rotation90deg:
        return Offset(
          imageSize.height - offset.dy,
          offset.dx,
        );
      case InputImageRotation.rotation180deg:
        return Offset(
          imageSize.width - offset.dx,
          imageSize.height - offset.dy,
        );
      case InputImageRotation.rotation270deg:
        return Offset(
          offset.dy,
          imageSize.width - offset.dx,
        );
    }
  }
}

/// Converts camera orientation to InputImageRotation for ML Kit
InputImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 0:
      return InputImageRotation.rotation0deg;
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    case 270:
      return InputImageRotation.rotation270deg;
    default:
      return InputImageRotation.rotation0deg;
  }
}

/// Gets the rotation value based on device orientation and camera
int getRotation(CameraController controller) {
  if (controller.description.sensorOrientation == 90) {
    return 90;
  } else if (controller.description.sensorOrientation == 270) {
    return 270;
  }
  return 0;
}

/// Calculates absolute image size from camera controller
Size getImageSize(CameraController controller) {
  final size = controller.value.previewSize!;
  // Camera preview size is often reported in landscape orientation
  // We need to swap for portrait
  if (controller.value.deviceOrientation == DeviceOrientation.portraitUp ||
      controller.value.deviceOrientation == DeviceOrientation.portraitDown) {
    return Size(size.height, size.width);
  }
  return size;
}
