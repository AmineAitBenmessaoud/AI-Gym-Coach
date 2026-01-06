/// Model representing a gym exercise
class Exercise {
  final String id;
  final String name;
  final String description;
  final List<String> instructions;
  final List<String> tips;
  final String difficulty;
  final String icon;
  final List<String> targetMuscles;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.tips,
    required this.difficulty,
    required this.icon,
    required this.targetMuscles,
  });
}

/// Available exercises in the app
class Exercises {
  static const List<Exercise> all = [
    Exercise(
      id: 'squat',
      name: 'Squat',
      description:
          'A fundamental lower body exercise that strengthens your legs and glutes.',
      instructions: [
        'Stand with feet shoulder-width apart',
        'Keep your chest up and core engaged',
        'Lower your body by bending your knees and hips',
        'Go down until thighs are parallel to the ground',
        'Push through your heels to return to starting position',
      ],
      tips: [
        'Keep your knees aligned with your toes',
        'Don\'t let your knees cave inward',
        'Keep your weight on your heels',
        'Maintain a neutral spine throughout',
      ],
      difficulty: 'Beginner',
      icon: '🏋️',
      targetMuscles: ['Quadriceps', 'Glutes', 'Hamstrings', 'Core'],
    ),
    Exercise(
      id: 'pushup',
      name: 'Push-up',
      description:
          'A classic upper body exercise that builds chest, shoulders, and triceps.',
      instructions: [
        'Start in a plank position with hands shoulder-width apart',
        'Keep your body in a straight line from head to heels',
        'Lower your body until chest nearly touches the ground',
        'Keep your elbows at 45 degrees from your body',
        'Push back up to starting position',
      ],
      tips: [
        'Don\'t let your hips sag or pike up',
        'Keep your core tight throughout',
        'Breathe in going down, out going up',
        'Start with knee push-ups if needed',
      ],
      difficulty: 'Beginner',
      icon: '💪',
      targetMuscles: ['Chest', 'Shoulders', 'Triceps', 'Core'],
    ),
    Exercise(
      id: 'plank',
      name: 'Plank',
      description:
          'An isometric core exercise that builds total body stability.',
      instructions: [
        'Start in a forearm plank position',
        'Place forearms on the ground, elbows under shoulders',
        'Extend your legs and balance on your toes',
        'Keep your body in a straight line',
        'Hold this position while breathing normally',
      ],
      tips: [
        'Don\'t let your hips drop or rise',
        'Keep your neck neutral, look down',
        'Engage your core and glutes',
        'Start with shorter holds and progress',
      ],
      difficulty: 'Beginner',
      icon: '🧘',
      targetMuscles: ['Core', 'Shoulders', 'Back', 'Glutes'],
    ),
    Exercise(
      id: 'lunge',
      name: 'Lunge',
      description:
          'A unilateral leg exercise that improves balance and leg strength.',
      instructions: [
        'Stand with feet hip-width apart',
        'Step forward with one leg',
        'Lower your hips until both knees are at 90 degrees',
        'Front knee should be above the ankle',
        'Push back to starting position and repeat',
      ],
      tips: [
        'Keep your torso upright',
        'Don\'t let your front knee go past your toes',
        'Alternate legs for balanced training',
        'Use a wall for balance if needed',
      ],
      difficulty: 'Intermediate',
      icon: '🦵',
      targetMuscles: ['Quadriceps', 'Glutes', 'Hamstrings', 'Calves'],
    ),
  ];

  static Exercise? findById(String id) {
    try {
      return all.firstWhere((exercise) => exercise.id == id);
    } catch (e) {
      return null;
    }
  }
}
