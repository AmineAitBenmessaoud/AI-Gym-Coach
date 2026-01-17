"""
Gemini AI Service
Handles Gemini API configuration and model initialization
"""
import google.generativeai as genai
import logging
from config import get_config

logger = logging.getLogger(__name__)

app_config = get_config()

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

logger.info(f"Gemini service initialized with model: {app_config.GEMINI_MODEL}")


def get_model():
    """Get the configured Gemini model instance"""
    return model
