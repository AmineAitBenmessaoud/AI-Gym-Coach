"""
Configuration file for AI Gym Coach Backend
"""
import os
from typing import Dict, List

class Config:
    """Base configuration"""
    
    # Flask settings
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
    DEBUG = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    HOST = os.getenv('FLASK_HOST', '0.0.0.0')
    PORT = int(os.getenv('FLASK_PORT', '5000'))
    
    # Gemini API settings
    GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
    GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-1.5-flash')
    
    # Generation config
    GENERATION_CONFIG = {
        "temperature": float(os.getenv('GEMINI_TEMPERATURE', '0.7')),
        "top_p": float(os.getenv('GEMINI_TOP_P', '0.95')),
        "top_k": int(os.getenv('GEMINI_TOP_K', '40')),
        "max_output_tokens": int(os.getenv('GEMINI_MAX_TOKENS', '1024')),
    }
    
    # Exercise-specific landmarks mapping
    EXERCISE_LANDMARKS: Dict[str, List[str]] = {
        'squat': [
            'leftHip', 'rightHip', 
            'leftKnee', 'rightKnee', 
            'leftAnkle', 'rightAnkle',
            'leftShoulder', 'rightShoulder'
        ],
        'push-up': [
            'leftShoulder', 'rightShoulder',
            'leftElbow', 'rightElbow',
            'leftWrist', 'rightWrist',
            'leftHip', 'rightHip'
        ],
        'deadlift': [
            'leftHip', 'rightHip',
            'leftKnee', 'rightKnee',
            'leftShoulder', 'rightShoulder',
            'leftAnkle', 'rightAnkle'
        ],
        'bench press': [
            'leftShoulder', 'rightShoulder',
            'leftElbow', 'rightElbow',
            'leftWrist', 'rightWrist'
        ],
        'pull-up': [
            'leftShoulder', 'rightShoulder',
            'leftElbow', 'rightElbow',
            'leftWrist', 'rightWrist',
            'leftHip', 'rightHip'
        ],
        'plank': [
            'leftShoulder', 'rightShoulder',
            'leftElbow', 'rightElbow',
            'leftHip', 'rightHip',
            'leftAnkle', 'rightAnkle'
        ],
        'lunge': [
            'leftHip', 'rightHip',
            'leftKnee', 'rightKnee',
            'leftAnkle', 'rightAnkle',
            'leftShoulder', 'rightShoulder'
        ],
    }
    
    # Confidence threshold for landmarks
    CONFIDENCE_THRESHOLD = float(os.getenv('CONFIDENCE_THRESHOLD', '0.5'))
    
    # CORS settings
    CORS_ORIGINS = os.getenv('CORS_ORIGINS', '*').split(',')


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False


# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'default': DevelopmentConfig
}


def get_config():
    """Get configuration based on environment"""
    env = os.getenv('FLASK_ENV', 'development')
    return config.get(env, config['default'])
