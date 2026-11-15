# AFK64.exe with the plugin loader, Lumenveil and Forever

Built from the AFK CoA64 branch for CoA Custom 2.0 (`COA-CUSTOM-VERSION.txt`), shipped with ilusixn's permission.
The release ZIP carries `CoA64/CoA64.exe`, `CoA64/Lumenveil64.dll`, `CoA64/Visuals.txt` and `CoA64/VulkanShaders/`;
AFK Realm installs the exe as `AFK64.exe` and puts the others beside it. `VulkanShaders.zip` holds the Vulkan shaders
for Forever, translated from a CoA Custom 2.0 client (`Tools/VulkanShaders/translate_shaders.py` in CoA64); they replace
the package's own VulkanShaders, which come from another client.

`Visuals.txt`:

```
; 0 = default graphics, 1 = Lumenveil, 2 = LuxVelum, 3 = Forever (Vulkan)
1
```

To update it: build CoA64 (`BuildCoA64.bat`) and Lumenveil (`cmake --build engine-x64`), copy `bin\Win\AFK64.exe`,
`bin\Win\Lumenveil64.dll` and `XvidDecoder.dll` here (the exe as `CoA64.exe`), set the CoA Custom version, commit and
tag a new release. Build Lumenveil from a tag of aspollon/Lumenveil `port/x64` and name that tag in `THIRD_PARTY.txt`, so
the shipped DLL matches its published source.
