#!/bin/bash
set -e

# Configuration
APP_NAME="AllSet"
APP_PATH="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_TEMP="${APP_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME}"
SOURCE_FOLDER="build/dmg-contents"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: ${APP_PATH} not found. Build the app first with 'make app'"
    exit 1
fi

# Clean up previous builds
rm -rf "$SOURCE_FOLDER"
rm -f "build/${DMG_NAME}"
rm -f "build/${DMG_TEMP}"

# Create source folder for DMG contents
mkdir -p "$SOURCE_FOLDER"

# Copy app to source folder
cp -R "$APP_PATH" "$SOURCE_FOLDER/"

# Create symbolic link to Applications folder
ln -s /Applications "$SOURCE_FOLDER/Applications"

# Create the temporary DMG
echo "Creating temporary DMG..."
hdiutil create -srcfolder "$SOURCE_FOLDER" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 200m \
    "build/${DMG_TEMP}"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "build/${DMG_TEMP}" | grep -E '/Volumes/' | sed 's/.*\t//')

echo "Mounted at: $MOUNT_DIR"

# Set DMG window appearance (optional - requires AppleScript)
echo "Setting DMG appearance..."
echo '
   tell application "Finder"
     tell disk "'${VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 900, 450}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 72
           set position of item "'${APP_NAME}'.app" of container window to {125, 150}
           set position of item "Applications" of container window to {375, 150}
           close
           open
           update without registering applications
           delay 2
     end tell
   end tell
' | osascript || true

# Sync and unmount
sync
echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
echo "Creating final compressed DMG..."
hdiutil convert "build/${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "build/${DMG_NAME}"

# Clean up
rm -f "build/${DMG_TEMP}"
rm -rf "$SOURCE_FOLDER"

echo "✅ DMG created successfully: build/${DMG_NAME}"
ls -lh "build/${DMG_NAME}"
