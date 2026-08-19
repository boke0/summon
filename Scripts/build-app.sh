#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.boke0.summon"
APP="$ROOT/dist/Summon.app"

swift build -c release --product summon
BIN="$(swift build -c release --show-bin-path)/summon"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources/plugins"

cp "$BIN" "$APP/Contents/MacOS/Summon"
chmod +x "$APP/Contents/MacOS/Summon"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Summon</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Summon</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSAccessibilityUsageDescription</key>
	<string>Summon lists open application windows and brings the one you select to the front.</string>
</dict>
</plist>
EOF

echo "APPL????" > "$APP/Contents/PkgInfo"

rsync -a --delete --exclude '.DS_Store' \
	"$ROOT/Examples/echo-plugin/" \
	"$APP/Contents/Resources/plugins/echo/"
chmod +x "$APP/Contents/Resources/plugins/echo/bin/"*

# apps and cursor are bash plugins (no Swift binary).
# plugin.json uses ["bin/search"] with CWD = the plugin directory.
install_shell_plugin() {
	local name="$1"
	local dest="$APP/Contents/Resources/plugins/$name"
	rm -rf "$dest"
	mkdir -p "$dest"
	rsync -a --exclude '.DS_Store' "$ROOT/plugins/$name/" "$dest/"
	chmod +x "$dest/bin/"*
}

install_shell_plugin apps
install_shell_plugin cursor
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP/Contents/MacOS/Summon"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"

echo "Built $APP"
