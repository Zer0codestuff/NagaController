#!/usr/bin/env bash
# Builds a distributable DMG: app bundle plus an Applications shortcut.
# The app is ad-hoc signed by default because a local development identity
# means nothing on other Macs. Not notarized: first launch needs right-click
# > Open, or: xattr -dr com.apple.quarantine /Applications/NagaController.app
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/NagaController.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/Resources/Info.plist")"
DMG="${1:-$PROJECT_ROOT/NagaController-v$VERSION.dmg}"

SIGNING_IDENTITY="${SIGNING_IDENTITY:--}" bash "$PROJECT_ROOT/Scripts/build_app.sh"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP_BUNDLE" "$STAGING/NagaController.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "NagaController $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
hdiutil verify -quiet "$DMG"
printf 'DMG: %s\n' "$DMG"
shasum -a 256 "$DMG"
