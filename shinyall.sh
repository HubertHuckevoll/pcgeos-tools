#!/bin/bash
# Try to build all the source and set up the repo for our purposes

# grab AGENTS.MD
getagentsmd.sh

# Build pmake
cd ~/pcgeos/Tools/pmake/pmake
wmake install

# Build all the tools
cd ~/pcgeos/Installed/Tools
pmake install

# Build all the geodes and the product
shinygeodes.sh
