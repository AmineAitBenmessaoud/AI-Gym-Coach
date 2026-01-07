import 'exercise_spec.dart';
import 'dart:async';

/// Detects form issues by comparing computed angles against exercise specs
/// Emits FormIssue events when anomalies are detected
class FormAnomalyDetector {
  final ExerciseSpec exerciseSpec;
  final StreamController<FormIssue> _issueController =
      StreamController<FormIssue>.broadcast();
  
  // Track issues to avoid duplicate alerts
  final Map<String, DateTime> _lastIssueTime = {};
  static const Duration _issueCooldown = Duration(seconds: 3);

  FormAnomalyDetector(this.exerciseSpec);

  /// Stream of detected form issues
  Stream<FormIssue> get issues => _issueController.stream;

  /// Analyze angles and detect anomalies
  /// Returns list of detected issues for this frame
  List<FormIssue> analyze(Map<String, double> smoothedAngles) {
    final detectedIssues = <FormIssue>[];

    // 1. Check angle ranges
    for (var entry in smoothedAngles.entries) {
      final jointName = entry.key;
      final angle = entry.value;
      final range = exerciseSpec.getAngleRange(jointName);

      if (range != null && !range.isValid(angle)) {
        final severity = range.getDeviationSeverity(angle);
        final issue = FormIssue(
          type: FormIssueType.angleDeviation,
          severity: _severityFromValue(severity),
          jointName: jointName,
          description: _getAngleDeviationDescription(jointName, angle, range),
          measuredValue: angle,
          expectedRange: '${range.minAcceptable.toInt()}-${range.maxAcceptable.toInt()}°',
          timestamp: DateTime.now(),
        );

        if (_shouldEmitIssue(issue.key)) {
          detectedIssues.add(issue);
          _issueController.add(issue);
          _lastIssueTime[issue.key] = DateTime.now();
        }
      }
    }

    // 2. Check form rules
    for (var rule in exerciseSpec.rules) {
      if (rule.isViolated(smoothedAngles)) {
        final issue = FormIssue(
          type: _issueTypeFromRule(rule.type),
          severity: _severityFromRuleType(rule.type),
          jointName: rule.requiredJoints.join(', '),
          description: rule.description,
          measuredValue: null,
          expectedRange: null,
          timestamp: DateTime.now(),
          ruleName: rule.name,
        );

        if (_shouldEmitIssue(issue.key)) {
          detectedIssues.add(issue);
          _issueController.add(issue);
          _lastIssueTime[issue.key] = DateTime.now();
        }
      }
    }

    return detectedIssues;
  }

  /// Check if enough time has passed since last issue of this type
  bool _shouldEmitIssue(String issueKey) {
    if (!_lastIssueTime.containsKey(issueKey)) return true;

    final timeSinceLastIssue = DateTime.now().difference(_lastIssueTime[issueKey]!);
    return timeSinceLastIssue >= _issueCooldown;
  }

  /// Generate description for angle deviation
  String _getAngleDeviationDescription(
    String jointName,
    double angle,
    AngleRange range,
  ) {
    if (angle < range.minAcceptable) {
      return '$jointName angle too small (${angle.toInt()}°, need >${range.minAcceptable.toInt()}°)';
    } else {
      return '$jointName angle too large (${angle.toInt()}°, need <${range.maxAcceptable.toInt()}°)';
    }
  }

  FormIssueSeverity _severityFromValue(double severity) {
    if (severity > 2.0) return FormIssueSeverity.critical;
    if (severity > 1.0) return FormIssueSeverity.warning;
    return FormIssueSeverity.minor;
  }

  FormIssueSeverity _severityFromRuleType(FormRuleType ruleType) {
    switch (ruleType) {
      case FormRuleType.safety:
        return FormIssueSeverity.critical;
      case FormRuleType.technique:
        return FormIssueSeverity.warning;
      case FormRuleType.warning:
        return FormIssueSeverity.minor;
    }
  }

  FormIssueType _issueTypeFromRule(FormRuleType ruleType) {
    switch (ruleType) {
      case FormRuleType.safety:
        return FormIssueType.safety;
      case FormRuleType.technique:
        return FormIssueType.technique;
      case FormRuleType.warning:
        return FormIssueType.minor;
    }
  }

  /// Reset cooldown timers
  void reset() {
    _lastIssueTime.clear();
  }

  void dispose() {
    _issueController.close();
  }
}

/// Represents a detected form issue
class FormIssue {
  final FormIssueType type;
  final FormIssueSeverity severity;
  final String jointName;
  final String description;
  final double? measuredValue;
  final String? expectedRange;
  final DateTime timestamp;
  final String? ruleName;

  FormIssue({
    required this.type,
    required this.severity,
    required this.jointName,
    required this.description,
    this.measuredValue,
    this.expectedRange,
    required this.timestamp,
    this.ruleName,
  });

  /// Unique key for deduplication
  String get key => ruleName ?? '$jointName-$type';

  /// Convert to JSON for backend
  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'severity': severity.toString().split('.').last,
        'jointName': jointName,
        'description': description,
        'measuredValue': measuredValue,
        'expectedRange': expectedRange,
        'timestamp': timestamp.toIso8601String(),
        'ruleName': ruleName,
      };

  @override
  String toString() => '[$severity] $description';
}

enum FormIssueType {
  angleDeviation,
  technique,
  safety,
  minor,
}

enum FormIssueSeverity {
  minor, // Yellow - room for improvement
  warning, // Orange - affecting technique
  critical, // Red - safety concern
}
