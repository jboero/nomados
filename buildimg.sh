#!/bin/bash
# jboero@hashicorp.com
# NomadOS experimental build script.  This uses qemu-nbd to create and mount a new qcow2 image.
# You will need access to create, nbd mount, and format a QCOW2 image file.
# 1. Formats the whole device Ext4
# 2. Builds nomadinit and copies minimal dependencies into said image: kernel, nomad.
# 3. Installs extlinux bootloader (without initrd) and unmounts.
# 4. Unmounts and compacts the image to minimize size.
# Build mount path.
export B=/mnt/qcow

# SATA boot by default.  Change to /dev/vda for VirtIO
export KERNEL_PATH="${KERNEL_PATH:-./bzImage}"
export BOOT_DEV="${BOOT_DEV:-/dev/sda}"
export PODMAN_SUPPORT="${PODMAN_SUPPORT:-n}"

# Optional cross compile
#export ARCH=riscv
#export CROSS_COMPILE=riscv64-linux-gnu-
#export QEMU_SUPPORT="${QEMU_SUPPORT:-y}"

umask 0022
qemu-img create -f qcow2 -o size=100G /tmp/hashios.qcow2
qemu-nbd --connect=/dev/nbd0 /tmp/hashios.qcow2

# Partition optionally with sfdisk
#sfdisk /dev/nbd0 <<EOF
#label: gpt
#device: /dev/nbd0
#unit: sectors
#sector-size: 512
#
#/dev/sda1 : start=        2048, size=     209713118, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=8CB01312-BC66-48C3-93B6-BE4D92580C6F, name="Only Partition"
#EOF

# Enable discard/trim
mkfs.ext4 /dev/nbd0
tune2fs -o discard /dev/nbd0
mount /dev/nbd0 $B

pushd $B
mkdir -p syslinux
mkdir -p {usr/{lib,lib64},sbin,bin,usr/bin,usr/local/bin,var/lib/nomad/data/plugins,etc/nomad,usr/lib/modules/$(uname -r)}
mkdir -p sys/{kernel/tracing,fs/fuse/connections}
mkdir -p dev/{pts,mqueue,hugepages,kernel/debug}
mkdir -p proc/sys/fs/binfmt_misc
mkdir -p var/{tmp,run,log,lib} var/lib/dhclient
mkdir -p var/lib/nomad/data/{plugins,allocations}
mkdir -p tmp sys/kernel/tracing sys/fs/fuse/connections sys/kernel/security
mkdir -p modules usr/sbin etc/dhcp
mkdir -p run/systemd/journal/
ln -s usr/lib64 lib64
ln -s usr/lib   lib
popd

# Copy kernel from path $KERNEL_PATH
cp "$KERNEL_PATH" $B/syslinux/
cp -an /usr/lib64/{ld-*.so*,libc-*} $B/usr/lib64/

# Helper to add a local binary and all lib dependencies
function add_dep()
{
	for dep in $(ldd -v $(which $1) | grep '/.*:' | sed 's/://g'); do
		if [ "$dep" == "$(which $1)" ] ; then
			cp -n "$dep" $(dirname "$B$dep")
		else
			cp -n "$dep"* $(dirname "$B$dep")
		fi
	done
}

# EXT Linux bootloader
cp /boot/extlinux/{vesamenu,libcom32,libutil}.c32 \
   ./wig/{splash.png} $B/syslinux/
cp ./config/extlinux.conf $B/syslinux/
# Replace BOOT_DEV if set
#sed -i "s/\/dev\/sda/${BOOT_DEVICE:\/dev\/sda}/g" $B/syslinux/extlinux.conf
cp ./config/init.json $B/etc/nomad/
cp ./sdhcp $B/sbin/
cp ./nomad $B/usr/bin/
#cp -a /etc/pki $B/etc/

# Copy minimal bins and libs.
#for cmd in bash sh su nomad df strace grep kill pkill ip nologin cat tail ls ipcalc ps stty nologin; do
#	add_dep $cmd
#done

#cp /etc/localtime $B/etc/
#ln -s /usr/bin/bash $B/bin
#ln -s /usr/bin/sh $B/bin
#cp -a /usr/lib64/{libcrypt*,libnsl*} $B/usr/lib64/

# NSS,PAM
#cp -a /usr/lib64/{security,libnss*} $B/usr/lib64/
#cp -a /etc/{authselect,default,login.defs} $B/etc/
#cp -a ./config/pam.d $B/etc/
#cp ./config/{group,passwd,shadow,nsswitch.conf} $B/etc/

# Podman option
if [ "$PODMAN_SUPPORT" = "y" ]
then
	cp -a /etc/{containers,cni} $B/etc/
	cp nomad-driver-podman $B/var/lib/nomad/data/plugins
	for cmd in podman conmon crun nsenter; do
		add_dep $cmd
	done
fi

# Build Nomad init
set -x
${CROSS_COMPILE}gcc -I /usr/include nomadinit.c -static -o $B/sbin/init || exit 1
#for dep in $(ldd -v $(which $1) | grep '/.*:' | sed 's/://g'); do
#	cp -n "$dep*" "$B$dep"
#done

# Install extlinux bootloader
extlinux --install /mnt/qcow

# Inspect final layout
tree $B
umount $B
qemu-nbd --disconnect /dev/nbd0

qemu-img convert -c -O qcow2 /tmp/hashios.qcow2 /tmp/hashios.compact.qcow2
mv -f /tmp/hashios.compact.qcow2 /tmp/hashios_$(uname -i).qcow2
qemu-img convert -f qcow2 /tmp/hashios_$(uname -i).qcow2 -O vmdk /tmp/hashios_$(uname -i).vmdk&
rm /tmp/hashios.qcow2
chown jboero:kvm /tmp/hashios*
