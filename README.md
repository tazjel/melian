melian
======

Build script to build Debian for a Mele A2000 (possibly works also on a A1000)


Usage
-----

1.) Install a plain Ubuntu 12.04 (32bit or 64bit) into a VM

2.) Enable root access in the VM

3.) Copy the install script into the VM

4.) Edit the install script and add you desired options

5.) Make the install script executable and run it
    --> it'll tell you the possible options


IF you're lazy, you'll just run the "full init" option e.g.
./install.sh full init


initialize:
This option just installs the required dependencies into your Ubuntu vm and creates the build directory.
This is necessary for the later building parts.


full:
This option just runs through all the building parts. There are still a few user interactions required.


uboot:
This option builds the u-boot loader (universal boot loader). The Mele A2000 requires that.


script:
This option builds the script.bin necessary to boot.


kernel:
This options builds the actual kernel. There are a few kernel options you can set directly in the script top part.
As examples you get TUN and mISDN support. You could use the same logic to add other modules to also build.


rootfs:
This option builds the Debian root file system by using qemu and debootstrap. You can build Squeeze or Wheezy, just set the option
at the top part of the script.


create:
This option partitions, then formats the sd card and finally writes all the necessary files on it.


download:
This option just downloads the u-boot and kernel sources. Together they're roughly 1GB to download.


backup:
This option makes a backup of the build directory.


restore:
This option restores the previously made backup to the default build directory.