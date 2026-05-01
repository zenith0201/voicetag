#!/bin/bash
set -e
echo "Building VoiceTag..."
swift build -c release
mkdir -p VoiceTag.app/Contents/MacOS
mkdir -p VoiceTag.app/Contents/Resources
cp .build/release/VoiceTag VoiceTag.app/Contents/MacOS/
cp Sources/VoiceTag/Resources/AppIcon.icns VoiceTag.app/Contents/Resources/VoiceTag.icns 2>/dev/null || true
python3 -c "
import plistlib
plist = {
    'CFBundleExecutable': 'VoiceTag',
    'CFBundleIdentifier': 'com.voicetag.app',
    'CFBundleName': 'VoiceTag',
    'CFBundleVersion': '1.0.0',
    'CFBundleShortVersionString': '1.0.0',
    'CFBundlePackageType': 'APPL',
    'CFBundleIconFile': 'VoiceTag',
    'LSMinimumSystemVersion': '14.0',
    'NSMicrophoneUsageDescription': 'VoiceTag uses the microphone to capture your spoken tags.',
    'NSPrincipalClass': 'NSApplication',
    'NSHighResolutionCapable': True,
}
with open('VoiceTag.app/Contents/Info.plist', 'wb') as f:
    plistlib.dump(plist, f)
"
touch VoiceTag.app
killall Dock 2>/dev/null || true
echo "Done!"
