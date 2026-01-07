import 'dart:collection';

/// Smooths angle measurements over time to reduce noise
/// Uses exponential moving average for real-time responsiveness
class AngleSmoother {
  final Map<String, Queue<double>> _angleBuffers = {};
  final int _bufferSize;
  final double _alpha; // EMA smoothing factor (0-1)

  /// Create smoother with buffer size and smoothing factor
  /// - bufferSize: number of frames to keep in buffer
  /// - alpha: EMA factor (higher = more responsive, lower = smoother)
  AngleSmoother({int bufferSize = 5, double alpha = 0.3})
      : _bufferSize = bufferSize,
        _alpha = alpha.clamp(0.0, 1.0);

  /// Add a new angle measurement and return smoothed value
  /// Uses exponential moving average for better real-time performance
  double smooth(String angleKey, double newValue) {
    // Initialize buffer if needed
    if (!_angleBuffers.containsKey(angleKey)) {
      _angleBuffers[angleKey] = Queue<double>();
    }

    final buffer = _angleBuffers[angleKey]!;

    // Add new value to buffer
    buffer.addLast(newValue);

    // Maintain buffer size
    if (buffer.length > _bufferSize) {
      buffer.removeFirst();
    }

    // Calculate exponential moving average
    if (buffer.length == 1) {
      return newValue; // First value, no smoothing needed
    }

    // EMA: smoothed = alpha * current + (1 - alpha) * previous
    double ema = buffer.first;
    for (var i = 1; i < buffer.length; i++) {
      ema = _alpha * buffer.elementAt(i) + (1 - _alpha) * ema;
    }

    return ema;
  }

  /// Calculate simple moving average (alternative to EMA)
  double simpleMovingAverage(String angleKey) {
    if (!_angleBuffers.containsKey(angleKey) || _angleBuffers[angleKey]!.isEmpty) {
      return 0;
    }

    final buffer = _angleBuffers[angleKey]!;
    final sum = buffer.reduce((a, b) => a + b);
    return sum / buffer.length;
  }

  /// Get current smoothed value without adding new measurement
  double? getCurrentSmoothed(String angleKey) {
    if (!_angleBuffers.containsKey(angleKey) || _angleBuffers[angleKey]!.isEmpty) {
      return null;
    }

    final buffer = _angleBuffers[angleKey]!;
    
    // Return EMA of current buffer
    if (buffer.length == 1) {
      return buffer.first;
    }

    double ema = buffer.first;
    for (var i = 1; i < buffer.length; i++) {
      ema = _alpha * buffer.elementAt(i) + (1 - _alpha) * ema;
    }

    return ema;
  }

  /// Smooth multiple angles at once
  Map<String, double> smoothAngles(Map<String, double?> angles) {
    final smoothed = <String, double>{};

    for (var entry in angles.entries) {
      if (entry.value != null) {
        smoothed[entry.key] = smooth(entry.key, entry.value!);
      }
    }

    return smoothed;
  }

  /// Reset all buffers (useful when starting new exercise)
  void reset() {
    _angleBuffers.clear();
  }

  /// Reset specific angle buffer
  void resetAngle(String angleKey) {
    _angleBuffers.remove(angleKey);
  }

  /// Check if buffer has enough data for reliable smoothing
  bool hasEnoughData(String angleKey) {
    return _angleBuffers.containsKey(angleKey) &&
        _angleBuffers[angleKey]!.length >= (_bufferSize * 0.6).ceil();
  }

  /// Get buffer size for an angle
  int getBufferSize(String angleKey) {
    return _angleBuffers[angleKey]?.length ?? 0;
  }
}
