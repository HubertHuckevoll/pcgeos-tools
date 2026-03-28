#!/bin/bash
# Try to build all the source and set upd the repo for our purposes

# copy our AGENTS.MD file
cp --force ~/pcgeos-tools/AGENTS.md ~/pcgeos/AGENTS.md

# Build pmake
cd ~/pcgeos/Tools/pmake/pmake
wmake install

# Build all the tools
cd ~/pcgeos/Installed/Tools
pmake install

# Build all the geodes and the product
shinygeodes.sh
