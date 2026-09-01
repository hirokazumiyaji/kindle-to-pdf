#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
mode="${1:-gui}"
destination="${2:-$HOME/Documents/KindleToPDF.app}"

# Old usage: package-app.sh /path/to/Something.app (CLI only)
if [[ $# -ge 1 && "$1" != "gui" && "$1" != "cli" ]]; then
  mode="cli"
  destination="$1"
fi

if [[ "$mode" != "gui" && "$mode" != "cli" ]]; then
  print -u2 "usage: $0 [gui|cli] [destination.app]"
  exit 1
fi

swift build -c release
mkdir -p "$destination/Contents/MacOS"
rm -f "$destination/Contents/MacOS/kindle-to-pdf" "$destination/Contents/MacOS/KindleToPDFApp"

if [[ "$mode" == "cli" ]]; then
  cp "$project_root/.build/release/kindle-to-pdf" "$destination/Contents/MacOS/kindle-to-pdf"
  cp "$project_root/Resources/Info.plist" "$destination/Contents/Info.plist"
  codesign --force --sign - "$destination/Contents/MacOS/kindle-to-pdf"
else
  cp "$project_root/.build/release/KindleToPDFApp" "$destination/Contents/MacOS/KindleToPDFApp"
  cp "$project_root/Resources/AppInfo.plist" "$destination/Contents/Info.plist"
  codesign --force --sign - "$destination/Contents/MacOS/KindleToPDFApp"
fi
codesign --force --sign - "$destination"
print "$destination"
