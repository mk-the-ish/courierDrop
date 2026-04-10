#!/bin/bash

# DropCity Backend Testing Setup Script
# This script helps set up your environment for Postman testing

echo "🚀 DropCity Backend Testing Setup"
echo "=================================="
echo ""

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "❌ curl not found. Please install curl first."
    exit 1
fi

# Create .env.test file
echo "📝 Creating test environment configuration..."
cat > .env.test << 'EOF'
# DropCity Backend Test Environment
# Copy values from your actual .env file

DATABASE_URL=postgresql://postgres:password@localhost:5432/dropcity
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email@iam.gserviceaccount.com

# Alert System
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.your-api-key
TWILIO_ACCOUNT_SID=your-account-sid
TWILIO_AUTH_TOKEN=your-auth-token
TWILIO_PHONE_NUMBER=+1234567890
ALERT_PHONE_NUMBER=+0987654321
ALERT_EMAIL=alerts@dropcity.io
EOF

echo "✅ Created .env.test file (update with your values)"
echo ""

# Create Postman environment template
echo "📝 Creating Postman environment template..."
cat > postman-environment-template.json << 'EOF'
{
  "id": "dropcity-dev-env",
  "name": "DropCity Dev",
  "values": [
    {
      "key": "base_url",
      "value": "http://localhost:8080",
      "enabled": true
    },
    {
      "key": "base_url_ws",
      "value": "localhost:8080",
      "enabled": true
    },
    {
      "key": "admin_token",
      "value": "YOUR_ADMIN_TOKEN_HERE",
      "enabled": true
    },
    {
      "key": "user_token",
      "value": "YOUR_USER_TOKEN_HERE",
      "enabled": true
    },
    {
      "key": "user_uid",
      "value": "",
      "enabled": true
    },
    {
      "key": "rule_id",
      "value": "",
      "enabled": true
    },
    {
      "key": "parcel_id",
      "value": "",
      "enabled": true
    },
    {
      "key": "courier_uid",
      "value": "",
      "enabled": true
    }
  ],
  "_postman_variable_scope": "environment",
  "_postman_exported_at": "2024-01-15T00:00:00Z",
  "_postman_exported_using": "Postman/latest"
}
EOF

echo "✅ Created postman-environment-template.json"
echo ""

# Check if backend is running
echo "🔍 Checking if backend is running..."
if curl -s http://localhost:8080/ > /dev/null 2>&1; then
    echo "✅ Backend is running on http://localhost:8080"
else
    echo "❌ Backend not detected on http://localhost:8080"
    echo "   Start it with: cd backend && npm start"
fi
echo ""

# Check database
echo "🔍 Checking database..."
if command -v psql &> /dev/null; then
    # Try to connect (this might fail if no DB, which is ok)
    echo "   psql found. You can use: psql -d dropcity to access database"
else
    echo "   psql not found. Install PostgreSQL client to test database."
fi
echo ""

# Create sample curl commands file
echo "📝 Creating sample curl commands..."
cat > test-api-commands.sh << 'EOF'
#!/bin/bash

# DropCity Backend API Testing Commands
# Set these variables before running:
export BASE_URL="http://localhost:8080"
export ADMIN_TOKEN="your-admin-token-here"
export USER_TOKEN="your-user-token-here"

echo "Testing DropCity Backend API"
echo "============================"
echo ""

# Test 1: API Health
echo "1️⃣  Testing API Health..."
curl -X GET "$BASE_URL/" \
  -H "Content-Type: application/json"
echo -e "\n"

# Test 2: Get Job Status
echo "2️⃣  Testing Job Status..."
curl -X GET "$BASE_URL/health/jobs" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"
echo -e "\n"

# Test 3: Get Alert Rules
echo "3️⃣  Testing Get Alert Rules..."
curl -X GET "$BASE_URL/admin/alerts/rules" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"
echo -e "\n"

# Test 4: Create Alert Rule
echo "4️⃣  Testing Create Alert Rule..."
curl -X POST "$BASE_URL/admin/alerts/rules" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "error_spike",
    "name": "Test Alert",
    "threshold": 50,
    "time_window_minutes": 30,
    "severity": "warning",
    "notification_channels": ["slack"]
  }'
echo -e "\n"

# Test 5: Get Error Summary
echo "5️⃣  Testing Error Summary..."
curl -X GET "$BASE_URL/admin/errors/summary?days=7" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json"
echo -e "\n"

# Test 6: Log Test Error
echo "6️⃣  Testing Error Logging..."
curl -X POST "$BASE_URL/logs" \
  -H "Authorization: Bearer $USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Test error from curl",
    "stack": "Error: test\n    at test():1",
    "context": {"test": true}
  }'
echo -e "\n"

echo "✅ Testing complete!"
EOF

chmod +x test-api-commands.sh
echo "✅ Created test-api-commands.sh (make executable: chmod +x test-api-commands.sh)"
echo ""

# Summary
echo "📋 Setup Complete!"
echo "=================="
echo ""
echo "Files created:"
echo "  • .env.test - Environment configuration template"
echo "  • postman-environment-template.json - Postman environment"
echo "  • test-api-commands.sh - Curl test commands"
echo ""
echo "Next steps:"
echo "  1. Update .env.test with your Firebase tokens"
echo "  2. Import postman-environment-template.json into Postman"
echo "  3. Import dropcity-api.postman_collection.json into Postman"
echo "  4. Update collection variables with your tokens"
echo "  5. Run tests in Postman"
echo ""
echo "Or use curl commands:"
echo "  1. Edit test-api-commands.sh and set your tokens"
echo "  2. Run: ./test-api-commands.sh"
echo ""
echo "Documentation:"
echo "  • See POSTMAN_TESTING_GUIDE.md for detailed testing instructions"
echo "  • See ALERTS_SETUP.md for API configuration"
echo ""
