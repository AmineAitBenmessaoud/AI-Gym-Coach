@echo off
REM AI Gym Coach Backend Setup Script
REM This script sets up and runs the backend server

echo.
echo ======================================
echo AI Gym Coach - Backend Setup
echo ======================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

echo [1/4] Python found. Creating virtual environment...
if not exist venv (
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
)

echo [2/4] Activating virtual environment...
call venv\Scripts\activate.bat

echo [3/4] Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo [4/4] Setup complete!
echo.
echo ======================================
echo Configuration
echo ======================================
echo.
echo Before running the server:
echo 1. Get your Google Generative AI API key from: https://ai.google.dev/
echo 2. Create a .env file (copy from .env.example)
echo 3. Add your API key to .env:
echo    GEMINI_API_KEY=your_api_key_here
echo.
echo ======================================
echo Ready to Start
echo ======================================
echo.
echo Run the server with:
echo python app.py
echo.
echo The API will be available at: http://localhost:5000
echo.
pause
