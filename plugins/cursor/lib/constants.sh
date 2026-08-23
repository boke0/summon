CURSOR_BUNDLE_ID="com.todesktop.230313mzl4w4u92"
CURSOR_APP="/Applications/Cursor.app"
CURSOR_CLI="$CURSOR_APP/Contents/Resources/app/bin/cursor"
CURSOR_MENU_RETRY=50
CURSOR_MENU_INTERVAL=0.1

# File titles depend on whether the Agents (glass) window already exists.
# Window > Cursor Agents is the window-list item, used only as a last fallback.
CURSOR_AGENTS_MENUS=(
	$'File\tSwitch to Agents Window'
	$'File\tNew Agents Window'
	$'Window\tCursor Agents'
)
