#!/bin/bash
# Try to build all the geodes and the product

# Build all the geodes
cd ~/pcgeos/Installed
yes | clean
pmake -L 4
pmake -L 4 # hack: do a second run in case pmake failed to resolve all deps

# Build product
shinyproduct.sh