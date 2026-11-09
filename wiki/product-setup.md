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

The run launchers also truncate `ensemble.log` in `write_start_log`
(`ensemble-run.sh`) or at startup (`ensemble-run.cmd`). This removes the
promotion messages that the wrappers appended before launch.
