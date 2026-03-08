@echo off

echo Starting Bol-Khata Banking Service with Java 17...

REM Set Java 17 path
set JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%

REM Verify Java version
echo Checking Java version...
java -version

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
echo Starting Banking Service on http://localhost:8081
call mvn spring-boot:run
