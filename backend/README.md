# AI Gym Coach Backend

Flask API backend for analyzing exercise form using pose detection data and Google Gemini 1.5 Flash API.

## ✨ Features

- **Real-time Exercise Analysis**: Instant feedback on exercise form
- **Detailed Form Assessment**: Comprehensive analysis with scores and corrections
- **Multi-Exercise Support**: Squat, Push-up, Deadlift, Bench Press, Pull-up, Plank, Lunge
- **Optimized AI Prompts**: Structured prompts for consistent JSON responses
- **Smart Landmark Filtering**: Focus on relevant body parts per exercise
- **Confidence Thresholding**: Only high-quality pose data processed
- **Configurable Settings**: Easy tuning via environment variables

## 🚀 Quick Start

### 1. Create Virtual Environment
```bash
python -m venv venv
venv\Scripts\activate  # On Windows
source venv/bin/activate  # On macOS/Linux
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure API Key
1. Get your Google Generative AI API key from [ai.google.dev](https://ai.google.dev/)
2. Copy `.env.example` to `.env`
3. Add your API key to `.env`:
```env
GEMINI_API_KEY=your_actual_api_key_here
```

### 4. Run the Server
```bash
# Using the start script (Windows)
start.bat

# Or directly with Python
python app.py
```

The server will run on `http://localhost:5000`

## 📡 API Endpoints

### Health Check
**GET** `/health`

Check if the service is running and view configuration.

**Response:**
```json
{
  "status": "ok",
  "service": "AI Gym Coach Backend",
  "model": "gemini-1.5-flash",
  "version": "2.0"
}
```

### Analyze Poses
**POST** `/analyze-poses`

Analyze pose data and provide detailed form feedback.

**Request Body:**
```json
{
  "poses": [
    {
      "landmarks": {
        "nose": {"x": 100, "y": 50, "z": 0, "confidence": 0.95},
        "leftShoulder": {"x": 80, "y": 100, "z": 0, "confidence": 0.92},
        ...
      }
    }
  ],
  "exercise": "squat"
}
```

**Response:**
```json
{
  "success": true,
  "analysis": {
    "exercise_name": "squat",
    "form_score": 8.5,
    "issues": ["Knees caving slightly inward", "Back rounding at bottom"],
    "corrections": ["Push knees outward aligned with toes", "Maintain neutral spine throughout"],
    "positives": ["Good depth", "Feet positioned well", "Controlled tempo"],
    "overall_feedback": "Solid squat form with minor adjustments needed..."
  }
}
```

### Real-time Feedback
**POST** `/real-time-feedback`

Get quick, critical feedback for real-time coaching.

**Request Body:**
```json
{
  "poses": [...],
  "exercise": "squats"
}
```

**Response:**
```json
{
  "success": true,
  "feedback": {
    "critical_issues": ["Back rounding", "Weight on toes", "Knees caving"],
    "immediate_action": "Straighten your back and shift weight to heels"
  }
}
```

## ⚙️ Configuration

Edit `.env` file to customize settings:

```env
# Model Selection (gemini-1.5-flash, gemini-1.5-pro)
GEMINI_MODEL=gemini-1.5-flash

# Generation Parameters
GEMINI_TEMPERATURE=0.7      # 0.0-1.0 (lower = more consistent)
GEMINI_TOP_P=0.95           # 0.0-1.0 (nucleus sampling)
GEMINI_TOP_K=40             # Top-k sampling
GEMINI_MAX_TOKENS=1024      # Max response length

# Pose Detection
CONFIDENCE_THRESHOLD=0.5    # Min confidence for landmarks (0.0-1.0)

# Server Settings
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=true
```

## 🏋️ Supported Exercises

| Exercise      | Key Landmarks Monitored |
|---------------|------------------------|
| **Squat**     | Hips, Knees, Ankles, Shoulders |
| **Push-up**   | Shoulders, Elbows, Wrists, Hips |
| **Deadlift**  | Hips, Knees, Shoulders, Ankles |
| **Bench Press** | Shoulders, Elbows, Wrists |
| **Pull-up**   | Shoulders, Elbows, Wrists, Hips |
| **Plank**     | Shoulders, Elbows, Hips, Ankles |
| **Lunge**     | Hips, Knees, Ankles, Shoulders |

## 🔧 Architecture

```
Backend Architecture:
├── Flask REST API (CORS enabled)
├── Google Gemini 1.5 Flash
│   ├── Optimized prompts for JSON output
│   ├── Exercise-specific landmark filtering
│   └── Confidence-based data quality
├── Configuration Management (config.py)
└── Error Handling & Logging
```

## 📊 Performance Optimizations

1. **Gemini 1.5 Flash**: Fast responses (~1-2s) with high quality
2. **Landmark Filtering**: Only relevant joints per exercise
3. **Confidence Thresholding**: Filter low-quality detections
4. **Structured Prompts**: Consistent JSON responses
5. **Error Recovery**: Graceful fallbacks for parsing failures

## 🛠️ Development

### Project Structure
```
backend/
├── app.py              # Main Flask application
├── config.py           # Configuration management
├── requirements.txt    # Python dependencies
├── .env               # Environment variables (create from .env.example)
├── setup.bat          # Setup script (Windows)
├── start.bat          # Start script (Windows)
└── README.md          # This file
```

### Adding New Exercises

Edit `config.py` to add new exercise landmarks:

```python
EXERCISE_LANDMARKS = {
    'your_exercise': [
        'relevantLandmark1',
        'relevantLandmark2',
        ...
    ]
}
```

## 🔒 Security Notes

- Never commit `.env` file to version control
- Change `SECRET_KEY` in production
- Use HTTPS in production
- Restrict CORS origins in production (`CORS_ORIGINS=https://yourdomain.com`)
- Secure your Gemini API key

## 📝 Logging

The application logs important events:
- API requests and responses
- Gemini API calls
- Errors and warnings
- Configuration details

Logs include timestamps and log levels (INFO, WARNING, ERROR).

## 🐛 Troubleshooting

**Issue**: `GEMINI_API_KEY not found`
- Solution: Create `.env` file from `.env.example` and add your API key

**Issue**: `Import "flask" could not be resolved`
- Solution: Activate virtual environment and run `pip install -r requirements.txt`

**Issue**: Slow responses
- Solution: Use `gemini-1.5-flash` model, reduce `GEMINI_MAX_TOKENS`

**Issue**: Inconsistent JSON responses
- Solution: Lower `GEMINI_TEMPERATURE` (try 0.5-0.6)

## 📄 License

See LICENSE file in root directory.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test your changes
4. Submit pull request

---

**Version**: 2.0  
**Model**: Google Gemini 1.5 Flash  
**Last Updated**: January 2026

## Setup

### 1. Create Virtual Environment
```bash
python -m venv venv
venv\Scripts\activate  # On Windows
source venv/bin/activate  # On macOS/Linux
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure API Key
1. Get your Google Generative AI API key from [ai.google.dev](https://ai.google.dev/)
2. Copy `.env.example` to `.env`
3. Add your API key to `.env`:
```
GEMINI_API_KEY=your_actual_api_key_here
```

### 4. Run the Server
```bash
python app.py
```

The server will run on `http://localhost:5000`

## API Endpoints

### Health Check
**GET** `/health`

Check if the service is running.

**Response:**
```json
{
  "status": "ok",
  "service": "AI Gym Coach Backend"
}
```

### Analyze Poses
**POST** `/analyze-poses`

Analyze pose data and provide detailed form feedback.

**Request Body:**
```json
{
  "poses": [
    {
      "landmarks": {
        "nose": {"x": 100, "y": 50, "z": 0, "confidence": 0.95},
        "leftShoulder": {"x": 80, "y": 100, "z": 0, "confidence": 0.92},
        ...
      }
    }
  ],
  "exercise": "squat"
}
```

**Response:**
```json
{
  "success": true,
  "analysis": {
    "exercise_name": "squat",
    "form_score": 7.5,
    "issues": ["Back not straight", "Knees caving inward"],
    "corrections": ["Keep your back upright", "Push knees outward"],
    "positives": ["Good depth", "Feet positioned well"],
    "overall_feedback": "..."
  }
}
```

### Real-time Feedback
**POST** `/real-time-feedback`

Get quick, critical feedback for real-time coaching.

**Request Body:**
```json
{
  "poses": [...],
  "exercise": "squats"
}
```

**Response:**
```json
{
  "success": true,
  "feedback": {
    "critical_issues": ["Back rounding", "Weight on toes"],
    "immediate_action": "Straighten your back and shift weight to heels"
  }
}
```

## Architecture

- **Flask**: Web framework for REST API
- **Google Generative AI**: Gemini 3 Pro for pose analysis
- **Flask-CORS**: Enable cross-origin requests from Flutter frontend

## How It Works

1. Flutter app detects pose using ML Kit
2. Pose landmarks are sent to this backend via HTTP
3. Pose data is formatted and sent to Gemini 3 API
4. Gemini analyzes the form and returns feedback
5. Feedback is sent back to Flutter app for display

## Environment

- Python 3.8+
- Flask 3.0.0
- Google Generative AI API access required

## Notes

- Ensure your Flutter app sends poses in the correct format
- The backend formats pose data for Gemini analysis
- Response time depends on Gemini API latency (usually 1-3 seconds)
