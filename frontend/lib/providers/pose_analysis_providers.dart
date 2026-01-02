import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pose_analysis_service.dart';

/// Modèle pour le résultat d'analyse
class PoseAnalysisResult {
  final bool success;
  final String? error;
  final Map<String, dynamic>? analysis;
  final bool isLoading;

  PoseAnalysisResult({
    required this.success,
    this.error,
    this.analysis,
    this.isLoading = false,
  });

  PoseAnalysisResult copyWith({
    bool? success,
    String? error,
    Map<String, dynamic>? analysis,
    bool? isLoading,
  }) {
    return PoseAnalysisResult(
      success: success ?? this.success,
      error: error ?? this.error,
      analysis: analysis ?? this.analysis,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// État pour le feedback en temps réel
class RealTimeFeedback {
  final bool success;
  final String? error;
  final List<String> criticalIssues;
  final String? immediateAction;

  RealTimeFeedback({
    required this.success,
    this.error,
    this.criticalIssues = const [],
    this.immediateAction,
  });

  factory RealTimeFeedback.fromJson(Map<String, dynamic> json) {
    if (json['success'] == false) {
      return RealTimeFeedback(
        success: false,
        error: json['error'] ?? 'Erreur inconnue',
      );
    }

    final feedback = json['feedback'] ?? {};
    return RealTimeFeedback(
      success: true,
      criticalIssues: List<String>.from(feedback['critical_issues'] ?? []),
      immediateAction: feedback['immediate_action'],
    );
  }
}

/// Provider pour vérifier la connexion au backend
final backendHealthProvider = FutureProvider<bool>((ref) async {
  return await PoseAnalysisService.checkBackendHealth();
});
