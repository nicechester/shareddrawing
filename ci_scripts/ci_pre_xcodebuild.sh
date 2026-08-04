#!/bin/zsh

# Safeguard: Get the repository root path
ROOT_DIR="${CI_PRIMARY_REPOSITORY_PATH:-$CI_WORKSPACE}"

if [ -z "$ROOT_DIR" ]; then
    ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

# Decode and save GoogleService-Info.plist
if [ -n "$GOOGLE_SERVICE_INFO_PLIST" ]; then
    echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 -d > "$ROOT_DIR/GoogleService-Info.plist"
    chmod 644 "$ROOT_DIR/GoogleService-Info.plist"
else
    echo "Error: GOOGLE_SERVICE_INFO_PLIST not set"
    exit 1
fi

# Decode and save Firebase service account key
if [ -n "$FIREBASE_SERVICE_ACCOUNT_KEY" ]; then
    echo "$FIREBASE_SERVICE_ACCOUNT_KEY" | base64 -d > "$ROOT_DIR/shared-drawing-7910b9b25a2d.json"
    chmod 644 "$ROOT_DIR/shared-drawing-7910b9b25a2d.json"
fi