#!/usr/bin/env bash
# Build Plugins\LivingVoices64.dll for CoA64 (64-bit) with the MinGW-w64 cross compiler (Ubuntu: g++-mingw-w64-x86-64-posix).
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p build
if [[ ! -f build/storm-w64/libStormLib.a ]]; then
    cmake -S third_party/StormLib -B build/storm-w64 -DCMAKE_TOOLCHAIN_FILE="$PWD/third_party/mingw64.cmake" \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DSTORM_SKIP_INSTALL=ON >/dev/null
    cmake --build build/storm-w64 -j"$(nproc)" >/dev/null
fi
x86_64-w64-mingw32-g++ -std=c++17 -O2 -shared -fno-exceptions -fno-rtti -Wall -Wno-unused-function \
    -static -static-libgcc -static-libstdc++ \
    -o build/LivingVoices64.dll LivingVoices.cpp build/storm-w64/libStormLib.a -lole32 -lwinmm -luser32 -lwininet
x86_64-w64-mingw32-strip build/LivingVoices64.dll
ls -la build/LivingVoices64.dll
