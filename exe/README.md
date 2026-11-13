# AFK64.exe with the plugin loader and Lumenveil

Built from the AFK CoA64 branch for CoA Custom 2.0 (`COA-CUSTOM-VERSION.txt`), shipped with ilusixn's permission.
The release ZIP carries `CoA64/AFK64.exe`, `Lumenveil64.dll` and `Visuals.txt`; AFK Realm puts them in place.

`Visuals.txt`:

```
; 0 = default graphics, 1 = Lumenveil, 2 = LuxVelum
1
```

To update it: build CoA64 (`BuildCoA64.bat`) and Lumenveil (`cmake --build engine-x64`), copy `bin\Win\AFK64.exe`,
`bin\Win\Lumenveil64.dll` and `XvidDecoder.dll` here, set the CoA Custom version, commit and tag a new release.
