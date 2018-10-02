#!/bin/bash

# set failure conditions
set -e
  
# get base directory and make source and package directories
BASEDIR=`dirname $(readlink -f "$0")`

#get file to import package build functions
source $BASEDIR/PKGBUILD || { echo 'No PKGBUILD found' ; exit 1;}
   
srcdir=$BASEDIR/src
pkgdir=$BASEDIR/$pkgname

echo "Clearing package and source directories"
rm -rf  "$pkgdir" "$srcdir"
 
#rm -rf $srcdir $pkgdir
mkdir -p $srcdir $pkgdir
   
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
export MAKEFLAGS=" -j3 "
#unset error due to msg command not being on debain
set +e
prepare && build && package 
#set error catch again
set -e

unset -n MAKEFLAGS

#actually package the package.
mkdir -p $pkgdir/DEBIAN/

control="$pkgdir/DEBIAN/control"

# butcher control file
printf "Package: $pkgname\nVersion: $pkgver-$pkgrel\nMaintainer: None\nArchitecture: any-x86-64\nDescription: $pkgdesc\n\n" > $control

sleep 1s

dpkg -b $pkgname 
