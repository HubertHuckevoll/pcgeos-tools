#!/bin/bash
# Try to build the product

# Build product
rm -r ~/gbuild
cd ~/pcgeos/Tools/build/product/bbxensem/Scripts
perl -I. buildbbx.pl
