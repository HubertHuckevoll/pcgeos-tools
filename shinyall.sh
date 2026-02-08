#!/bin/bash
# Try to build all the source

# Build pmake
cd ~/pcgeos/Tools/pmake/pmake
wmake install

# Build all the tools
cd ~/pcgeos/Installed/Tools
pmake install

# Build all the geodes and the product
shinygeodes.sh
