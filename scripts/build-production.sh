#!/bin/bash
# ============================================
# Nol Coffee - Production Build Script
# ============================================

set -e

echo "🚀 Building Nol Coffee POS - Production Release"
echo "================================================"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run build runner (if using code generation)
# echo "🏗️ Running build runner..."
# flutter pub run build_runner build --delete-conflicting-outputs

# Build APK (Android)
echo "📱 Building Android APK..."
flutter build apk \
  --release \
  --flavor production \
  --target-platform android-arm64 \
  --dart-define=ENV=production \
  --dart-define=API_BASE_URL=https://api.nol.coffee

# Build App Bundle (Google Play)
echo "📦 Building Android App Bundle..."
flutter build appbundle \
  --release \
  --flavor production \
  --dart-define=ENV=production \
  --dart-define=API_BASE_URL=https://api.nol.coffee

# Build iOS (requires macOS + Xcode)
# echo "🍎 Building iOS..."
# flutter build ios \
#   --release \
#   --dart-define=ENV=production \
#   --dart-define=API_BASE_URL=https://api.nol.coffee

echo ""
echo "✅ Build Complete!"
echo ""
echo "📁 Output files:"
echo "  - APK: build/app/outputs/flutter-apk/app-production-release.apk"
echo "  - AAB: build/app/outputs/bundle/productionRelease/app-production-release.aab"
echo ""
echo "🚀 Next steps:"
echo "  1. Sign the APK/AAB with your keystore"
echo "  2. Upload to Google Play Console or distribute directly"
echo "  3. Make sure api.nol.coffee is accessible before deploying"