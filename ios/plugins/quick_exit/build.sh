#!/usr/bin/env bash
# Rebuild ios/plugins/quick_exit/quick_exit.a (arm64 device, iOS 17+). Commit the .a.
set -euo pipefail
cd "$(dirname "$0")"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun --sdk iphoneos clang++ -c src/quick_exit.mm -o /tmp/quick_exit.o \
  -arch arm64 -isysroot "$SDK" -miphoneos-version-min=17.0 -fobjc-arc -std=c++17 -O2
rm -f quick_exit.a
xcrun --sdk iphoneos libtool -static -o quick_exit.a /tmp/quick_exit.o
xcrun nm -gU quick_exit.a | grep -E "quick_exit_(de)?init" 
