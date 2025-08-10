#!/bin/bash

# switch to source dir of geode
# this script must be run using the source command:
# source cds BbxBrow

dir=`find $ROOT_DIR/Appl $ROOT_DIR/Library $ROOT_DIR/Driver -type d -name "$1"`
echo Switching to: $dir
cd $dir
