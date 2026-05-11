#!/bin/bash
# Try to build the product

# Cleanup
rm -r ~/gbuild/gfs
rm -r ~/gbuild/image
rm -r ~/gbuild/localpc/ensemble

# Build product
cd ~/pcgeos/Tools/build/product/bbxensem/Scripts
perl -I. buildbbx.pl
