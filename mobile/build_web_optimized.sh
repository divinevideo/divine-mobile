#!/bin/bash
# ABOUTME: Build Flutter web with optimizations for faster loading
# ABOUTME: Generates code and builds release web app with tree shaking and PWA support

echo "Building optimized Flutter web app..."

# Clean previous build
flutter clean
flutter pub get

# Generate code (Riverpod providers, Freezed models, etc.)
echo "🔧 Generating code with build_runner..."
dart run build_runner build --delete-conflicting-outputs

# Build with specific optimizations for modern Flutter
flutter build web \
  --release \
  --tree-shake-icons \
  --pwa-strategy=offline-first \
  

# Copy updated headers file to build output
cp web-deploy/_headers build/web/_headers

echo "Build complete! Deploy the build/web directory to Cloudflare."