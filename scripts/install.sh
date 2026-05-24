#!/bin/bash
# SoloFan Quick Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/mohamadlounnas/ffan/main/scripts/install.sh | bash

set -e

REPO="mohamadlounnas/ffan"
APP_NAME="SoloFan"

echo "🌬️  SoloFan Installation"
echo "========================"
echo ""

LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
    echo "❌ Failed to fetch latest version"
    exit 1
fi

VERSION="${LATEST_TAG#v}"
ARCHIVE="solofan-v${VERSION}-macos.zip"

echo "📥 Downloading SoloFan ${LATEST_TAG}..."
curl -L "https://github.com/${REPO}/releases/download/${LATEST_TAG}/${ARCHIVE}" -o "/tmp/${ARCHIVE}"

echo "📦 Extracting..."
cd /tmp
unzip -q "${ARCHIVE}"

echo "🔄 Installing to /Applications..."
rm -rf "/Applications/${APP_NAME}.app"
mv "${APP_NAME}.app" /Applications/

echo "🔧 Installing helper tool (requires password)..."
sudo cp "/Applications/${APP_NAME}.app/Contents/Resources/smc-helper" /usr/local/bin/
sudo chown root:wheel /usr/local/bin/smc-helper
sudo chmod 4755 /usr/local/bin/smc-helper

echo "🧹 Cleaning up..."
rm "/tmp/${ARCHIVE}"

echo ""
echo "✅ Installation complete!"
echo "🚀 Launching SoloFan..."
echo ""

open "/Applications/${APP_NAME}.app"
