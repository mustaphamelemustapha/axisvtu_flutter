#!/bin/bash
FRAMEWORK_EXECUTABLE_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.framework/objective_c"
if [ -f "$FRAMEWORK_EXECUTABLE_PATH" ]; then
    echo "Stripping x86_64 from $FRAMEWORK_EXECUTABLE_PATH"
    lipo -remove x86_64 "$FRAMEWORK_EXECUTABLE_PATH" -o "$FRAMEWORK_EXECUTABLE_PATH" || true
fi
