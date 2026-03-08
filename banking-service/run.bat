@echo off

echo Starting Bol-Khata Banking Service...

REM Check if Maven is installed
where mvn >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Maven is not installed. Please install Maven first.
    exit /b 1
)

REM Build the project
echo Building project...
call mvn clean install -DskipTests

REM Run the service
echo Starting Banking Service on http://localhost:8080
call mvn spring-boot:run
