#!/usr/bin/env bash
# Simple smoke test: build the Xcode project to ensure the code compiles
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
PROJECT_NAME="Newgit"
XCODEPROJ="${PROJECT_NAME}.xcodeproj"
SCHEME="${PROJECT_NAME}"

echo "Running smoke test: building ${PROJECT_NAME}..."

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. This test requires Xcode to be installed and the developer tools configured."
  exit 2
fi

# Use xcpretty if available for nicer formatting, but capture xcodebuild exit status reliably
if command -v xcpretty >/dev/null 2>&1; then
  echo "Using xcpretty for prettier output"
  xcodebuild -project "${XCODEPROJ}" -scheme "${SCHEME}" -configuration Debug clean build | xcpretty
  BUILD_STATUS=${PIPESTATUS[0]}
else
  echo "xcpretty not found; running xcodebuild raw"
  xcodebuild -project "${XCODEPROJ}" -scheme "${SCHEME}" -configuration Debug clean build
  BUILD_STATUS=$?
fi

if [ $BUILD_STATUS -eq 0 ]; then
  echo "BUILD SUCCESS"
  exit 0
else
  echo "BUILD FAILED (exit $BUILD_STATUS)"
  exit $BUILD_STATUS
fi
