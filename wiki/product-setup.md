# Product setup and update markers

The host launcher update and DOS product activation are separate steps.
Both currently use the root `update.txt` marker.

- `~/pcgeos-packaging/templ/ensemble.sh` and `ensemble.cmd` promote the
  pending `BASEBOX/ensemble-run.*.update` files. These wrappers preserve
  `update.txt` for DOS setup when they start the run launcher.
- `~/pcgeos-packaging/templ/basebox.launch.templ.conf` calls `setup.bat`
  before `loader.exe`. The product `SETUP.BAT` selects the build-specific
  `GSETUP` launcher.
- `Tools/build/product/bbxensem/gsetup/gsetup.bat`, labels
  `CHECKDEFAULTINI` and `DEFAULTCHECK`, skips activation when a user INI
  and `GFS.INI` exist and `update.txt` is absent. It does not compare the
  build paths in `GFS.INI` with the selected distribution.
- The same batch file, labels `UPDATEMARKER` and `DOACTIVATE`, uses the
  marker to select activation. The activation payload supplies `GFS.INI`.
  Explicit `ACTIVATE` also selects this phase without a marker.

Deleting the shared marker in a host wrapper prevents automatic
activation of an existing installation. A new Basebox build can run with
the old GEOS build. Launcher promotion must preserve the marker until DOS
setup has used it.

The host wrappers clear `ensemble.log` before launcher promotion. The run
launchers append their startup headers (`write_start_log` in
`ensemble-run.sh`, the startup redirection in `ensemble-run.cmd`). This
keeps promotion messages and runtime output in one log for each normal
launch. Direct calls to the internal run launchers append to the existing
log.

## Version metadata

`Tools/build/product/bbxensem/bbxensem.filetree` places the
`Images/VERSION.TXT` template in `SETUP/ACTIVATE` for FreeGEOS. Other
targets keep the system-core destination (`GFS LOCALPC`). The template
uses `VAR(buildnumber)`, set by `Tools/build/build/var.pl:SetVars` from
`ResolveEnvar("versionTag")` with the leading `BLD` removed. No Git lookup
or timestamp is generated for this file.
`Scripts/buildbbx.pl:GenerateFreeGEOSSetupCopyScripts` generates `GACT.BAT`
from the files under `SETUP/ACTIVATE`. A file added to that payload before
script generation therefore gets an activation copy command automatically.

`~/pcgeos-packaging/pack-ensemble.sh:add_basebox_version` appends
`Basebox Build <number>` to the staged activation file. The number comes
from the detected `BLD<number>` Basebox folder. Packaging requires exactly
one activation version file; older GEOS archives must be rebuilt first.
Plain DOS builds keep the PC/GEOS line without a Basebox line.
