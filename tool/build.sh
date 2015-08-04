#!/usr/bin/env bash

# Gets the absolute path of the script (not where it's called from)
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOPDIR=$DIR/..

function usage {
    echo "usage: build [[[-d ] | [-h]]"
}

# process args
debug=0
while [ "$1" != "" ]; do
    case $1 in
        -d | --debug )       	shift
                                debug=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

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

# Build front-end -> build/web
cd $TOPDIR
pub get
if [ $debug == 1 ]; then
	pub build --mode=debug
else
	pub build
fi

# Build back-end -> build/bin
BUILDBIN=$TOPDIR/build/bin
mkdir -p $BUILDBIN
if [ $debug == 1 ]; then
	dart2js --output-type=dart --categories=Server -o $BUILDBIN/main.dart $TOPDIR/bin/main.dart
else
	dart2js --output-type=dart --categories=Server --minify -o $BUILDBIN/main.dart $TOPDIR/bin/main.dart
fi
rm -rf $BUILDBIN/main.dart.deps

# Copy over tabinfo.json -> build/bin
cp $TOPDIR/lib/tabinfo.json $BUILDBIN