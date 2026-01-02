#!/bin/bash

# Clean Xcode build artifacts and caches
echo "Cleaning Xcode build folder..."
cd "$(dirname "$0")"
xcodebuild clean -workspace StepBlocker.xcworkspace -scheme StepBlocker 2>/dev/null || echo "Note: Clean may have failed, but continuing..."

echo "Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/StepBlocker-* 2>/dev/null
rm -rf ~/Library/Developer/Xcode/DerivedData/*StepBlocker* 2>/dev/null

echo "Removing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex 2>/dev/null

echo "Done! Please close and reopen Xcode, then try building again."

