# CoA64.exe with the plugin loader

Built from ilusixn/CustomRacesCoa `races-port` plus two commits of branch `voices` (the `Plugins\*.dll` loader and HD
on any renderer), commit 4583808, for CoA Custom 1.9.9 (`COA-CUSTOM-VERSION.txt`). Shipped with ilusixn's permission.
AFK Realm installs it with the voices when the game folder has no CoA64.exe that loads plugins.

To update it: build CoA64 (`BuildCoA64.bat`), copy `bin\Win\CoA64.exe` and `XvidDecoder.dll` here, set the CoA Custom
version, commit and tag a new release.
