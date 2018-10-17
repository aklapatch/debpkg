#!/bin/bash

# TODO add md5sum verification

#get pkgbuild from AUR
if [[ "$1" != "" && "$1" != "-c"  ]]; then
	git clone --depth=1 "https://aur.archlinux.org/$1.git" recipe
	mv -f recipe/PKGBUILD ./PKGBUILD
	rm -rf recipe
fi
# set failure conditions
set -e
  
# get base directory and make source and package directories
BASEDIR=`dirname $(readlink -f "$0")`

#get file to import package build functions
source $BASEDIR/PKGBUILD || { echo 'No PKGBUILD found' ; exit 1;}
   
srcdir=$BASEDIR/src
pkgdir=$BASEDIR/pkg

#clean up source if specified
if [[ "$1" == "-c" || "$2"=="-c" || "$3"=="-c"  ]]
then
	echo "Clearing package and source directories"
	rm -rf  "$pkgdir" "$srcdir" "$BASEDIR/$pkgname"
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
for src in $source; do

	# check to see if git was specified
	if [ "${src%+*}" == 'git' ]
	then
		# clone git repo or update it		
		master="${src#*+}"
		dir="directory ${src##*/}"
		
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
		file="${src##*/}"
        	if [ ! -f $file ]; then
                	wget ${src}
        	fi
	fi
done
  
#verify source package
i=1
echo "Verifying file integrity"
for src in $source; do
        file="${src##*/}"
        if [ "${sha256sums[$i]}" != 'SKIP'  ]; then
				 
                if [ "$(sha256sum $file)" = "${sha256sums[$i]}" ]; then
                        echo "$file failed the integrity check."
                fi
        fi
        i=$i+1
done
  
#extract files
for src in $source; do
		
		# check to see if git was specified
		if [ "${src%+*}" == 'git' ]
		then
			# clone git repo or update it		
			master="${src#*+}"
			dir="directory ${src##*/}"
			
			if [ -d "$dir" ] 
			then
				#copy to sourcedir
				cp -r $dir $srcdir/$dir
			fi
		else
			# extract file to directory
			file="${src##*/}"
			echo "Extracting $file to $srcdir"
			tar -xf $file -C $srcdir
		fi
done
  
# set up flags to build
export MAKEFLAGS="-j4"
export CFLAGS="-march=native -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

#unset error due to msg command not being on debain
set +e

# Run through PKGBUILD functions
prepare
build
cd $srcdir
package 
cd $srcdir

#set error catch again
set -e

#unset build flags
unset -n MAKEFLAGS
unset -n CFLAGS
unset -n CXXFLAGS

# move files to pkgdir and ready package directory
cd $BASEDIR
mkdir -p $pkgname
cd $pkgdir
cp -r * "$BASEDIR/$pkgname"
cd $BASEDIR
mkdir -p $pkgname/DEBIAN/

control="$pkgname/DEBIAN/control"

# butcher control file from PKGBUILD info
printf "Package: $pkgname\nVersion: $pkgver-$pkgrel\nMaintainer: None\nArchitecture: amd64\nDescription: $pkgdesc\n" > $control

# add conflicts info to control file
printf "Conflicts: " >> $control

for con in $conflicts; do
	printf "$con " >> $control
done
printf "\n" >> $control

# add url to control file
printf "Homepage: " >> $control

for addr in $url; do
	echo $addr
	printf "$addr " >> $control
done
printf "\n" >> $control

# package final product
dpkg-deb --verbose  -b $pkgname 
