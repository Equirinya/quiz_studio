#!/usr/bin/env bash
# Adds Quiz Studio to the app menu and gives it its icon in the dock/taskbar.
#
# GNOME on Wayland ignores the icon a window sets and instead looks for a
# desktop entry named after the app id (de.equirinya.quizStudio), so without
# this the dock shows a generic icon, also for `flutter run -d linux`.
#
# Usage: linux/install-desktop-entry.sh [bundle dir]
#   bundle dir defaults to build/linux/x64/release/bundle, else .../debug/bundle.
# Installs only into ~/.local/share; run it again after moving the bundle.
# Remove with: linux/install-desktop-entry.sh --uninstall
set -euo pipefail

APP_ID="de.equirinya.quizStudio"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$APPS/$APP_ID.desktop" "$ICONS/$APP_ID.png"
  update-desktop-database "$APPS" 2>/dev/null || true
  echo "Removed the Quiz Studio desktop entry."
  exit 0
fi

BUNDLE="${1:-}"
if [[ -z "$BUNDLE" ]]; then
  for b in "$ROOT/build/linux/x64/release/bundle" "$ROOT/build/linux/x64/debug/bundle"; do
    [[ -x "$b/quiz_show" ]] && BUNDLE="$b" && break
  done
fi
if [[ -z "$BUNDLE" || ! -x "$BUNDLE/quiz_show" ]]; then
  echo "No built bundle found. Run 'flutter build linux' first, or pass the bundle dir." >&2
  exit 1
fi
BUNDLE="$(cd "$BUNDLE" && pwd)"

mkdir -p "$APPS" "$ICONS"
install -m 644 "$ROOT/linux/runner/resources/app_icon.png" "$ICONS/$APP_ID.png"
cat > "$APPS/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Quiz Studio
Comment=Build quizzes together and present them on the big screen
Exec="$BUNDLE/quiz_show"
Path=$BUNDLE
Icon=$APP_ID
StartupWMClass=$APP_ID
Categories=Game;
Terminal=false
EOF
update-desktop-database "$APPS" 2>/dev/null || true
gtk-update-icon-cache -q "${ICONS%/256x256/apps}" 2>/dev/null || true
echo "Installed $APPS/$APP_ID.desktop -> $BUNDLE/quiz_show"
