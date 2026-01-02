@echo off
echo ===================================
echo AI Gym Coach - Starting Backend
echo ===================================
echo.

REM Set environment variables directly
set GEMINI_API_KEY=AIzaSyA3W9_sRkV2BPNhrQYgRod9TxW6sSPc5c0
set GEMINI_MODEL=gemini-1.5-flash
set FLASK_HOST=0.0.0.0
set FLASK_PORT=5000
set FLASK_ENV=development
set FLASK_DEBUG=true

echo Environment configured:
echo - Gemini API Key: %GEMINI_API_KEY:~0,20%...
echo - Gemini Model: %GEMINI_MODEL%
echo - Flask Host: %FLASK_HOST%
echo - Flask Port: %FLASK_PORT%
echo.

echo Starting Flask server...
python app.py

pause
