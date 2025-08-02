#!/bin/bash
# Build a project geode afresh
yes | clean
mkmf
pmake depend
pmake -L 4 full
