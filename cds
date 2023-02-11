#!/bin/bash

# this script must be run using the source command:
# source cds BbxBrow

dir=`find $ROOT_DIR/Appl -type d -name "$1"`
echo Switching to: $dir
cd $dir
