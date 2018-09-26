#!/bin/bash

#aliases for makepkg functions
alias msg="echo "

# get base directory and make source and package directories
BASEDIR=`dirname $(readlink -f "$0")`

srcdir=$BASEDIR/src
pkgdir=$BASEDIR/pkg
mkdir -p $srcdir $pkgdir 

#get file to import package build functions
source $BASEDIR/PKGBUILD

#check for dependencies
for deps in $depends; do
	text=$(dpkg-query -l *"$deps"*)
	if [ "${text%%:*}" == "dpkg-query" ]; then
		echo "$text dependency is not installed. Exiting."
		exit
	fi
done

# get source files
for url in $source; do
	file="${url##*/}"
	if [ ! -f $file ]; then
		wget ${url}
	fi	
done

#verify source package
i=1
echo "verifying integrity"
for srcpkg in $source; do
	file="${url##*/}"
	if [ "${sha256sums[i]}" = 'SKIP'  ]; then
		if [ "$(sha256sum $file)" = "${sha256sums[i]}" ]; then
			echo "$file failed the integrity check."
		fi
	fi	
	i=i+1
done

#extract files
for srcpkg in $source; do
	file="${url##*/}"
	echo "Extracting $file to $srcdir"
	tar -xf $file -C $srcdir
done

#run prepare build and package
prepare
build
package	

#actually package the package.
#mkdir -p $srcdir/DEBIAN
#dpkg-deb --build 




