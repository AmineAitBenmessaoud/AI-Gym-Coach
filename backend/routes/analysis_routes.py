"""
Analysis Routes
Handles all pose analysis and feedback endpoints
"""
import json
import logging
from flask import Blueprint, request, jsonify
from analyzers import PoseAnalyzer
from services.gemini_service import get_model
from config import get_config

logger = logging.getLogger(__name__)
app_config = get_config()
model = get_model()

# Create blueprint
analysis_bp = Blueprint('analysis', __name__)


@analysis_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "service": "AI Gym Coach Backend",
        "model": app_config.GEMINI_MODEL,
        "version": "2.0"
    })


@analysis_bp.route('/real-time-feedback', methods=['POST'])
def real_time_feedback():
    """
    Endpoint for real-time feedback during exercise
    Provides quick corrections based on current pose
    
    Request body:
    {
        "poses": [pose_objects],
        "exercise": "exercise_name"
    }
    """
    try:
        data = request.get_json()
        poses = data.get('poses', [])
        exercise_name = data.get('exercise', '')
        
        if not poses:
            return jsonify({
                "success": False,
                "error": "No pose data provided"
            }), 400
        
        pose_text = PoseAnalyzer.format_pose_data(poses, exercise_name)
        
        # Create optimized quick feedback prompt
        prompt = f"""You are a real-time fitness coach. Analyze this pose snapshot.

EXERCISE: {exercise_name}

{pose_text}

Provide IMMEDIATE, ACTIONABLE feedback. Focus on the most critical issue RIGHT NOW.

RESPONSE FORMAT (strict JSON):
{{
  "critical_issues": ["issue 1", "issue 2", "issue 3"],
  "immediate_action": "One clear instruction to fix the main problem"
}}

Keep it SHORT and SPECIFIC. Respond ONLY with valid JSON."""
        
        response = model.generate_content(prompt)
        
        try:
            json_text = response.text.strip()
            
            # Remove markdown code blocks
            if "```json" in json_text:
                json_start = json_text.find("```json") + 7
                json_end = json_text.find("```", json_start)
                json_str = json_text[json_start:json_end].strip()
            elif "```" in json_text:
                json_start = json_text.find("```") + 3
                json_end = json_text.rfind("```")
                json_str = json_text[json_start:json_end].strip()
            elif "{" in json_text and "}" in json_text:
                json_start = json_text.find("{")
                json_end = json_text.rfind("}") + 1
                json_str = json_text[json_start:json_end]
            else:
                json_str = json_text
            
            feedback = json.loads(json_str)
            
            # Ensure required fields exist
            if 'critical_issues' not in feedback:
                feedback['critical_issues'] = []
            if 'immediate_action' not in feedback:
                feedback['immediate_action'] = json_text
                
            # Limit to 3 critical issues max
            if len(feedback['critical_issues']) > 3:
                feedback['critical_issues'] = feedback['critical_issues'][:3]
                
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"Real-time feedback JSON parsing failed: {str(e)}")
            feedback = {
                "critical_issues": ["Form check in progress"],
                "immediate_action": response.text.strip()
            }
        
        return jsonify({
            "success": True,
            "feedback": feedback
        })
    
    except Exception as e:
        logger.error(f"Error in /real-time-feedback: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@analysis_bp.route('/analyze-angles', methods=['POST'])
def analyze_angles():
    """
    Analyze exercise with angle data from biomechanics layer
    Receives smoothed angles and detected form issues
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided"
            }), 400
        
        exercise_name = data.get('exercise_name', 'unknown')
        angles = data.get('angles', {})
        form_issues = data.get('form_issues', [])
        
        logger.info(f"Analyzing angles for {exercise_name}: {angles}")
        logger.info(f"Form issues detected: {len(form_issues)} issues")
        
        # Format angles for Gemini
        angles_text = "BIOMECHANICAL ANALYSIS:\n\n"
        angles_text += f"Exercise: {exercise_name}\n\n"
        angles_text += "Current Joint Angles:\n"
        for joint, angle in angles.items():
            if angle is not None:
                angles_text += f"  {joint}: {angle:.1f}°\n"
        
        if form_issues:
            angles_text += "\nDetected Form Issues:\n"
            for issue in form_issues:
                angles_text += f"  - {issue.get('type', 'unknown')}: {issue.get('description', 'No description')}\n"
                angles_text += f"    Severity: {issue.get('severity', 'unknown')}\n"
        
        # Create prompt for Gemini
        prompt = f"""You are an expert biomechanics coach analyzing exercise form.

{angles_text}

Based on these joint angles and detected issues, provide:
1. Assessment of the current form quality
2. Specific corrections needed (if any)
3. Encouragement or advice

RESPONSE FORMAT (strict JSON):
{{
  "form_quality": "excellent/good/needs_improvement/poor",
  "corrections": ["correction 1", "correction 2"],
  "encouragement": "Brief motivational message"
}}

Respond ONLY with valid JSON."""
        
        response = model.generate_content(prompt)
        
        try:
            json_text = response.text.strip()
            
            # Clean JSON from markdown
            if "```json" in json_text:
                json_start = json_text.find("```json") + 7
                json_end = json_text.find("```", json_start)
                json_str = json_text[json_start:json_end].strip()
            elif "```" in json_text:
                json_start = json_text.find("```") + 3
                json_end = json_text.rfind("```")
                json_str = json_text[json_start:json_end].strip()
            else:
                json_start = json_text.find("{")
                json_end = json_text.rfind("}") + 1
                json_str = json_text[json_start:json_end]
            
            analysis = json.loads(json_str)
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"Angles analysis JSON parsing failed: {str(e)}")
            analysis = {
                "form_quality": "needs_improvement",
                "corrections": ["Review the detected form issues"],
                "encouragement": response.text.strip()
            }
        
        return jsonify({
            "success": True,
            "analysis": analysis,
            "angles": angles,
            "form_issues_count": len(form_issues)
        })
    
    except Exception as e:
        logger.error(f"Error in /analyze-angles: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@analysis_bp.route('/analyze-form-issue', methods=['POST'])
def analyze_form_issue():
    """
    Analyze a specific form issue detected by biomechanics layer
    Provides targeted coaching for the detected problem
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                "success": False,
                "error": "No data provided"
            }), 400
        
        exercise_name = data.get('exercise_name', 'unknown')
        issue = data.get('issue', {})
        angles = data.get('angles', {})
        
        issue_type = issue.get('type', 'unknown')
        issue_description = issue.get('description', 'Form issue detected')
        severity = issue.get('severity', 'warning')
        
        logger.info(f"Analyzing form issue: {issue_type} ({severity}) for {exercise_name}")
        
        # Format for Gemini
        issue_text = f"""FORM ISSUE DETECTED:

Exercise: {exercise_name}
Issue Type: {issue_type}
Severity: {severity}
Description: {issue_description}

Current Joint Angles:
"""
        for joint, angle in angles.items():
            if angle is not None:
                issue_text += f"  {joint}: {angle:.1f}°\n"
        
        # Create targeted prompt
        prompt = f"""{issue_text}

As an expert coach, provide IMMEDIATE, SPECIFIC instructions to fix this issue.

RESPONSE FORMAT (strict JSON):
{{
  "quick_fix": "One clear instruction to correct this immediately",
  "why_it_matters": "Brief explanation of the risk/benefit",
  "cue": "Simple mental cue to remember (e.g., 'Chest up', 'Knees out')"
}}

Respond ONLY with valid JSON."""
        
        response = model.generate_content(prompt)
        
        try:
            json_text = response.text.strip()
            
            # Clean JSON
            if "```json" in json_text:
                json_start = json_text.find("```json") + 7
                json_end = json_text.find("```", json_start)
                json_str = json_text[json_start:json_end].strip()
            elif "```" in json_text:
                json_start = json_text.find("```") + 3
                json_end = json_text.rfind("```")
                json_str = json_text[json_start:json_end].strip()
            else:
                json_start = json_text.find("{")
                json_end = json_text.rfind("}") + 1
                json_str = json_text[json_start:json_end]
            
            coaching = json.loads(json_str)
            
        except (json.JSONDecodeError, ValueError) as e:
            logger.warning(f"Form issue JSON parsing failed: {str(e)}")
            coaching = {
                "quick_fix": "Adjust your form based on the detected issue",
                "why_it_matters": "Proper form prevents injury and improves results",
                "cue": response.text.strip()[:50]
            }
        
        return jsonify({
            "success": True,
            "coaching": coaching,
            "issue": issue
        })
    
    except Exception as e:
        logger.error(f"Error in /analyze-form-issue: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500
