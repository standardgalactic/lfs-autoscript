#!/bin/bash

export LC_ALL=C

re='^[0-9]+$'

red="\e[91m"
blue="\e[94m"
green="\e[92m"
bold="\e[1m"
underline="\e[4m"
reset="\e[0m"

sources="https://www.linuxfromscratch.org/lfs/view/stable/wget-list"
sourcesmd5="https://www.linuxfromscratch.org/lfs/view/stable/md5sums"

programcheck() {
	MYSH=$(readlink -f /bin/sh)
	echo $MYSH | grep -q bash || echo "ERROR: /bin/sh does not point to bash"
	unset MYSH

	if [ $(ld --version 1>/dev/null 2>/dev/null) ]; then echo "binutils not found"; exit 1; fi
	if [ $(bison --version 1>/dev/null 2>/dev/null) ]; then echo "bison not found"; exit 1; fi

	if [ -h /usr/bin/yacc ]; then
		echo "found yacc";
	else
		echo "yacc not found" 
	fi

	if [ $(bzip2 --version 1>/dev/null 2>/dev/null) ]; then echo "bzip2 not found"; exit 1; else echo "found bzip2"; fi
	if [ $(chown --version 1>/dev/null 2>/dev/null) ]; then echo "coreutils not found"; exit 1; else echo "found coreutils"; fi
	if [ $(diff --version 1>/dev/null 2>/dev/null) ]; then echo "diff not found"; exit 1; else echo "found diff"; fi
	if [ $(find --version >/dev/null) ]; then echo "find not found"; exit 1; else echo "found find"; fi
	if [ $(gawk --version 1>/dev/null 2>/dev/null) ]; then echo "gawk not found"; exit 1; else echo "found gawk"; fi

	if [ -h /usr/bin/awk ]; then
		echo "found awk"
	else 
		echo "awk not found" 
	fi

	if [ $(gcc --version 1>/dev/null 2>/dev/null) ]; then echo "gcc not found"; exit 1; else echo "found gcc"; fi
	if [ $(g++ --version 1>/dev/null 2>/dev/null) ]; then echo "g++ not found"; exit 1; else echo "found g++"; fi
	if [ $(ldd --version 1>/dev/null 2>/dev/null) ]; then echo "ldd not found"; exit 1; else echo "found ldd"; fi  # glibc version
	if [ $(grep --version 1>/dev/null 2>/dev/null) ]; then echo "grep not found"; exit 1; else echo "found grep"; fi
	if [ $(gzip --version 1>/dev/null 2>/dev/null) ]; then echo "gzip not found"; exit 1;  else echo "found gzip";fi
	if [ $(m4 --version 1>/dev/null 2>/dev/null) ]; then echo "m4 not found"; exit 1; else echo "found m4"; fi
	if [ $(make --version 1>/dev/null 2>/dev/null) ]; then echo "make not found"; exit 1; else echo "found make"; fi
	if [ $(patch --version 1>/dev/null 2>/dev/null) ]; then echo "patch not found"; exit 1; else echo "found patch"; fi
	if [ $(perl -V:version 1>/dev/null 2>/dev/null) ]; then echo "perl not found"; exit 1; else echo "found perl"; fi
	if [ $(python3 --version 1>/dev/null 2>/dev/null) ]; then echo "python3 not found"; exit 1; else echo "found python3"; fi
	if [ $(sed --version 1>/dev/null 2>/dev/null) ]; then echo "sed not found"; exit 1; else echo "found sed"; fi
	if [ $(tar --version 1>/dev/null 2>/dev/null) ]; then echo "tar not found"; exit 1; else echo "found tar"; fi
	if [ $(makeinfo --version 1>/dev/null 2>/dev/null) ]; then echo "makeinfo not found"; exit 1; else echo "found makeinfo"; fi  # texinfo version
	if [ $(xz --version 1>/dev/null 2>/dev/null) ]; then echo "xz not found"; exit 1; else echo "found xz"; fi
	if [ $(wget --version 1>/dev/null 2>/dev/null) ]; then echo "wget not found"; exit 1; else echo "found wget"; fi

	echo 'int main(){}' > dummy.c && g++ -o dummy dummy.c
	if [ -x dummy ]; then
		echo "g++ compilation OK"
	else
		echo "g++ compilation failed"
		exit 1;
	fi
	rm -f dummy.c dummy
}

askcorrectpart() {
	echo "Boot Partition Size: $bootsize"
	if [ "$doswap" = "y" ]; then
		echo "Swap Partition Size: $swapsize"
	fi
	echo "Root Partition Size: $rootsize"
	echo ""
	read -p "Is this information correct? (Y/n)" tmp

	tmp=$(echo "$tmp" | tr '[:upper:]' '[:lower:]')
	echo $tmp
	if ! [ -z "$tmp" ]; then
		if ! [ "$tmp" = "y" ]; then
			askbootsize
			askswap
			askrootsize
			askcorrectpart
		fi
	fi
}

askbootsize() {
	read -p "Boot Partition size (Default: 200): " bootsize
	if [ -z "$bootsize" ]; then 
		bootsize=200
	else
		if ! [[ $bootsize =~ $re ]] ; then
   			echo -e "$bold$red[!]$reset$red Not a number!"
			askbootsize
		fi
	fi
}

askswapsize() {
	read -p "Swap Partition size (Default: 512): " swapsize
	if [ -z "$swapsize" ]; then 
		swapsize=512
	else
		if ! [[ $swapsize =~ $re ]] ; then
   			echo -e "$bold$red[!]$reset$red Not a number!"
			askswapsize
		fi
	fi
}

askrootsize() {
	read -p "Root Partition size (Default: Rest of the Disk):" rootsize
	if [ -z "$rootsize" ]; then 
		rootusefulldisk=1
	else
		if ! [[ $rootsize =~ $re ]] ; then
   			echo -e "$bold$red[!]$reset$red Not a number!"
			askrootsize
		fi
		rootusefulldisk=0
	fi
}

askswap() {
	read -p "Swap Partition? (Y/n): " tmp
	doswap=$(echo "$tmp" | tr '[:upper:]' '[:lower:]')
	if [ -z "$tmp" ]; then
		doswap="y"
	fi
	if [[ "$doswap" = "y" ]]; then
		askswapsize
	fi
}

askcores() {
	read -p "MAKEOPTS -jX (Default: 2): " tmp
	if ! [[ $tmp =~ $re ]] ; then
		echo -e "$bold$red[!]$reset$red MAKEOPTS must be a number!$reset"
		askcores
	fi
	cores=$tmp
}

failpartition() {
	echo -e "$bold$red[!]$reset$red Failed to partition disk /dev/$diskblock! Exiting...$reset"
	exit 1
}

failformat() {
	echo -e "$bold$red[!]$reset$red Failed to format disk /dev/$diskblock! Exiting...$reset"
	exit 1
}

failmount() {
	echo -e "$bold$red[!]$reset$red Failed to mount disk /dev/$diskblock! Exiting...$reset"
	exit 2
}

faildownload() {
	echo -e "$bold$red[!]$reset$red Failed to download sources! Exiting...$reset"
	exit 2
}

failbuild() {
	echo -e "$bold$red[!]$reset$red Failed build! Exiting...$reset"
	exit 3
}

partitiondisk() {
	echo -e "$bold$blue[*]$reset$blue Partitioning disk...$reset"
	parted -a optimal /dev/$diskblock mklabel gpt || failpartition
	parted -a optimal /dev/$diskblock mkpart primary 0 $bootsize || failpartition
	if [ "$doswap" = "y" ]; then
		 parted -a optimal /dev/$diskblock mkpart primary $(($bootsize+1)) $swapsize 1>/dev/null || failpartition
		if [ $rootusefulldisk -ne 1 ]; then
			parted -a optimal /dev/$diskblock mkpart primary $(($swapsize+1)) $rootsize 1>/dev/null || failpartition
		else
			parted -a optimal /dev/$diskblock mkpart primary $(($swapsize+1)) 100% 1>/dev/null || failpartition
		fi
	else
		if [ $rootusefulldisk -ne 1 ]; then
			parted -a optimal /dev/$diskblock mkpart primary $(($bootsize+1)) $rootsize 1>/dev/null || failpartition
		else
			parted -a optimal /dev/$diskblock mkpart primary $(($bootsize+1)) 100% 1>/dev/null || failpartition
		fi
	fi
}

formatdisk() {
	echo -e "$blod$blue[*]$reset$blue Formatting disk...$reset"
	mkfs.vfat -v -F32 /dev/${diskblock}1 1>/dev/null || failformat
	if [ "$doswap" = "y" ]; then
		mkfs.ext4 -v /dev/${diskblock}3 1>/dev/null || failformat
		mkswap -v /dev/${diskblock}2 1>/dev/null || failformat
		swapon -v /dev/${diskblock}2 1>/dev/null || failformat
	else
		mkfs.ext4 -v /dev/${diskblock}2 1>/dev/null || failformat
	fi
}

echo " _     ______ _____    ___  _   _ _____ _____ _____ _____ ______ ___________ _____"
echo "| |    |  ___/  ___|  / _ \\| | | |_   _|  _  /  ___/  __ \\| ___ \_   _| ___ \\_   _|"
echo "| |    | |_  \ \`--.  / /_\ \ | | | | | | | | \\ \`--.| /  \\/| |_/ / | | | |_/ / | |"
echo "| |    |  _|  \`--. \ |  _  | | | | | | | | | |\`--. \\ |    |    /  | | |  __/  | |"
echo "| |____| |   /\__/ / | | | | |_| | | | \ \_/ /\__/ / \__/\| |\ \ _| |_| |     | |"
echo "\_____/\_|   \____/  \_| |_/\___/  \_/  \___/\____/ \____/\_| \_|\___/\_|     \_/"
echo "					    "
echo -e "		By $bold@a5tra$reset		    "
echo ""

echo -e "$bold$blue[*]$reset$blue Checking for required programs...$reset"
echo ""
programcheck
echo ""

echo -e "$bold$blue[*]$reset$blue Preparing disk...$reset"
echo -e "$bold$blue[*]$reset$blue Partition sizes are in MB$reset"
echo ""
read -p "Disk Block (sdX): " diskblock

askbootsize
askswap
askrootsize
askcorrectpart


echo -e "$bold$red[!]$reset$blue This will destroy all data on your disk!$reset"
read -p "Do you want to continue? (y/N) " tmp
if [ $(echo "$tmp" | tr '[:upper:]' '[:lower:]') == "y" ]; then
	partitiondisk
	formatdisk
else
	echo -e "$bold[.]$reset Exiting..."
	exit 0
fi

echo ""
echo -e "$bold$blue[*]$reset$blue Mounting the filesystem...$reset"
echo ""
read -p "Mountpoint (Default: /mnt/lfs): " tmp
mountpoint=$(echo "$tmp" | tr '[:upper:]' '[:lower:]')
if [ -z $mountpoint ]; then
	mountpoint="/mnt/lfs"
fi
export LFS=$mountpoint
echo -e "$bold$green[ ]$green Mountpoint set to $LFS$reset"
echo ""

mkdir -pv $LFS
if [ "$doswap" = "y" ]; then
	mount -v /dev/${diskblock}3 $LFS 1>/dev/null || failmount
else
	mount -v /dev/${diskblock}2 $LFS 1>/dev/null || failmount
fi
mkdir -pv $LFS/boot
mount -v /dev/${diskblock}1 $LFS/boot 1>/dev/null || failmount

echo ""
echo -e "$bold$blue[*]$reset$blue Downloading sources...$reset"
echo ""
mkdir -v $LFS/sources
mkdir -v $LFS/tools
chmod -v a+wt $LFS/sources

mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
	ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

chown -v $(whoami) $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v $(whoami) $LFS/lib64 ;;
esac

wget $sources 1>/dev/null || faildownload
wget $sourcesmd5 1>/dev/null || faildownload

wget -i wget-list --continue --directory-prefix=$LFS/sources

echo "3518fa864fe8d7ef65be4960f380b03b	binutils-2.37-upstream_fix-1.patch" >> $LFS/sources/md5sums
echo "6a5ac7e89b791aae556de0f745916f7f	bzip2-1.0.8-install_docs-1.patch" >> $LFS/sources/md5sums
echo "cd8ebed2a67fff2e231026df91af6776	coreutils-8.32-i18n-1.patch" >> $LFS/sources/md5sums
echo "9a5997c3452909b1769918c759eff8a2	glibc-2.34-fhs-1.patch" >> $LFS/sources/md5sums
echo "f75cca16a38da6caa7d52151f7136895	kbd-2.4.0-backspace-1.patch" >> $LFS/sources/md5sums
echo "fb42558b59ed95ee00eb9f1c1c9b8056	perl-5.34.0-upstream_fixes-1.patch" >> $LFS/sources/md5sums
echo "4900322141d493e74020c9cf437b2cdc	sysvinit-2.99-consolidated-1.patch" >> $LFS/sources/md5sums

echo -e "$bold$blue[*]$reset$blue Downloading patches...$reset"
wget https://www.linuxfromscratch.org/patches/lfs/11.0/binutils-2.37-upstream_fix-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/bzip2-1.0.8-install_docs-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/coreutils-8.32-i18n-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/glibc-2.34-fhs-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/kbd-2.4.0-backspace-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/perl-5.34.0-upstream_fixes-1.patch --directory-prefix=$LFS/sources
wget https://www.linuxfromscratch.org/patches/lfs/11.0/sysvinit-2.99-consolidated-1.patch --directory-prefix=$LFS/sources

echo ""
echo -e "$bold$blue[*]$reset$blue Validating downloaded files...$reset"
echo ""
pushd $LFS/sources
md5sum -c md5sums
popd

echo ""
echo -e "$bold$blue[*]$reset$blue Final preparations...$reset"
echo ""

if [ ! -e /etc/bash.bashrc ]; then mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE; movedbashrc="y"; fi

askcores
export MAKEOPTS="-j$cores"

echo -e "$bold$green[ ]$reset$green Backing up ~/.bashrc to ~/.bashrc.bak$reset"
echo -e "$bold$green[ ]$reset$green Backing up ~/.bash_profile to ~/.bash_profile.bak$reset"
mv -v ~/.bashrc ~/.bashrc.bak
mv -v ~/.bash_profile ~/.bash_profile.bak

echo "exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash" > ~/.bash_profile

echo "set +h" > ~/.bashrc
echo "umask 022" >> ~/.bashrc
echo "LFS=$LFS" >> ~/.bashrc
echo "LC_ALL=POSIX" >> ~/.bashrc
echo "LFS_TGT=$(uname -m)-lfs-linux-gnu" >> ~/.bashrc
echo "PATH=/usr/bin" >> ~/.bashrc
echo "if [ ! -L /bin ]; then PATH=/bin:$PATH; fi" >> ~/.bashrc
echo "PATH=$LFS/tools/bin:$PATH" >> ~/.bashrc
echo "CONFIG_SITE=$LFS/usr/share/config.site" >> ~/.bashrc
echo "export LFS LC_ALL LFS_TGT PATH CONFIG_SITE" >> ~/.bashrc

source ~/.bash_profile

if [ "$movedbashrc" = "y" ]; then  mv -v /etc/bash.bashrc.NOUSE /etc/bash.bashrc; fi

echo ""
echo -e "$bold$blue[*]$reset$blue Extracting files...$reset"
echo ""
cd $LFS/sources
tar xpvf \*.{xz,gz}

echo ""
echo -e "$bold$blue[*]$reset$blue Compiling binutils (Pass 1)...$reset"
cd binutils-2.37
mkdir build && cd build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --disable-werror 1>/dev/null || failbuild
make 1>/dev/null || failbuild
make install -j1 1>/dev/null || failbuild
cd ../..

echo ""
echo -e "$bold$blue[*]$reset$blue Compiling GCC (Pass 1)...$reset"
cd gcc-11.2.0
tar -xf ../mpfr-4.1.0.tar.xz 1>/dev/null
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz 1>/dev/null
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz 1>/dev/null
mv -v mpc-1.2.1 mpc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
mkdir build && cd build
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=$LFS/tools                            \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++ 1>/dev/null || failbuild
make 1>/dev/null || failbuild
make install 1>/dev/null || failbuild

cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
cd ..

echo ""
echo -e "$bold$blue[*]$reset$blue Compiling Linux API Headers...$reset"
cd linux-5.13.12
make mrproper 1>/dev/null || failbuild
make headers 1>/dev/null || failbuild
find usr/include -name '.*' -delete 1>/dev/null || failbuild
rm usr/include/Makefile
cp -rv usr/include $LFS/usr
cd ..

echo ""
echo -e "$bold$blue[*]$reset$blue Compiling Glibc...$reset"
cd glibc-2.34
case $(uname -m) in
    i?86)   ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3 1>/dev/null || failbuild
    ;;
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64 1>/dev/null || failbuild
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3 1>/dev/null || failbuild
    ;;
esac
patch -Np1 -i ../glibc-2.34-fhs-1.patch 1>/dev/null || failbuild
mkdir build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=$LFS/usr/include    \
      libc_cv_slibdir=/usr/lib 1>/dev/null || failbuild
make 1>/dev/null || failbuild
make DESTDIR=$LFS install
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
if [ $(readelf -l a.out | grep '/ld-linux') = "[Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]" |
	$(readelf -l a.out | grep '/ld-linux') = "[Requesting program interpreter: /lib/ld-linux.so.2]" ]; then
	failbuild
fi
$LFS/tools/libexec/gcc/$LFS_TGT/11.2.0/install-tools/mkheaders
cd ..

echo ""
echo -e "$bold$blue[*]$reset$blue Compiling Libstdc++...$reset"
cd gcc-11.2.0
rm -rf build
mkdir build && cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --build=$(../config.guess)      \
    --prefix=/usr                   \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.2.0 1>/dev/null || failbuild

make 1>/dev/null || failbuild
make DESTDIR=$LFS install 1>/dev/null || failbuild
