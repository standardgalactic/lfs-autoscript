#!/bin/sh

saveprogress() {
	echo "$tmp" > /savefile.lfs
}

failbuild() {
	echo -e "[!] Failed build! Exiting..."
	exit 3
}

buildtmplibstdcc() {
	saveprogress

	echo "[*] Building Libstdc++..."
	cd /sources/gcc-11.2.0
	ln -s gthr-posix.h libgcc/gthr-default.h
	mkdir -v build
	cd build
	../libstdc++-v3/configure            \
    	CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
    	--prefix=/usr                    \
    	--disable-multilib               \
    	--disable-nls                    \
    	--host=$(uname -m)-lfs-linux-gnu \
    	--disable-libstdcxx-pch 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild

	buildtmpgettext
}

buildtmpgettext() {
	tmp="buildtmpgettext"
	saveprogress

	echo "[*] Building Gettext..."
	cd /sources/gettext-0.21
	make 1>/dev/null || failbuild
	cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin

	buildtmpbison
}

buildtmpbison() {
	tmp="buildtmpbison"
	saveprogress

	echo "[*] Building Bison..."
	cd /sources/bison-3.7.6
	./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.7.6 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild

	buildtmpperl	
}

buildtmpperl() {
	tmp="buildtmpperl"
	saveprogress

	echo "[*] Building Perl..."
	cd /sources/perl-5.34.0
	sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl     \
             -Darchlib=/usr/lib/perl5/5.34/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild
	
	buildtmppython
}

buildtmppython() {
	tmp="buildtmppython"
	saveprogress

	echo "[*] Building Python..."
	cd /sources/python-3.9.6
	./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild

	buildtmptexinfo
}

buildtmptexinfo() {
	tmp="buildtmptexinfo"
	saveprogress
	
	echo "[*] Building Texinfo..."
	cd /source/texinfo-6.8
	sed -e 's/__attribute_nonnull__/__nonnull/' \
    -i gnulib/lib/malloc/dynarray-skeleton.c
	./configure --prefix=/usr 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild

	buildtmputillinux
}

buildtmputillinux() {
	tmp="buildtmputillinux"
	saveprogress

	echo "[*] Building Util-Linux..."
	cd /sources/util-linux-2.37.2
	mkdir -pv /var/lib/hwclock
	./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --docdir=/usr/share/doc/util-linux-2.37.2 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            runstatedir=/run 1>/dev/null || failbuild
	make 1>/dev/null || failbuild
	make install 1>/dev/null || failbuild
}

cleanup() {
	echo "[*] Cleaning Up..."
	rm -rf /usr/share/{info,man,doc}/*
	find /usr/{lib,libexec} -name \*.la -delete
	rm -rf /tools
}

echo " _     ______ _____    ___  _   _ _____ _____ _____ _____ ______ ___________ _____"
echo "| |    |  ___/  ___|  / _ \\| | | |_   _|  _  /  ___/  __ \\| ___ \_   _| ___ \\_   _|"
echo "| |    | |_  \ \`--.  / /_\ \ | | | | | | | | \\ \`--.| /  \\/| |_/ / | | | |_/ / | |"
echo "| |    |  _|  \`--. \ |  _  | | | | | | | | | |\`--. \\ |    |    /  | | |  __/  | |"
echo "| |____| |   /\__/ / | | | | |_| | | | \ \_/ /\__/ / \__/\| |\ \ _| |_| |     | |"
echo "\_____/\_|   \____/  \_| |_/\___/  \_/  \___/\____/ \____/\_| \_|\___/\_|     \_/"
echo "									Stage 2    "
echo "		By @a5tra		    "
echo ""

echo "[*] Creating full folder structure..."
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

echo "[*] Creating Essential Files and Symlinks..."
ln -sv /proc/self/mounts /etc/mtab

cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF

echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group

install -o tester -d /home/tester
exec /bin/bash --login +h

touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

tmp="buildtmplibstdcc"; buildtmplibstdcc


tmp="cleanup"; cleanup