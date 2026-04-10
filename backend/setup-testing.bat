@echo off
REM DropCity Backend Testing Setup Script for Windows
REM This script helps set up your environment for testing

echo.
echo.
echo ============================================
echo DropCity Backend Testing Setup for Windows
echo ============================================
echo.

REM Check if curl is available
curl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: curl not found. Please install Git for Windows or add curl to PATH.
    exit /b 1
)

echo Creating test environment files...
echo.

REM Create .env.test file
echo Creating .env.test file...
(
echo # DropCity Backend Test Environment
echo # Copy values from your actual .env file
echo.
echo DATABASE_URL=postgresql://postgres:password@localhost:5432/dropcity
echo FIREBASE_PROJECT_ID=your-firebase-project
echo FIREBASE_PRIVATE_KEY=your-private-key
echo FIREBASE_CLIENT_EMAIL=your-client-email@iam.gserviceaccount.com
echo.
echo # Alert System
echo SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
echo EMAIL_PROVIDER=sendgrid
echo SENDGRID_API_KEY=SG.your-api-key
echo TWILIO_ACCOUNT_SID=your-account-sid
echo TWILIO_AUTH_TOKEN=your-auth-token
echo TWILIO_PHONE_NUMBER=+1234567890
echo ALERT_PHONE_NUMBER=+0987654321
echo ALERT_EMAIL=alerts@dropcity.io
) > .env.test

echo Created .env.test (update with your values)
echo.

REM Create Postman environment template
echo Creating Postman environment template...
(
echo {
echo   "id": "dropcity-dev-env",
echo   "name": "DropCity Dev",
echo   "values": [
echo     {"key": "base_url", "value": "http://localhost:8080", "enabled": true},
echo     {"key": "base_url_ws", "value": "localhost:8080", "enabled": true},
echo     {"key": "admin_token", "value": "YOUR_ADMIN_TOKEN_HERE", "enabled": true},
echo     {"key": "user_token", "value": "YOUR_USER_TOKEN_HERE", "enabled": true},
echo     {"key": "user_uid", "value": "", "enabled": true},
echo     {"key": "rule_id", "value": "", "enabled": true},
echo     {"key": "parcel_id", "value": "", "enabled": true},
echo     {"key": "courier_uid", "value": "", "enabled": true}
echo   ]
echo }
) > postman-environment-template.json

echo Created postman-environment-template.json
echo.

REM Check if backend is running
echo Checking if backend is running on http://localhost:8080...
curl -s http://localhost:8080/ >nul 2>&1
if %errorlevel% equ 0 (
    echo SUCCESS: Backend is running
) else (
    echo WARNING: Backend not detected on http://localhost:8080
    echo Please start it with: npm start
)
echo.

REM Create batch file with test commands
echo Creating test commands batch file...
(
echo @echo off
echo REM DropCity Backend API Testing Commands
echo REM Set these variables before running:
echo set BASE_URL=http://localhost:8080
echo set ADMIN_TOKEN=your-admin-token-here
echo set USER_TOKEN=your-user-token-here
echo.
echo echo.
echo echo ===========================
echo echo DropCity Backend API Tests
echo echo ===========================
echo echo.
echo.
echo echo 1 Testing API Health...
echo curl -X GET "%BASE_URL%/" ^
echo   -H "Content-Type: application/json"
echo echo.
echo echo.
echo.
echo echo 2 Testing Job Status...
echo curl -X GET "%BASE_URL%/health/jobs" ^
echo   -H "Authorization: Bearer %ADMIN_TOKEN%" ^
echo   -H "Content-Type: application/json"
echo echo.
echo echo.
echo.
echo echo 3 Testing Get Alert Rules...
echo curl -X GET "%BASE_URL%/admin/alerts/rules" ^
echo   -H "Authorization: Bearer %ADMIN_TOKEN%" ^
echo   -H "Content-Type: application/json"
echo echo.
echo echo.
echo.
echo echo 4 Testing Error Summary...
echo curl -X GET "%BASE_URL%/admin/errors/summary?days=7" ^
echo   -H "Authorization: Bearer %ADMIN_TOKEN%" ^
echo   -H "Content-Type: application/json"
echo echo.
echo echo.
echo.
echo echo 5 Testing Create Alert Rule...
echo curl -X POST "%BASE_URL%/admin/alerts/rules" ^
echo   -H "Authorization: Bearer %ADMIN_TOKEN%" ^
echo   -H "Content-Type: application/json" ^
echo   -d "{\"type\": \"error_spike\", \"name\": \"Test\", \"threshold\": 50, \"time_window_minutes\": 30, \"severity\": \"warning\", \"notification_channels\": [\"slack\"]}"
echo echo.
echo echo.
echo.
echo echo Tests complete!
) > test-api-commands.bat

echo Created test-api-commands.bat
echo.

REM Summary
echo.
echo =====================================
echo Setup Complete!
echo =====================================
echo.
echo Files created:
echo   - .env.test
echo   - postman-environment-template.json
echo   - test-api-commands.bat
echo.
echo Next Steps:
echo   1. Update .env.test with your Firebase tokens
echo   2. Import postman-environment-template.json into Postman
echo   3. Import dropcity-api.postman_collection.json into Postman
echo   4. Update collection variables with your tokens
echo   5. Run tests in Postman
echo.
echo Or use the batch file:
echo   1. Edit test-api-commands.bat and set your tokens
echo   2. Run: test-api-commands.bat
echo.
echo Documentation:
echo   - POSTMAN_TESTING_GUIDE.md - Detailed testing instructions
echo   - TESTING_QUICK_START.md - Quick start guide
echo   - ALERTS_SETUP.md - API configuration
echo.
pause
