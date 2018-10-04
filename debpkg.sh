#!/bin/bash

# set failure conditions
set -e
  
# get base directory and make source and package directories
BASEDIR=`dirname $(readlink -f "$0")`

#get file to import package build functions
source $BASEDIR/PKGBUILD || { echo 'No PKGBUILD found' ; exit 1;}
   
srcdir=$BASEDIR/src
pkgdir=$BASEDIR/$pkgname

#clean up source if specified
if [ $1 == "-c" ]
then
	echo "Clearing package and source directories"
	rm -rf  "$pkgdir" "$srcdir"
fi
 
# make directories if necessary
mkdir -p $srcdir $pkgdir
   
# exit if dependencies are not installed
for deps in $depends; do
        text=$(dpkg-query -l *"$deps"*)
        if [ "${text%%:*}" == "dpkg-query" ]; then
                echo "$text dependency is not installed. Exiting."
                exit
        fi
done

# get source files
for url in $source; do

	echo "url = ${url%+*}"
	# check to see if git was specified
	if [ "${url%+*}" == 'git' ]
	then
		# clone git repo or update it		
		master="${url#*+}"
		dir="directory ${url##*/}"
		echo $dir
		if [ -d "$dir" ] 
		then 
			echo "Updating $dir git repo"
			cd "$dir"
			git pull
		else
			echo "Cloning git repo"
			git clone --depth=1 "$master"
		fi
	else	# get file if not a git file
		file="${url##*/}"
        	if [ ! -f $file ]; then
                	wget ${url}
        	fi
	fi
done
  
#verify source package
i=1
echo "verifying integrity"
for url in $source; do
        file="${url##*/}"
        if [ "${sha256sums[i]}" != 'SKIP'  ]; then
                if [ "$(sha256sum $file)" = "${sha256sums[i]}" ]; then
                        echo "$file failed the integrity check."
                fi
        fi
        i=i+1
done
  
#extract files
for url in $source; do
		echo "url = ${url%+*}"
		# check to see if git was specified
		if [ "${url%+*}" == 'git' ]
		then
			# clone git repo or update it		
			master="${url#*+}"
			dir="directory ${url##*/}"
			echo $dir
			if [ -d "$dir" ] 
			then
				#copy to sourcedir
				cp -r $dir $pkgdir/$dir
			fi
		else
			# extract file to directory
			file="${url##*/}"
			echo "Extracting $file to $srcdir"
			tar -xf $file -C $srcdir
		fi
done
  
#run prepare build and package
export MAKEFLAGS=" -j4 "
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

dpkg-deb --verbose  -b $pkgdir 
