#!/usr/bin/env bash

# Gets the absolute path of the script (not where it's called from)
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOPDIR=$DIR/..

# Check dependencies
command -v pub >/dev/null 2>&1 || {
	echo "FAIL";
	echo "Please install dart-sdk, add bin to PATH, and restart this script. Aborting."
	exit 1;
}

# Get extra assets
cd $TOPDIR/web
if [ ! -d "src-min-noconflict" ]; then
	git clone --quiet https://github.com/ajaxorg/ace-builds.git
	cd ace-builds
	# make sure we're using package 03.03.15
	git checkout --quiet beb9ff68e397b4dcaa1d40f79651a063fc917736
	mv src-min-noconflict ../src-min-noconflict
fi
cd $TOPDIR/web
rm -rf ace-builds

# Run the build
cd $TOPDIR
pub get
pub build