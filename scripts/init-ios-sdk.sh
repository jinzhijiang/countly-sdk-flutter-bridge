#!/bin/bash

### CONFIGURATION ###
SUBMODULE_PATH="ios/Classes/countly-sdk-ios"
TAG="${1:-25.4.7}"   # default tag if none given
MAIN_SPARSE_FILE="../../../scripts/sparse-checkout.list"  # relative path from submodule

echo "🔧 Initializing Countly iOS SDK submodule..."
echo "   Tag: $TAG"
echo "   Path: $SUBMODULE_PATH"
echo ""

# Ensure submodule exists
git submodule update --init --recursive $SUBMODULE_PATH

cd "$SUBMODULE_PATH" || { echo "❌ Failed to enter submodule path."; exit 1; }

# Fetch & checkout tag
echo "📥 Checking out tag $TAG..."
git fetch --all --tags
git checkout "$TAG" || { echo "❌ Tag not found: $TAG"; exit 1; }

# Ensure the main sparse-checkout file exists in the Flutter repo
if [ ! -f "$MAIN_SPARSE_FILE" ]; then
    echo "❌ Missing sparse-checkout rules at: scripts/sparse-checkout.list"
    exit 1
fi

echo "🧹 Applying sparse-checkout rules from: scripts/sparse-checkout.list"

# Initialize sparse checkout (non-cone mode)
git sparse-checkout init --no-cone

# Apply the rules inside Git internals
cp "$MAIN_SPARSE_FILE" "$(git rev-parse --git-path info)/sparse-checkout"

# Apply to working tree
git read-tree -mu HEAD

echo ""
echo "✅ Countly iOS SDK initialized"
echo "   → Tag: $TAG"
echo "   → Sparse checkout applied using scripts/sparse-checkout.list"

