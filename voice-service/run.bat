@echo off

echo Starting Bol-Khata Voice Service...

REM Check if virtual environment exists
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt

REM Create .env if it doesn't exist
if not exist ".env" (
    echo Creating .env file from example...
    copy .env.example .env
    echo Please edit .env with your API keys
)

REM Run the service
echo Starting Voice Service on http://localhost:8000
python -m app.main
