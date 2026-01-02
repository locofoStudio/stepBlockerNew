#!/bin/sh

# Script to copy Hermes framework dSYM to the archive
# This should be added as a "Run Script" build phase in Xcode
# Place it after "Embed Frameworks" phase

set -e

HERMES_FRAMEWORK_PATH="${PODS_ROOT}/hermes-engine/destroot/usr/local/lib/libhermes.dylib"
HERMES_DSYM_PATH="${PODS_ROOT}/hermes-engine/destroot/usr/local/lib/libhermes.dylib.dSYM"

if [ -d "$HERMES_DSYM_PATH" ]; then
    echo "Copying Hermes dSYM to archive..."
    
    # Get the archive path
    ARCHIVE_DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF"
    
    if [ -d "$ARCHIVE_DSYM_PATH" ]; then
        # Copy the Hermes dSYM
        cp -R "$HERMES_DSYM_PATH" "$ARCHIVE_DSYM_PATH/hermes.dSYM"
        echo "Hermes dSYM copied successfully"
    else
        echo "Warning: Archive dSYM path not found: $ARCHIVE_DSYM_PATH"
    fi
else
    echo "Warning: Hermes dSYM not found at: $HERMES_DSYM_PATH"
fi

