# CoA64 Voices

Quest voice-over ([Living Voices](https://github.com/Crono141/LivingVoices)) and chat read aloud
([Companion Voice](https://github.com/Crono141/CompanionVoice)) for the 64-bit CoA64 client, both by Crono141.

The originals patch the 32-bit stock `Wow.exe` 12340. CoA64 instead loads `Plugins\*.dll` and hands each plugin the
Lua calls by pointer (`plugin/ClientPlugins.h`), so here the same engine is built as a 64-bit plugin,
`Plugins\LivingVoices64.dll`. Its Lua API (`LivingVoices.*`, `CompanionVoiceEngine.*`) is unchanged, so the Living
Voices add-on runs as released.

## What is changed from upstream

- `plugin/LivingVoices.cpp` (Living Voices a6ba85d): no exe patch, no fixed addresses; exports `CoaPlugin_OpenLua`.
  `cv_module.h`, `lv_pack.h`, `lv_splice.h` are unchanged.
- `addons/CompanionVoice` (Companion Voice fcbf63d):
  - say and yell are spoken, from players and from NPCs (each switchable);
  - CoA Custom races get a fitting stock voice (`RaceVoices.lua`; own choices win);
  - AFK Realm writes `AFKDefaults.lua` from its Voices page; a new stamp applies those settings once.

## Install

Through AFK Realm (client → Voices). By hand, into the CoA64 folder:

1. This release: `Plugins\LivingVoices64.dll` and `Interface\AddOns\CompanionVoice`.
2. Companion Voice release zip: only its `Interface\AddOns\CompanionVoice\engine` and `voices` folders (keep this
   repo's Lua files).
3. Living Voices release (`-part1.zip`, `-part2.zip`, 3.6 GB): only its `Interface\AddOns\LivingVoices` folder.
   `LivingVoices.dll` and the patcher are not used on CoA64.

`/lv` and `/cvoice` open the settings. `LivingVoices.log` beside the exe says what the plugin saw.

On a realm with mod-ollama-chat-coa (`OllamaChat.VoiceLabels = 1`), bot lines written by the language model are
labelled, and the group's bots' stock status text stays quiet.

## Build

`plugin/build.sh` (Ubuntu: `g++-mingw-w64-x86-64-posix`, `cmake`); `./package.sh <version>` makes the release zip.
The tag workflow publishes it.

## Licence

GPL-3.0 (`LICENSE`), as Living Voices and Companion Voice. StormLib (MIT) and miniaudio (public domain / MIT-0) are in
`plugin/third_party`. A fan work: not affiliated with, endorsed by or sponsored by Blizzard Entertainment.
