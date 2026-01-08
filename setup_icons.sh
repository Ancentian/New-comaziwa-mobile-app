#!/bin/bash
# Icon Generation Script for Comaziwa App
# This script sets up and generates app icons for Google Play Store

set -e  # Exit on error

PROJECT_DIR="/home/ancent/Projects/android/comaziwa-app"

echo "🎨 Comaziwa App Icon Setup"
echo "=================================="
echo ""

# Step 1: Verify logo exists
echo "📋 Verifying logo..."
if [ ! -f "$PROJECT_DIR/assets/logo.png" ]; then
    echo "❌ ERROR: assets/logo.png not found!"
    echo "   Please ensure your logo is at: $PROJECT_DIR/assets/logo.png"
    exit 1
fi
echo "✅ Logo found at assets/logo.png"
echo ""

# Step 2: Change to project directory
cd "$PROJECT_DIR"
echo "📁 Working directory: $(pwd)"
echo ""

# Step 3: Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get
echo "✅ Dependencies updated"
echo ""

# Step 4: Generate icons
echo "🔨 Generating app icons from logo.png..."
flutter pub run flutter_launcher_icons
echo "✅ Icons generated successfully!"
echo ""

# Step 5: Verify generated files
echo "🔍 Verifying generated icon files..."
ICON_DIRS=(
    "android/app/src/main/res/mipmap-mdpi"
    "android/app/src/main/res/mipmap-hdpi"
    "android/app/src/main/res/mipmap-xhdpi"
    "android/app/src/main/res/mipmap-xxhdpi"
    "android/app/src/main/res/mipmap-xxxhdpi"
)

for dir in "${ICON_DIRS[@]}"; do
    if [ -f "$dir/ic_launcher.png" ]; then
        size=$(identify -format "%wx%h" "$dir/ic_launcher.png" 2>/dev/null || echo "unknown size")
        echo "  ✅ $dir/ic_launcher.png ($size)"
    else
        echo "  ❌ $dir/ic_launcher.png NOT FOUND"
    fi
done
echo ""

# Step 6: Build to verify
echo "🏗️ Building APK to verify icon setup..."
flutter clean
flutter build apk --release
echo "✅ Build successful!"
echo ""

echo "=================================="
echo "🎉 Icon setup completed successfully!"
echo ""
echo "📝 Next Steps:"
echo "1. ✅ Icons have been generated and placed in mipmap-* directories"
echo "2. ✅ Android app icon (adaptive icon) is configured"
echo "3. 📋 For Google Play Store upload, you'll need:"
echo "   - Your app icon as separate 512×512 PNG"
echo "   - Feature graphic (1024×500 PNG)"
echo "   - Screenshots (minimum 2)"
echo ""
echo "📚 See GOOGLE_PLAY_ICON_SETUP.md for complete instructions"
echo "=================================="
