"""
AI Gym Coach Backend - Flask API
Receives pose data from Flutter frontend and sends it to Google Gemini API for analysis
"""
import logging
from flask import Flask
from flask_cors import CORS
from config import get_config
from routes.analysis_routes import analysis_bp

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

# Register blueprints
app.register_blueprint(analysis_bp)

logger.info(f"Using Gemini model: {app_config.GEMINI_MODEL}")
logger.info(f"Server starting on {app_config.HOST}:{app_config.PORT}")


if __name__ == '__main__':
    app.run(
        debug=False,
        host=app_config.HOST,
        port=app_config.PORT,
        use_reloader=False
    )