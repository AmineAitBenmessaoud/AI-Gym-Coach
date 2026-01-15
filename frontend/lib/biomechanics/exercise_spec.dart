/// Defines ideal biomechanical parameters for each exercise
/// Used by FormAnomalyDetector to identify form issues
class ExerciseSpec {
  final String name;
  final Map<String, AngleRange> angleRanges;
  final List<FormRule> rules;

  ExerciseSpec({
    required this.name,
    required this.angleRanges,
    required this.rules,
  });

  /// Get angle range for a specific joint
  AngleRange? getAngleRange(String jointName) => angleRanges[jointName];

  /// Check if an angle is within acceptable range
  bool isAngleValid(String jointName, double angle) {
    final range = angleRanges[jointName];
    if (range == null) return true; // No spec = assume valid
    return range.isValid(angle);
  }
}

/// Acceptable angle range for a joint during exercise
class AngleRange {
  final double minIdeal;
  final double maxIdeal;
  final double minAcceptable;
  final double maxAcceptable;
  final String jointName;

  AngleRange({
    required this.jointName,
    required this.minIdeal,
    required this.maxIdeal,
    double? minAcceptable,
    double? maxAcceptable,
  }) : minAcceptable = minAcceptable ?? minIdeal - 10,
       maxAcceptable = maxAcceptable ?? maxIdeal + 10;

  /// Check if angle is within acceptable range
  bool isValid(double angle) {
    return angle >= minAcceptable && angle <= maxAcceptable;
  }

  /// Check if angle is within ideal range
  bool isIdeal(double angle) {
    return angle >= minIdeal && angle <= maxIdeal;
  }

  /// Get severity of deviation (0 = ideal, 1 = at acceptable limit, >1 = beyond acceptable)
  double getDeviationSeverity(double angle) {
    if (isIdeal(angle)) return 0.0;

    if (angle < minAcceptable) {
      // Below acceptable minimum
      return (minAcceptable - angle) / (minAcceptable - minIdeal + 10);
    } else if (angle > maxAcceptable) {
      // Above acceptable maximum
      return (angle - maxAcceptable) / (maxAcceptable - maxIdeal + 10);
    } else {
      // Between acceptable and ideal
      if (angle < minIdeal) {
        return (minIdeal - angle) / (minIdeal - minAcceptable);
      } else {
        return (angle - maxIdeal) / (maxAcceptable - maxIdeal);
      }
    }
  }
}

/// Rule for detecting form issues
class FormRule {
  final String name;
  final String description;
  final FormRuleType type;
  final List<String> requiredJoints;
  final bool Function(Map<String, double> angles) condition;

  FormRule({
    required this.name,
    required this.description,
    required this.type,
    required this.requiredJoints,
    required this.condition,
  });

  /// Check if rule is violated
  bool isViolated(Map<String, double> angles) {
    // Check if all required joints are present
    for (var joint in requiredJoints) {
      if (!angles.containsKey(joint)) return false;
    }

    return condition(angles);
  }
}

enum FormRuleType {
  safety, // Critical safety issue (knee valgus, hyperextension)
  technique, // Form issue affecting effectiveness
  warning, // Minor deviation from ideal form
}

/// Exercise specifications database
class ExerciseSpecs {
  /// Squat specifications
  /// Squat specifications
  /// Sources:
  /// - NCBI: "Biomechanical analysis of the squat exercise"
  ///   https://pubmed.ncbi.nlm.nih.gov/12423179/
  /// - ExRx Squat Kinematics
  ///   https://exrx.net/WeightExercises/Quadriceps/BBBackSquat
  static ExerciseSpec get squat => ExerciseSpec(
    name: 'squat',
    angleRanges: {
      'leftKnee': AngleRange(
        jointName: 'leftKnee',
        minIdeal: 80,
        maxIdeal: 110,
        minAcceptable: 70,
        maxAcceptable: 130,
      ),
      'rightKnee': AngleRange(
        jointName: 'rightKnee',
        minIdeal: 80,
        maxIdeal: 110,
        minAcceptable: 70,
        maxAcceptable: 130,
      ),
      'leftHip': AngleRange(
        jointName: 'leftHip',
        minIdeal: 70,
        maxIdeal: 100,
        minAcceptable: 60,
        maxAcceptable: 120,
      ),
      'rightHip': AngleRange(
        jointName: 'rightHip',
        minIdeal: 70,
        maxIdeal: 100,
        minAcceptable: 60,
        maxAcceptable: 120,
      ),
      'torso': AngleRange(
        jointName: 'torso',
        minIdeal: 0,
        maxIdeal: 30,
        minAcceptable: 0,
        maxAcceptable: 45,
      ),
    },
    rules: [
      FormRule(
        name: 'shallow_squat',
        description: 'Insufficient squat depth',
        type: FormRuleType.technique,
        requiredJoints: ['leftKnee', 'rightKnee'],
        condition: (a) => ((a['leftKnee']! + a['rightKnee']!) / 2) > 125,
      ),
      FormRule(
        name: 'asymmetric_squat',
        description: 'Uneven knee bend',
        type: FormRuleType.technique,
        requiredJoints: ['leftKnee', 'rightKnee'],
        condition: (a) => (a['leftKnee']! - a['rightKnee']!).abs() > 15,
      ),
      FormRule(
        name: 'excessive_lean',
        description: 'Excessive forward torso lean',
        type: FormRuleType.warning,
        requiredJoints: ['torso'],
        condition: (a) => a['torso']! > 45,
      ),
    ],
  );

  /// Push-up specifications
  /// Sources:
  /// - NCBI: "Kinematic analysis of push-up exercises"
  ///   https://pubmed.ncbi.nlm.nih.gov/20179648/
  /// - ExRx Push-Up
  ///   https://exrx.net/WeightExercises/PectoralSternal/BWPushup
  static ExerciseSpec get pushup => ExerciseSpec(
    name: 'pushup',
    angleRanges: {
      'leftElbow': AngleRange(
        jointName: 'leftElbow',
        minIdeal: 75,
        maxIdeal: 100,
        minAcceptable: 60,
        maxAcceptable: 120,
      ),
      'rightElbow': AngleRange(
        jointName: 'rightElbow',
        minIdeal: 75,
        maxIdeal: 100,
        minAcceptable: 60,
        maxAcceptable: 120,
      ),
      'torso': AngleRange(
        jointName: 'torso',
        minIdeal: 0,
        maxIdeal: 10,
        minAcceptable: 0,
        maxAcceptable: 20,
      ),
    },
    rules: [
      FormRule(
        name: 'shallow_pushup',
        description: 'Insufficient elbow bend',
        type: FormRuleType.technique,
        requiredJoints: ['leftElbow', 'rightElbow'],
        condition: (a) => ((a['leftElbow']! + a['rightElbow']!) / 2) > 120,
      ),
      FormRule(
        name: 'hip_sag',
        description: 'Hips sagging (core disengaged)',
        type: FormRuleType.warning,
        requiredJoints: ['torso'],
        condition: (a) => a['torso']! > 20,
      ),
    ],
  );

  /// Lunge specifications
  /// Sources:
  /// - NCBI: "Lower limb kinematics during forward lunge"
  ///   https://pubmed.ncbi.nlm.nih.gov/17685704/
  /// - ExRx Forward Lunge
  ///   https://exrx.net/WeightExercises/Quadriceps/DBLunge
  static ExerciseSpec get lunge => ExerciseSpec(
    name: 'lunge',
    angleRanges: {
      'frontKnee': AngleRange(
        jointName: 'frontKnee',
        minIdeal: 80,
        maxIdeal: 100,
        minAcceptable: 70,
        maxAcceptable: 120,
      ),
      'backKnee': AngleRange(
        jointName: 'backKnee',
        minIdeal: 80,
        maxIdeal: 110,
        minAcceptable: 70,
        maxAcceptable: 130,
      ),
      'torso': AngleRange(
        jointName: 'torso',
        minIdeal: 0,
        maxIdeal: 20,
        minAcceptable: 0,
        maxAcceptable: 30,
      ),
    },
    rules: [
      FormRule(
        name: 'knee_forward',
        description: 'Front knee bending excessively',
        type: FormRuleType.warning,
        requiredJoints: ['frontKnee'],
        condition: (a) => a['frontKnee']! < 70,
      ),
      FormRule(
        name: 'torso_instability',
        description: 'Torso leaning too much',
        type: FormRuleType.technique,
        requiredJoints: ['torso'],
        condition: (a) => a['torso']! > 30,
      ),
    ],
  );

  /// Pull-up specifications
  /// Sources:
  /// - NCBI: "Kinematics of pull-up exercises"
  ///   https://pubmed.ncbi.nlm.nih.gov/30580363/
  /// - ExRx Pull-Up
  ///   https://exrx.net/WeightExercises/LatissimusDorsi/BWPullup
  static ExerciseSpec get pullup => ExerciseSpec(
    name: 'pullup',
    angleRanges: {
      'leftElbow': AngleRange(
        jointName: 'leftElbow',
        minIdeal: 45,
        maxIdeal: 90,
        minAcceptable: 30,
        maxAcceptable: 120,
      ),
      'rightElbow': AngleRange(
        jointName: 'rightElbow',
        minIdeal: 45,
        maxIdeal: 90,
        minAcceptable: 30,
        maxAcceptable: 120,
      ),
      'shoulder': AngleRange(
        jointName: 'shoulder',
        minIdeal: 30,
        maxIdeal: 60,
        minAcceptable: 20,
        maxAcceptable: 80,
      ),
    },
    rules: [
      FormRule(
        name: 'partial_pullup',
        description: 'Incomplete pull-up range',
        type: FormRuleType.technique,
        requiredJoints: ['leftElbow', 'rightElbow'],
        condition: (a) => ((a['leftElbow']! + a['rightElbow']!) / 2) > 110,
      ),
    ],
  );

  /// Plank specifications
  /// Sources:
  /// - NCBI: "Core muscle activation during plank exercises"
  ///   https://pubmed.ncbi.nlm.nih.gov/23822095/
  /// - ExRx Plank
  ///   https://exrx.net/WeightExercises/RectusAbdominis/BWFrontPlank
  static ExerciseSpec get plank => ExerciseSpec(
    name: 'plank',
    angleRanges: {
      'torso': AngleRange(
        jointName: 'torso',
        minIdeal: 0,
        maxIdeal: 5,
        minAcceptable: 0,
        maxAcceptable: 10,
      ),
      'hip': AngleRange(
        jointName: 'hip',
        minIdeal: 170,
        maxIdeal: 180,
        minAcceptable: 160,
        maxAcceptable: 180,
      ),
    },
    rules: [
      FormRule(
        name: 'hip_sag',
        description: 'Hips sagging below neutral',
        type: FormRuleType.safety,
        requiredJoints: ['hip'],
        condition: (a) => a['hip']! < 160,
      ),
      FormRule(
        name: 'pike_plank',
        description: 'Hips too high (pike position)',
        type: FormRuleType.warning,
        requiredJoints: ['torso'],
        condition: (a) => a['torso']! > 15,
      ),
    ],
  );

  static final Map<String, ExerciseSpec> _registry = {
    'squat': squat,
    'pushup': pushup,
    'lunge': lunge,
    'pullup': pullup,
    'plank': plank,
  };

  static ExerciseSpec? getSpec(String exerciseName) {
    final key = exerciseName
        .toLowerCase()
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll(' ', '');

    return _registry[key];
  }
}
