#!/bin/sh

# Script to generate Hermes framework dSYM for App Store submission
# This should be added as a "Run Script" build phase in Xcode
# Place it after "Embed Frameworks" phase

# Path of the Hermes binary that was linked into your app
HERMES_BIN="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/hermes.framework/hermes"

# Where Xcode expects the dSYM for this build configuration
HERMES_DSYM="${DWARF_DSYM_FOLDER_PATH}/hermes.framework.dSYM"

# Only run dsymutil if the dSYM isn't there yet
if [ -f "$HERMES_BIN" ] && [ ! -d "$HERMES_DSYM" ]; then
    echo "🛠  Generating dSYM for Hermes..."
    if /usr/bin/dsymutil "$HERMES_BIN" -o "$HERMES_DSYM" 2>&1; then
        echo "✅ Hermes dSYM generated successfully"
    else
        echo "⚠️  Warning: Failed to generate Hermes dSYM, but continuing build..."
        exit 0
    fi
elif [ -d "$HERMES_DSYM" ]; then
    echo "ℹ️  Hermes dSYM already exists"
elif [ ! -f "$HERMES_BIN" ]; then
    echo "ℹ️  Hermes binary not found at: $HERMES_BIN (this is normal if Hermes is not used)"
    exit 0
else
    echo "ℹ️  Skipping Hermes dSYM generation"
    exit 0
fi

