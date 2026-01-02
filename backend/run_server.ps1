# AI Gym Coach - Backend Server Startup Script
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "AI Gym Coach - Starting Backend" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Set working directory
Set-Location "c:\Users\Naoufal BENKMIL\Desktop\AI-Gym-Coach\backend"

# Load environment variables from .env file
if (Test-Path ".env") {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Yellow
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Process)
            if ($key -eq "GEMINI_MODEL") {
                Write-Host "  - Model: $value" -ForegroundColor Green
            }
        }
    }
    Write-Host ""
} else {
    Write-Host "Warning: .env file not found!" -ForegroundColor Red
    Write-Host ""
}

# Display configuration
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  - Host: 0.0.0.0" -ForegroundColor White
Write-Host "  - Port: 5000" -ForegroundColor White
Write-Host "  - Model: $env:GEMINI_MODEL" -ForegroundColor White
Write-Host ""

Write-Host "Starting Flask server..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Start the server
python app.py
