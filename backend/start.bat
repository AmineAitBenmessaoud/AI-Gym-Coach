@echo off
REM AI Gym Coach Backend Start Script

echo.
echo ======================================
echo AI Gym Coach Backend - Starting...
echo ======================================
echo.

REM Check if virtual environment exists
if not exist venv (
    echo ERROR: Virtual environment not found!
    echo Please run setup.bat first
    pause
    exit /b 1
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Check if .env file exists
if not exist .env (
    echo WARNING: .env file not found!
    echo Please create a .env file with your GEMINI_API_KEY
    echo Copy from .env.example and add your API key
    pause
)

echo Starting Flask server...
echo.
echo ======================================
echo API Server Running
echo ======================================
echo.
echo Endpoints available:
echo   GET  http://localhost:5000/health
echo   POST http://localhost:5000/analyze-poses
echo   POST http://localhost:5000/real-time-feedback
echo.
echo Press Ctrl+C to stop the server
echo ======================================
echo.

python app.py
