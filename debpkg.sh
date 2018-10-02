#!/bin/bash

# set failure conditions
set -e
  
#aliases for makepkg functions
alias msg="echo "

# get base directory and make source and package directories
BASEDIR=`dirname $(readlink -f "$0")`

#get file to import package build functions
source $BASEDIR/PKGBUILD || { echo 'No PKGBUILD found' ; exit 1;}
 
echo $BASEDIR

  
srcdir=$BASEDIR/src
pkgdir=$BASEDIR/$pkgname

echo "Cleaning up package directories."
rm -rf  $pkgdir
 
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
prepare 
build 
package 
        
#actually package the package.
mkdir -p $pkgdir/DEBIAN

# butcher control file
printf "Package: %s \nVersion: %s \nMaintainer: None \nArchitecture: any-x86-64 \nDescription: %s \n" "$pkgname" "$pkgver-$pkgrel"  "$pkgdesc" > $pkgdir/DEBIAN/control

dpkg-deb --build $pkgname               
