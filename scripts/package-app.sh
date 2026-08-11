#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
destination="${1:-$project_root/dist/KindleToPDF.app}"
binary="$project_root/.build/release/kindle-to-pdf"

swift build -c release
mkdir -p "$destination/Contents/MacOS"
cp "$binary" "$destination/Contents/MacOS/kindle-to-pdf"
cp "$project_root/Resources/Info.plist" "$destination/Contents/Info.plist"
codesign --force --sign - "$destination/Contents/MacOS/kindle-to-pdf"
codesign --force --sign - "$destination"
print "$destination"
