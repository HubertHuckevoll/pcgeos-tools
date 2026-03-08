---
name: pcgeos-shiny-build
description: Run a clean PC/GEOS geode rebuild in an `Installed/...` project directory using `clean`, `mkmf`, `pmake depend`, and `pmake -L 4 full`. Use when Codex needs to rebuild an app/library/driver from scratch and the working project is under the `Installed` subtree.
---

# PC/GEOS Shiny Build

## Overview

Use this skill to execute the standard shiny rebuild sequence for a PC/GEOS target directory. Prefer the bundled script to keep rebuild steps consistent.

## Workflow

1. Change into the currently worked-on project directory under `Installed` (for example `~/pcgeos/Installed/Appl/BbxBrow`).
2. Run the bundled script from that directory:

```bash
/home/konstantinmeyer/pcgeos-tools/skills/pcgeos-shiny-build/scripts/shiny.sh
```

3. If a step fails, stop and report the exact failing command and output.

## Constraints

- Run this workflow only from a project directory inside `Installed/...`.
- Do not manually create or edit `Makefile` or `dependencies.mk`.
- Let `mkmf` and `pmake depend` generate build files inside the `Installed` subtree as part of the shiny workflow.

## Resource

- `scripts/shiny.sh`: Deterministic wrapper for the shiny rebuild sequence, restricted to `Installed/...` project directories.
