#!/bin/bash
set -euo pipefail

# Build a signed & notarized macOS DMG for MarkdownViewer
# Usage: ./scripts/build-dmg.sh [version]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCHEME="MarkdownViewer"
APP_NAME="MarkdownViewer"
BUNDLE_ID="com.feherkaroly.markdownviewer"

# Version from argument or from project
VERSION="${1:-$(xcodebuild -project "$PROJECT_DIR/MarkdownViewer.xcodeproj" -showBuildSettings 2>/dev/null | awk '/MARKETING_VERSION/ {print $3}')}"

BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_NAME="${APP_NAME}-${VERSION}-macOS"
DMG_PATH="$PROJECT_DIR/dist/$DMG_NAME.dmg"

# Code signing
SIGN_IDENTITY="Developer ID Application: Károly Fehér (YG66KQ8KDT)"
NOTARIZE_PROFILE="notarytool"

echo "==> Building $APP_NAME v${VERSION} DMG installer"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$PROJECT_DIR/dist"

# ── 1. Archive ──────────────────────────────────────────────────────────
echo "==> Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/MarkdownViewer.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -quiet

# ── 2. Export signed app ────────────────────────────────────────────────
echo "==> Exporting signed app..."

EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YG66KQ8KDT</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -quiet

APP_BUNDLE="$EXPORT_DIR/$APP_NAME.app"

echo "==> Verifying signature..."
codesign --verify --verbose "$APP_BUNDLE"

# ── 3. Create DMG ───────────────────────────────────────────────────────
echo "==> Creating DMG..."

rm -f "$DMG_PATH"

APP_ICNS="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
DMG_BG="$SCRIPT_DIR/dmg-background.png"
DMG_BG_2X="$SCRIPT_DIR/dmg-background@2x.png"

DMG_STAGING="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create background folder with both 1x and 2x images
mkdir -p "$DMG_STAGING/.background"
cp "$DMG_BG" "$DMG_STAGING/.background/bg.png"
cp "$DMG_BG_2X" "$DMG_STAGING/.background/bg@2x.png"

DMG_RW="$BUILD_DIR/$DMG_NAME-rw.dmg"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDRW \
    -fs HFS+ \
    -size 20m \
    "$DMG_RW"

# Mount rw image
MOUNT_DIR=$(hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

# Create Finder alias to /Applications and set its icon
echo "==> Creating Applications alias with icon..."
/usr/bin/osascript -e "tell application \"Finder\" to make alias file to POSIX file \"/Applications\" at POSIX file \"$MOUNT_DIR\" with properties {name:\"Applications\"}"
python3 -c "
import Cocoa
ws = Cocoa.NSWorkspace.sharedWorkspace()
icon = ws.iconForFile_('/Applications')
ws.setIcon_forFile_options_(icon, '$MOUNT_DIR/Applications', 0)
print('Applications icon set')
"

# Set volume icon
if [ -f "$APP_ICNS" ]; then
    echo "==> Setting volume icon..."
    cp "$APP_ICNS" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR"
fi

# Generate .DS_Store with background alias (must run on mounted volume)
echo "==> Generating .DS_Store with background..."
python3 "$SCRIPT_DIR/gen-ds-store.py" "$MOUNT_DIR"

sync
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_RW"

# ── 4. Sign DMG ─────────────────────────────────────────────────────────
echo "==> Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH"

# ── 5. Notarize ─────────────────────────────────────────────────────────
echo "==> Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARIZE_PROFILE" --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

# ── 6. Clean up ─────────────────────────────────────────────────────────
rm -rf "$BUILD_DIR"

echo ""
echo "==> Done! Signed & notarized DMG:"
echo "    dist/$DMG_NAME.dmg"
echo ""
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
