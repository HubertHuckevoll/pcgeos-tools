#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
    echo "Usage: $0"
    echo "Run a full PC/GEOS shiny rebuild in the current Installed/<project> directory."
    exit 0
fi

if [[ $# -ne 0 ]]; then
    echo "error: this script takes no arguments; run it inside Installed/<project>" >&2
    exit 1
fi

if [[ "${PWD}" != *"/Installed/"* ]]; then
    echo "error: run this script only from a project under the Installed subtree" >&2
    exit 1
fi

if [[ ! -f local.mk && ! -f geode.geo && ! -f makefile ]]; then
    echo "error: current directory does not look like a GEOS project folder" >&2
    exit 1
fi

yes | clean
mkmf
pmake depend
pmake -L 4 full
