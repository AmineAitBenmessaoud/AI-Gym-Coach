import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Service pour communiquer avec le backend et l'API Gemini
class PoseAnalysisService {
  // Change cette URL selon votre configuration (localhost pour dev, IP du serveur pour prod)
  static const String baseUrl = 'http://localhost:5000';
  static const Duration timeout = Duration(seconds: 30);

  // Cache pour éviter trop d'appels API
  static DateTime? _lastAnalysisTime;
  static const Duration _analysisThrottle = Duration(seconds: 2);

  /// Convertit une Pose en JSON pour envoi au backend
  static Map<String, dynamic> _poseToJson(Pose pose) {
    final landmarks = <String, dynamic>{};

    // Optimisation: envoyer seulement les landmarks avec une bonne confiance
    for (var entry in pose.landmarks.entries) {
      final landmark = entry.value;

      // Filter par confiance (>0.5 = bonne détection)
      if (landmark.likelihood > 0.5) {
        landmarks[entry.key.toString().split('.').last] = {
          'x': landmark.x,
          'y': landmark.y,
          'z': landmark.z,
          'confidence': landmark.likelihood,
        };
      }
    }

    return {'landmarks': landmarks};
  }

  /// Envoie les poses au backend pour analyse détaillée
  static Future<Map<String, dynamic>> analyzePoses(
    List<Pose> poses, {
    String? exerciseName,
  }) async {
    try {
      if (poses.isEmpty) {
        return {'success': false, 'error': 'Aucune pose détectée'};
      }

      // Optimisation: prendre seulement la première pose (la plus confiante généralement)
      final posesJson = [_poseToJson(poses.first)];

      final response = await http
          .post(
            Uri.parse('$baseUrl/analyze-poses'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'poses': posesJson,
              if (exerciseName != null) 'exercise': exerciseName,
            }),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        return {
          'success': false,
          'error': 'Erreur serveur: ${response.statusCode} - ${response.body}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Délai d\'attente dépassé. Vérifiez votre connexion.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Erreur de connexion: $e'};
    }
  }

  /// Envoie les poses pour un retour en temps réel
  static Future<Map<String, dynamic>> getRealTimeFeedback(
    List<Pose> poses, {
    required String exerciseName,
  }) async {
    try {
      // Throttling: éviter trop d'appels API
      if (_lastAnalysisTime != null) {
        final timeSinceLastCall = DateTime.now().difference(_lastAnalysisTime!);
        if (timeSinceLastCall < _analysisThrottle) {
          return {'success': false, 'error': 'Throttled'};
        }
      }

      _lastAnalysisTime = DateTime.now();

      if (poses.isEmpty) {
        return {'success': false, 'error': 'Aucune pose détectée'};
      }

      // Optimisation: seulement la première pose pour le temps réel
      final posesJson = [_poseToJson(poses.first)];

      final response = await http
          .post(
            Uri.parse('$baseUrl/real-time-feedback'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'poses': posesJson, 'exercise': exerciseName}),
          )
          .timeout(
            const Duration(seconds: 5),
          ); // Timeout plus court pour le temps réel

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Erreur serveur: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Timeout'};
    } catch (e) {
      return {'success': false, 'error': 'Erreur de connexion: $e'};
    }
  }

  /// Vérifie la connexion avec le backend
  static Future<bool> checkBackendHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(timeout);

      return response.statusCode == 200;
    } catch (e) {
      print('Backend health check failed: $e');
      return false;
    }
  }
}
