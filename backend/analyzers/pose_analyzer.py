"""
Pose Analyzer
Analyzes pose data using Gemini API
"""
import json
import logging
from typing import List, Dict
from config import get_config
from services.gemini_service import get_model

logger = logging.getLogger(__name__)
app_config = get_config()
model = get_model()


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
