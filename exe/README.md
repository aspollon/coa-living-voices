# AFK64.exe with the plugin loader, Lumenveil and Azeroth Remastered

Built from the AFK CoA64 branch for CoA Custom 2.0.2 (`COA-CUSTOM-VERSION.txt`), shipped with ilusixn's permission.
The release ZIP carries `CoA64/CoA64.exe`, `CoA64/Lumenveil64.dll`, `CoA64/Visuals.txt` and `CoA64/VulkanShaders/`;
AFK Realm installs the exe as `AFK64.exe` and puts the others beside it. `VulkanShaders.zip` holds the Vulkan shaders
for Azeroth Remastered, translated from a CoA Custom 2.0 client (a 2.0.2 translation is a subset of it: the same records, so it serves 2.0.2 and a client without CoA Custom alike) plus the 166 vertex shaders of fueryin's Ultra-HD pack (`--merge-into`) (`Tools/VulkanShaders/translate_shaders.py` in CoA64); they replace
the package's own VulkanShaders, which come from another client.
Since CoA64 9bac2d3d the exe runs on Mado's Azeroth Remastered engine (wxl Vulkan backend with FSR 3.1, frame
generation and DLSS). Mado's shaders, `FSR/` and `DLSS/` come from his package, which AFK Realm downloads when Visuals is
3; AFK Realm and AFK Client translate the CoA shaders his set lacks into `Vulkan\shaders\translated\manifest-coa.txt`.
`GraphicsData.zip` holds `forever_data/` (Azeroth Remastered's light, fog, water and grading tables) and
`DBFilesClient/*.cdbc` (Living Azeroth's wind, climate, grass and snow tables), both from Esteria's client; the release
carries them in `CoA64/` and AFK Realm puts them in the game folder beside the exe.

`Visuals.txt`:

```
; 0 = default graphics, 1 = Lumenveil, 2 = LuxVelum, 3 = Azeroth Remastered (Vulkan)
1
```

To update it: build CoA64 (`BuildCoA64.bat`) and Lumenveil (`cmake --build engine-x64`), copy `bin\Win\AFK64.exe`,
`bin\Win\Lumenveil64.dll` and `XvidDecoder.dll` here (the exe as `CoA64.exe`), set the CoA Custom version, commit and
tag a new release. Build Lumenveil from a tag of aspollon/Lumenveil `port/x64` and name that tag in `THIRD_PARTY.txt`, so
the shipped DLL matches its published source.

The device finds a module by the md5 of the shader's bytes, so a set may hold more records than one client uses. A CoA
Custom release that brings a shader none of these has needs a new translation (`Tools/VulkanShaders/Make-VulkanShaders.ps1
-Client <game>`), merged into this set; torn skinned models on Azeroth Remastered usually mean a foreign VulkanShaders
folder replaced this one.
