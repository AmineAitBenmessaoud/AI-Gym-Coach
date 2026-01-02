"""
AI Gym Coach Backend - Flask API
Receives pose data from Flutter frontend and sends it to Google Gemini API for analysis
"""

from dotenv import load_dotenv
import os

# Load environment variables FIRST before importing config
basedir = os.path.abspath(os.path.dirname(__file__))
load_dotenv(os.path.join(basedir, '.env'))

from flask import Flask, request, jsonify
from flask_cors import CORS
import google.generativeai as genai
import json
from typing import List, Dict
import logging
from config import get_config

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
app_config = get_config()
app.config.from_object(app_config)

# Configure CORS
CORS(app, resources={r"/*": {"origins": app_config.CORS_ORIGINS}})

# Configure Gemini API
GEMINI_API_KEY = app_config.GEMINI_API_KEY
if not GEMINI_API_KEY:
    logger.error("GEMINI_API_KEY not found in environment variables!")
    raise ValueError("GEMINI_API_KEY is required")

genai.configure(api_key=GEMINI_API_KEY)

# Configure Gemini model with optimized settings
generation_config = app_config.GENERATION_CONFIG

safety_settings = [
    {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
    {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
]

model = genai.GenerativeModel(
    model_name=app_config.GEMINI_MODEL,
    generation_config=generation_config,
    safety_settings=safety_settings
)

logger.info(f"Using Gemini model: {app_config.GEMINI_MODEL}")
logger.info(f"Server starting on {app_config.HOST}:{app_config.PORT}")


class PoseAnalyzer:
    """Analyzes pose data using Gemini API"""
    
    # Key landmarks for different exercises (imported from config)
    EXERCISE_LANDMARKS = app_config.EXERCISE_LANDMARKS
    CONFIDENCE_THRESHOLD = app_config.CONFIDENCE_THRESHOLD
    
    @staticmethod
    def format_pose_data(poses: List[Dict], exercise_name: str = None) -> str:
        """
        Format pose data for Gemini analysis
        
        Args:
            poses: List of pose objects from ML Kit
            exercise_name: Optional exercise name to filter relevant landmarks
        
        Returns:
            Formatted string representation of pose data
        """
        formatted = "POSE DATA ANALYSIS:\n\n"
        
        # Get relevant landmarks for the exercise
        relevant_landmarks = PoseAnalyzer.EXERCISE_LANDMARKS.get(
            exercise_name.lower() if exercise_name else None,
            None
        )
        
        for idx, pose in enumerate(poses):
            formatted += f"Person {idx + 1}:\n"
            
            if 'landmarks' in pose:
                landmarks = pose['landmarks']
                
                # Filter landmarks if exercise is specified
                landmarks_to_show = (
                    {k: v for k, v in landmarks.items() if k in relevant_landmarks}
                    if relevant_landmarks
                    else landmarks
                )
                
                for landmark_name, landmark_data in landmarks_to_show.items():
                    if isinstance(landmark_data, dict):
                        x = landmark_data.get('x', 'N/A')
                        y = landmark_data.get('y', 'N/A')
                        z = landmark_data.get('z', 'N/A')
                        confidence = landmark_data.get('confidence', 0)
                        
                        # Only include high-confidence landmarks
                        if isinstance(confidence, (int, float)) and confidence > PoseAnalyzer.CONFIDENCE_THRESHOLD:
                            formatted += f"  • {landmark_name}: x={x:.2f}, y={y:.2f}, z={z:.2f} (conf: {confidence:.2f})\n"
                
                formatted += "\n"
        
        return formatted
    
    @staticmethod
    def analyze_exercise_form(poses: List[Dict], exercise_name: str = None) -> Dict:
        """
        Analyze exercise form using Gemini
        
        Args:
            poses: Pose data from ML Kit
            exercise_name: Optional name of the exercise being performed
        
        Returns:
            Dictionary with analysis results
        """
        try:
            # Format pose data for analysis
            pose_text = PoseAnalyzer.format_pose_data(poses, exercise_name)
            
            # Create optimized prompt for Gemini
            prompt = f"""You are an expert personal trainer and biomechanics specialist analyzing exercise form.

EXERCISE: {exercise_name if exercise_name else "Unknown - identify it"}

{pose_text}

ANALYSIS REQUIRED:
Analyze the body positioning and movement patterns. Provide structured feedback in JSON format.

RESPONSE FORMAT (strict JSON):
{{
  "exercise_name": "identified or confirmed exercise name",
  "form_score": <number 0-10>,
  "issues": ["issue 1", "issue 2", ...],
  "corrections": ["specific correction 1", "specific correction 2", ...],
  "positives": ["positive aspect 1", "positive aspect 2", ...],
  "overall_feedback": "brief summary in 2-3 sentences"
}}

FOCUS ON:
- Joint angles and alignment
- Weight distribution
- Range of motion
- Common form mistakes for this exercise
- Safety considerations

Respond ONLY with valid JSON."""
            
            # Send to Gemini
            response = model.generate_content(prompt)
            
            # Parse response
            response_text = response.text.strip()
            
            # Try to extract JSON from response
            try:
                # Remove markdown code blocks if present
                if "```json" in response_text:
                    json_start = response_text.find("```json") + 7
                    json_end = response_text.find("```", json_start)
                    json_str = response_text[json_start:json_end].strip()
                elif "```" in response_text:
                    json_start = response_text.find("```") + 3
                    json_end = response_text.rfind("```")
                    json_str = response_text[json_start:json_end].strip()
                elif "{" in response_text and "}" in response_text:
                    json_start = response_text.find("{")
                    json_end = response_text.rfind("}") + 1
                    json_str = response_text[json_start:json_end]
                else:
                    json_str = response_text
                
                analysis = json.loads(json_str)
                
                # Validate required fields
                required_fields = ['exercise_name', 'form_score', 'issues', 'corrections', 'positives', 'overall_feedback']
                for field in required_fields:
                    if field not in analysis:
                        analysis[field] = [] if field in ['issues', 'corrections', 'positives'] else ""
                        
            except (json.JSONDecodeError, ValueError) as e:
                logger.warning(f"JSON parsing failed: {str(e)}")
                # If JSON parsing fails, create structured response from text
                analysis = {
                    "exercise_name": exercise_name or "Unknown",
                    "form_score": 5,
                    "issues": ["Unable to parse detailed analysis"],
                    "corrections": ["Review the raw feedback below"],
                    "positives": [],
                    "overall_feedback": response_text,
                    "raw_response": response_text
                }
            
            return {
                "success": True,
                "analysis": analysis
            }
            
        except Exception as e:
            logger.error(f"Error analyzing poses: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "service": "AI Gym Coach Backend",
        "model": app_config.GEMINI_MODEL,
        "version": "2.0"
    })


@app.route('/analyze-poses', methods=['POST'])
def analyze_poses():
    """
    Endpoint to analyze pose data
    
    Request body:
    {
        "poses": [pose_objects_from_mlkit],
        "exercise": "optional_exercise_name"
    }
    """
    try:
        data = request.get_json()
        
        if not data or 'poses' not in data:
            return jsonify({
                "success": False,
                "error": "Missing 'poses' in request body"
            }), 400
        
        poses = data['poses']
        exercise_name = data.get('exercise', None)
        
        if not poses:
            return jsonify({
                "success": False,
                "error": "Poses list is empty"
            }), 400
        
        # Analyze poses
        result = PoseAnalyzer.analyze_exercise_form(poses, exercise_name)
        
        return jsonify(result)
    
    except Exception as e:
        logger.error(f"Error in /analyze-poses: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/real-time-feedback', methods=['POST'])
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


if __name__ == '__main__':
    app.run(
        debug=False,
        host=app_config.HOST,
        port=app_config.PORT,
        use_reloader=False
    )
