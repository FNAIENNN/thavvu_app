#!/bin/bash
set -e

echo "==> Setting up Flutter for Vercel build..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor -v
flutter config --enable-web
flutter pub get
flutter build web --release
