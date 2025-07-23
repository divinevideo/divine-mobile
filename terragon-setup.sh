#!/bin/bash

set -e  # Exit on error

echo "🔧 Setting up Flutter development environment..."

# 1. Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y curl git unzip xz-utils libglu1-mesa

# 2. Install Flutter SDK
echo "⬇️ Downloading Flutter SDK..."
FLUTTER_VERSION="3.22.1"
FLUTTER_TAR="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

curl -sSOL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TAR}"
tar xf "${FLUTTER_TAR}"

# 3. Export Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Optional: persist PATH across script calls (not always effective in ephemeral sandboxes)
echo 'export PATH="$PWD/flutter/bin:$PATH"' >> ~/.bashrc

# 4. Pre-cache dependencies
echo "📦 Pre-caching Flutter dependencies..."
flutter doctor --verbose
flutter precache

# 5. Enable Linux desktop (optional)
# flutter config --enable-linux-desktop

# 6. Install project dependencies
echo "📦 Running flutter pub get..."
flutter pub get

# 7. (Optional) Run codegen if using build_runner
# echo "🏗️ Running build_runner..."
# flutter pub run build_runner build --delete-conflicting-outputs

echo "✅ Flutter setup complete and ready to go!"