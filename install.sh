#!/bin/bash

sdcard="/dev/sdb"					# Set the sdcard
mac="00CE39B6F42D"					# Without the -.... just the digits
hostname="mele"						# Set the hostname
builddir="/usr/local/src/mele"		# Set the building directory
uboot="sun4i"						# Set the desired u-boot version. See here: https://github.com/hno/uboot-allwinner/wiki
kernel="allwinner-v3.0-android-v2"	# Select the desired kernel branch. See here: http://rhombus-tech.net/allwinner_a10/kernel_compile/
network="static"					# Either static or dhcp
networkbase="192.168.1"				# Set first three octets
networkip="71"						# Set final octet
server="y"							# y or n / enable server mode? Deactivate GPU and free ram
misdn="y"							# y or n / add mISDN module to kernel
tun="y"								# y or n / also compile the tun module - required for openvpn
password="password"					# set root password in the sdcard
locales="en_US.UTF-8"				# set your locales
debian="wheezy"						# Set your Debian version
arm="armhf"							# Set armel or armhf (armhf only for wheezy)


# More info at http://rhombus-tech.net/allwinner_a10/source_code/
# More debian specific info at http://rhombus-tech.net/allwinner_a10/hacking_the_mele_a1000/Building_Debian_From_Source_Code_for_Mele/


##############################################################################
#                                                                            #
#                            BELOW BE DRAGONS                                #
#                                                                            #
##############################################################################

function updateSettings
{
        File="$1"
        Pattern="$2"
        Replace="$3"

        if grep "${Pattern}" "${File}" >/dev/null;
        then
                # Pattern found, replace line
                sed -i s/.*"${Pattern}".*/"${Replace}"/g "${File}"
                echo ""
        else
                # Pattern not found, append new
                echo "${Replace}" >> "${File}"
        fi
}



function initializeFunc
{
	# Prepare environment, download necessary packages
	apt-get update
	apt-get -y dist-upgrade
	apt-get -y install git-core gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf build-essential qemu qemu-user-static util-linux uboot-mkimage
	mkdir -p ${builddir}
}



function ubootFunc
{
	curDir="${builddir}/uboot-allwinner"
	if [ ! -d "${curDir}" ]; then
		cd ${builddir}
		git clone git://github.com/hno/uboot-allwinner.git
	fi
	cd ${curDir}
	git checkout ${uboot}
	make ${uboot} CROSS_COMPILE=arm-linux-gnueabi${hf}-
	echo "Done building u-boot"
}



function scriptFunc
{
	curDir="${builddir}/sunxi-tools"
	if [ ! -d "${curDir}" ]; then
		cd ${builddir}
		git clone https://github.com/amery/sunxi-tools
	fi

	cd ${curDir}
	make
	curDir="${builddir}/scriptbin"
	if [ ! -d "${curDir}" ]; then
		mkdir ${curDir}
	fi
	wget "http://rhombus-tech.net/allwinner_a10/hacking_the_mele_a1000/sys_config1.fex" -O "${curDir}/non-server.fex"
	wget "https://raw.github.com/cnxsoft/a10-config/master/script.fex/mele-a1000-server.fex" -O "${curDir}/server.fex"

	cd ${curDir}
	rm "${curDir}/myscript.fex"
	case "${server}" in
	n)	echo "Getting non-server fex"
		cp "${curDir}/non-server.fex" "${curDir}/myscript.fex"
		;;
	*)	echo "Getting server fex"
		cp "${curDir}/server.fex" "${curDir}/myscript.fex"
		;;
	esac
	updateSettings "myscript.fex" "MAC" "MAC = \"${mac}\""

	../sunxi-tools/fex2bin "myscript.fex" "myscript.bin"

	echo "Done building script.bin"
}



function bootFunc
{
	curDir="${builddir}/bootcmd"
	if [ ! -d "${curDir}" ]; then
		mkdir ${curDir}
	fi
	cd ${curDir}
	echo "setenv console 'ttyS0,115200'
setenv root '/dev/mmcblk0p2'
setenv panicarg 'panic=10'
setenv extra 'rootfstype=ext4 rootwait'
setenv loglevel '8'
setenv setargs 'setenv bootargs console=\${console} root=\${root} loglevel=\${loglevel} \${panicarg} \${extra}'
setenv kernel 'uImage'
setenv boot_mmc 'fatload mmc 0 0x43000000 script.bin; fatload mmc 0 0x48000000 \${kernel}; bootm 0x48000000'
setenv bootcmd 'run setargs boot_mmc'" > "boot.cmd"

	mkimage -A arm -O u-boot -T script -C none -n "boot" -d "boot.cmd" "boot.scr"

}



function kernelFunc
{
	curDir="${builddir}/linux-allwinner"
	if [ ! -d "${curDir}" ]; then
		cd ${builddir}
		git clone git://github.com/amery/linux-allwinner.git
	fi
	cd ${curDir}
	git checkout ${kernel}
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi${hf}- sun4i_defconfig
	cp -a ".config" "config.orig"
	wget "https://raw.github.com/cnxsoft/a10-config/master/kernel/mele-a1000-server.config"  -O "${curDir}/config.server"

	rm "${curDir}/.config"
	case "${server}" in
	n)  echo "Building non-server kernel"
		cp -a "${curDir}/config.orig" "${curDir}/.config"
		;;
	*)  echo "Building server kernel"
		cp -a "${curDir}/config.server" "${curDir}/.config"
		updateSettings ".config" 'CONFIG_CMDLINE=' 'CONFIG_CMDLINE="mem=512M@0x40000000 console=ttyS0,115200"'
		updateSettings ".config" 'CONFIG_CMDLINE_FROM_BOOTLOADER' '# CONFIG_CMDLINE_FROM_BOOTLOADER is not set'
		updateSettings ".config" 'CONFIG_CMDLINE_EXTEND' 'CONFIG_CMDLINE_EXTEND=y'
		;;
	esac

	case "${misdn}" in
	y)  echo "Adding mISDN"
		updateSettings ".config" 'CONFIG_ISDN' 'CONFIG_ISDN=y'
		updateSettings ".config" 'CONFIG_MISDN' 'CONFIG_MISDN=m'
		updateSettings ".config" 'CONFIG_MISDN_HFCUSB' 'CONFIG_MISDN_HFCUSB=m'
		;;
	*)  echo ""
		;;
	esac

	case "${tun}" in
	y)	echo "Adding TUN"
		updateSettings ".config" 'CONFIG_TUN' 'CONFIG_TUN=m'
		;;
	*)  echo ""
		;;
	esac

	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi${hf}- uImage modules
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi${hf}- INSTALL_MOD_PATH=output modules_install
}



function rootfsFunc
{
	curDir="${builddir}/rootfs"
	if [ -d "${curDir}" ]; then
		rm -Rf ${curDir}
	fi
	mkdir -p "${curDir}/mnt"
	cd ${curDir}
	dd if="/dev/zero" of="rootfs.img" bs=1M count=1024
	mkfs.ext4 -F "rootfs.img"
	mount -o loop "rootfs.img" "mnt"
	debootstrap --verbose --arch=${arm} --variant=minbase --foreign ${debian} "mnt" http://ftp.debian.org/debian
	modprobe binfmt_misc
	cp "/usr/bin/qemu-arm-static" "mnt/usr/bin"
	mkdir "mnt/dev/pts"
	mount -t devpts devpts "mnt/dev/pts"
	mount -t proc proc "mnt/proc"
	chroot "mnt/" bash <<EOF
	/debootstrap/debootstrap --second-stage;

	echo "deb http://security.debian.org/ ${debian}/updates main contrib non-free
deb-src http://security.debian.org/ ${debian}/updates main contrib non-free
deb http://ftp.debian.org/debian/ ${debian} main contrib non-free
deb-src http://ftp.debian.org/debian/ ${debian} main contrib non-free" > "/etc/apt/sources.list";

	apt-get update;
	exit;
EOF

	mount -t devpts devpts "mnt/dev/pts"
	mount -t proc proc "mnt/proc"

	chroot "mnt/" bash <<EOF
	export LANG=C;
	apt-get -y install apt-utils dialog locales;
	exit;
EOF

	echo 'APT::Install-Recommends "0";
APT::Install-Suggests "0";' > "${curDir}/mnt/etc/apt/apt.conf.d/71mele";

	chroot "mnt/" bash <<EOF
	LANG="${locales}" locale-gen --purge "${locales}";
	export LANG="${locales}";
	apt-get -y install dhcp3-client udev netbase ifupdown iproute openssh-server iputils-ping wget net-tools ntpdate uboot-mkimage uboot-envtools vim nano less openvpn htop tmux openssl pump module-init-tools tzdata keyboard-configuration;
	exit;
EOF

	case "${network}" in
	dhcp)  echo 'auto lo eth0
iface lo inet loopback
iface eth0 inet dhcp' > "${curDir}/mnt/etc/network/interfaces"
		;;
	*)  echo "auto lo eth0
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
#iface eth0 inet dhcp
iface eth0 inet static
address ${networkbase}.${networkip}
netmask 255.255.255.0
network ${networkbase}.0
broadcast ${networkbase}.255
gateway ${networkbase}.1" > "${curDir}/mnt/etc/network/interfaces"
		;;
	esac;

	echo "${hostname}" > "${curDir}/mnt/etc/hostname"

	echo "# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/root      /               ext4    noatime,errors=remount-ro 0 1
tmpfs          /tmp            tmpfs   defaults          0       0" > "${curDir}/mnt/etc/fstab"

	echo "T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux" >> "${curDir}/mnt/etc/inittab"
	sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' "${curDir}/mnt/etc/inittab"

	chroot "mnt/" bash <<EOF
	echo "root:${password}" | chpasswd
	exit;
EOF

	umount "mnt/proc"
	umount "mnt/dev/pts"
	umount "${curDir}/mnt"
}



function createFunc
{
	curDir1="${builddir}/sdcard/mnt1"
	curDir2="${builddir}/sdcard/mnt2"
	mkdir -p "${curDir1}"
	mkdir -p "${curDir2}"

	dd if="/dev/zero" of="${sdcard}" bs=512 count=2047
	(echo n;echo;echo;echo;echo "+17M";echo n;echo ;echo;echo;echo;echo w) |fdisk "${sdcard}"

	dd if="${builddir}/uboot-allwinner/spl/${uboot}-spl.bin" of="${sdcard}" bs=1024 seek=8
	dd if="${builddir}/uboot-allwinner/u-boot.bin" of="${sdcard}" bs=1024 seek=32

	mkfs.vfat "${sdcard}1"
	mount "${sdcard}1" "${curDir1}"
	cp "${builddir}/linux-allwinner/arch/arm/boot/uImage" "${curDir1}/"
	cp "${builddir}/scriptbin/myscript.bin" "${curDir1}/script.bin"
	cp "${builddir}/bootcmd/boot.scr" "${curDir1}/"
	umount "${curDir1}"

	mkfs.ext4 "${sdcard}2"
	mount "${sdcard}2" "${curDir2}"
	mount -o loop "${builddir}/rootfs/rootfs.img" "${builddir}/rootfs/mnt"
	cd "${builddir}/linux-allwinner"
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabi${hf}- INSTALL_MOD_PATH="../rootfs/mnt" modules_install
	cp -a "${builddir}/rootfs/mnt/"* "${curDir2}/"
	umount "${curDir2}"
	umount "${builddir}/rootfs/mnt"

	echo "Files written to sdcard"
	echo ""
	echo ""
	echo "Once you boot up the created image, plese run the following commands:"
	echo "dpkg-reconfigure tzdata"
	echo "dpkg-reconfigure locales"
	echo "dpkg-reconfigure keyboard-configuration"

}



function restoreFunc
{
	rm -Rf "${builddir}"
	cp -a "${builddir}.orig" "${builddir}"
	echo "Build environment restored"
}



function backupFunc
{
	rm -Rf "${builddir}.orig"
	cp -a "${builddir}" "${builddir}.orig"
	echo "Build environment backed up"
}



function fullFunc
{
	ubootFunc
	scriptFunc
	bootFunc
	kernelFunc
	rootfsFunc
	createFunc
	echo "Done"
}



function downloadFunc
{
	apt-get -y install git-core
	mkdir -p "${builddir}"
	curDir="${builddir}/uboot-allwinner"
	if [ ! -d "${curDir}" ]; then
		cd "${builddir}"
		git clone git://github.com/hno/uboot-allwinner.git
	fi
	curDir="${builddir}/sunxi-tools"
	if [ ! -d "${curDir}" ]; then
		cd "${builddir}"
		git clone https://github.com/amery/sunxi-tools
	fi
	curDir="${builddir}/linux-allwinner"
	if [ ! -d "${curDir}" ]; then
		cd "${builddir}"
		git clone git://github.com/amery/linux-allwinner.git
	fi
	echo "Done"
}



case "${arm}" in
armel) echo "Setting to armel"
	hf=""
	;;
*) echo "Setting to armhf"
	hf="hf"
	;;
esac



case "${2}" in
init)  echo "Installting required packages and modifications"
	initializeFunc
    echo "Initializing completed... please continue with one of the other options"
	;;
esac



case "${1}" in
initialize)  echo "Installting required packages and modifications"
	initializeFunc
    echo "Initializing completed... please continue with one of the other options"
	;;
full)  echo "Building all... this takes a while"
	fullFunc
    ;;
uboot)  echo  "Building u-boot"
	ubootFunc
    ;;
script)  echo  "Building script.bin"
	scriptFunc
    ;;
boot)  echo  "Building boot.cmd"
	bootFunc
    ;;
kernel)  echo  "Building Kernel"
	kernelFunc
    ;;
rootfs) echo  "Building root filesystem"
	rootfsFunc
    ;;
create) echo  "Copying files onto sdcard"
	createFunc
    ;;
restore) echo "Restoring install environment"
	restoreFunc
	;;
backup) echo "Backup install environment"
	backupFunc
	;;
download) echo "Downloading the source code"
	downloadFunc
	;;
*) echo "Use: as root: ./install.sh OPTION"
   echo "Possible options:"
   echo "initialize - only run ONCE to install required dependencies and stuff"
   echo "full - build everything (runs all except the initialize)"
   echo "full init - this will run the initialize and full script at once"
   echo "uboot - build the u-boot"
   echo "script - build script.bin"
   echo "boot - build boot.cmd"
   echo "kernel - build the kernel"
   echo "rootfs - build the root filesystem"
   echo "create - write everything to the sd card (it will get reformatted)"
   echo "restore - remove build environment and restore backup"
   echo "backup - backup build environment"
   echo "download - just download the source code"
   ;;
esac
