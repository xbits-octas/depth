#!/bin/bash

# Version Bump Script
# Usage: ./version_bump.sh [major|minor|patch]

VERSION_FILE="VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: VERSION file not found"
    exit 1
fi

# Read current version
CURRENT_VERSION=$(cat "$VERSION_FILE")
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"

MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Determine bump type
BUMP_TYPE="${1:-patch}"

case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Error: Invalid bump type. Use 'major', 'minor', or 'patch'"
        exit 1
        ;;
esac

# Format new version (ensure MINOR and PATCH are zero-padded)
NEW_VERSION=$(printf "%d.%02d.%03d" "$MAJOR" "$MINOR" "$PATCH")

# Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"

echo "Version bumped: $CURRENT_VERSION -> $NEW_VERSION"
echo "Don't forget to commit the VERSION file!"
