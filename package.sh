#!/usr/bin/env bash
# dist/CoA64-Voices-<version>.zip: Plugins\LivingVoices64.dll and the Companion Voice add-on (CoA64 fork).
# The voice data (Living Voices MPQs, Companion Voice engine and voices) comes from the upstream releases; AFK Realm adds it.
set -euo pipefail
cd "$(dirname "$0")"
v="${1:-dev}"
plugin/build.sh
rm -rf dist/stage && mkdir -p dist/stage/Plugins dist/stage/Interface/AddOns
cp plugin/build/LivingVoices64.dll dist/stage/Plugins/
cp -r addons/CompanionVoice dist/stage/Interface/AddOns/
cp LICENSE README.md dist/stage/
(cd dist/stage && rm -f "../CoA64-Voices-$v.zip" && zip -qr "../CoA64-Voices-$v.zip" .)
ls -la "dist/CoA64-Voices-$v.zip"
