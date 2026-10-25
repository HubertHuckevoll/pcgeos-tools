#!/bin/bash
# Try to build all the geodes and the product

# grab AGENTS.MD
getamd.sh

# Build all the geodes
set -o pipefail
cd ~/pcgeos/Installed
yes | clean
pmake -L 4 2>&1 | tee ~/build.log

# Build product
shinyproduct.sh