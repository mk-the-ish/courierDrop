#!/bin/bash

# Admin Dashboard - Build Fix Script

echo "🔧 Fixing build issues..."

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Audit fix for vulnerabilities
echo "🔒 Fixing security vulnerabilities..."
npm audit fix

# Clean build cache
echo "🧹 Cleaning build cache..."
rm -rf .next

# Test build
echo "🏗️  Building for production..."
npm run build

if [ $? -eq 0 ]; then
  echo "✅ Build successful!"
  echo "🚀 Ready for Render deployment"
else
  echo "❌ Build failed"
  exit 1
fi
