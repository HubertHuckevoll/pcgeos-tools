#!/bin/bash
# copy local Codex/developer helpers into the PC/GEOS checkout

cp --force ~/pcgeos-tools/AGENTS.md ~/pcgeos/AGENTS.md
cp --force ~/pcgeos-tools/target-codex ~/pcgeos/bin/target-codex
cp --force ~/pcgeos-tools/codex.tcl ~/pcgeos/Tools/swat/lib.new/codex.tcl
chmod +x ~/pcgeos/bin/target-codex
