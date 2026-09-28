#!/bin/bash
set -euo pipefail

# ============================================================
# NotchX Build & Package Script
# Creates: Signed NotchX.app bundle + Signed NotchX.dmg installer
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/NotchX.app"
DMG_DIR="$BUILD_DIR/dmg_staging"
DMG_OUTPUT="$BUILD_DIR/NotchX.dmg"

echo "🛑 Stopping any running NotchX instances..."
killall NotchX 2>/dev/null || true
sleep 0.5

echo "🔨 Building NotchX (Release)..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

# Find the release binary
RELEASE_BIN=$(swift build -c release --show-bin-path 2>/dev/null)/NotchX

if [ ! -f "$RELEASE_BIN" ]; then
    echo "❌ Release binary not found at: $RELEASE_BIN"
    exit 1
fi

echo "📦 Creating .app bundle..."

# Clean and recreate app structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the release binary
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/NotchX"
chmod +x "$APP_BUNDLE/Contents/MacOS/NotchX"

# Copy AppIcon.icns and custom assets
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "🎨 AppIcon.icns embedded."
fi
if [ -f "$PROJECT_DIR/Sources/NotchX/Resources/NXMenuIcon@2x.png" ]; then
    cp "$PROJECT_DIR/Sources/NotchX/Resources/NXMenuIcon@2x.png" "$APP_BUNDLE/Contents/Resources/"
fi
if [ -f "$PROJECT_DIR/Sources/NotchX/Resources/NXLogo.png" ]; then
    cp "$PROJECT_DIR/Sources/NotchX/Resources/NXLogo.png" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NotchX</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.vedant.NotchX</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NotchX</string>
    <key>CFBundleDisplayName</key>
    <string>NotchX</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Vedant. All rights reserved.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>NotchX needs AppleScript access to control media and perform system actions.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>NotchX accesses your calendar to display upcoming events and meetings directly in the notch.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>NotchX accesses your calendar to display upcoming events and meetings directly in the notch.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>NotchX monitors microphone status for call controls in the notch.</string>
    <key>NSCameraUsageDescription</key>
    <string>NotchX monitors camera status for call controls in the notch.</string>
    <key>CFBundleGetInfoString</key>
    <string>NotchX 1.0.0, Copyright © 2026 Vedant. All Rights Reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Clean extended attributes (strips quarantine flags)
echo "🧹 Stripping extended quarantine attributes..."
xattr -cr "$APP_BUNDLE"

# Codesign .app bundle with Hardened Runtime & Anti-Tamper Entitlements
echo "🔏 Signing NotchX.app bundle with Hardened Runtime & Anti-Tamper Shield..."
codesign --force --deep --options runtime --entitlements "$PROJECT_DIR/NotchX.entitlements" --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
echo "✅ Code signature & Hardened Runtime verified successfully."

# ============================================================
# Create DMG Installer
# ============================================================
echo "💿 Creating DMG installer..."

# Clean staging
rm -rf "$DMG_DIR"
rm -f "$DMG_OUTPUT"
mkdir -p "$DMG_DIR"

# Copy app bundle to staging
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Set custom volume icon on DMG
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$DMG_DIR/.VolumeIcon.icns"
    SetFile -a C "$DMG_DIR" 2>/dev/null || true
fi

# Create a symlink to /Applications for standard drag-to-install
ln -s /Applications "$DMG_DIR/Applications"

# Copy legal & copyright notices to DMG
cp "$PROJECT_DIR/LICENSE" "$DMG_DIR/LICENSE.txt"
cp "$PROJECT_DIR/COPYRIGHT" "$DMG_DIR/COPYRIGHT.txt"

# Create a 1-Click Launch helper script inside the DMG
cat > "$DMG_DIR/Open NotchX.command" << 'CMD'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "========================================================"
echo "⚡ Starting NotchX by Vedant..."
echo "========================================================"

# Remove quarantine in case macOS flagged downloaded files
if [ -d "/Applications/NotchX.app" ]; then
    xattr -dr com.apple.quarantine /Applications/NotchX.app 2>/dev/null || true
    open /Applications/NotchX.app
elif [ -d "$DIR/NotchX.app" ]; then
    xattr -dr com.apple.quarantine "$DIR/NotchX.app" 2>/dev/null || true
    open "$DIR/NotchX.app"
fi

echo "✅ NotchX is running! Look for the NX icon in your top menu bar."
sleep 1.2
osascript -e 'tell application "Terminal" to close (every window whose name contains "Open NotchX")' &>/dev/null &
exit 0
CMD
chmod +x "$DMG_DIR/Open NotchX.command"

# Create README with clear instructions
cat > "$DMG_DIR/README.txt" << 'README'
============================================================
NotchX — The Definitive MacBook Notch Overlay
Version 1.0.0
Copyright (c) 2026 Vedant. All Rights Reserved.
============================================================

INSTALLATION:
  1. Drag "NotchX.app" directly into the "Applications" folder shortcut.
  2. Double-click "Open NotchX.command" for an instant 1-click launch!
     (Or right-click NotchX.app in Applications -> Open).

HOW IT WORKS:
  - NotchX sits seamlessly under your MacBook camera notch.
  - Hover near the notch or drag any file/folder/photo to open.
  - Click the "NX" icon in your top menu bar for Settings and controls.
  - Features: Live audio routing, per-app volume sliders, 21-day calendar,
    Aural Haptics, microphone privacy veil, and animated wallpapers.

SECURITY & COPYRIGHT:
  - Protected by Hardened Runtime & Anti-Tamper Sentinel.
  - All rights reserved by Vedant. Unauthorized reverse engineering,
    redistribution, or resale is strictly prohibited.
  - See LICENSE.txt and COPYRIGHT.txt for full legal details.

REQUIREMENTS:
  - macOS 14 (Sonoma) or macOS 15 (Sequoia)
  - Apple Silicon MacBook (M1/M2/M3/M4)

Enjoy NotchX!
README

# Create the DMG using hdiutil
hdiutil create \
    -volname "NotchX" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# Sign the DMG container
echo "🔏 Signing DMG..."
codesign --force --sign - "$DMG_OUTPUT"

# Clean up staging
rm -rf "$DMG_DIR"

echo ""
echo "============================================================"
echo "🎉 Build & Packaging Complete!"
echo "============================================================"
echo ""
echo "  📱 App Bundle:  $APP_BUNDLE"
echo "  💿 DMG File:    $DMG_OUTPUT"
echo ""

# Show file sizes
echo "  📏 Binary size: $(du -sh "$APP_BUNDLE/Contents/MacOS/NotchX" | cut -f1)"
echo "  📏 App size:    $(du -sh "$APP_BUNDLE" | cut -f1)"
echo "  📏 DMG size:    $(du -sh "$DMG_OUTPUT" | cut -f1)"
echo ""
echo "  To test DMG:    open $DMG_OUTPUT"
echo "  To run app:     open $APP_BUNDLE"
echo ""
