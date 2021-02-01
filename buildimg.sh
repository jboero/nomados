#!/bin/bash -x
# jboero@hashicorp.com
# NomadOS experimental build script.  This uses qemu-nbd to create and mount a new qcow2 image.
# 1. Formats the whole device Ext4
# 2. Builds nomadinit and copies minimal dependencies into said image: kernel, nomad.
# 3. Installs extlinux bootloader (without initrd) and unmounts.
# 4. Unmounts and compacts the image to minimize size.
export B=/mnt/qcow
umask 0022
qemu-img create -f qcow2 -o size=100G /tmp/nomados.qcow2
qemu-nbd --connect=/dev/nbd0 /tmp/nomados.qcow2

# EXT4 entire device
mkfs.ext4 /dev/nbd0

# Enable discard/trim
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

# Copy kernel from ./bzImage
cp bzImage $B/syslinux/
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
   ./config/{splash.png,extlinux.conf} $B/syslinux/
cp ./config/init.json $B/etc/nomad/
cp ./sdhcp $B/sbin/
cp -a /etc/pki $B/etc/

# Copy minimal bins and libs.
for cmd in bash sh su nomad df strace grep kill pkill ip nologin cat tail ls ipcalc ps stty nologin; do
	add_dep $cmd
done
cp /etc/localtime $B/etc/
ln -s /usr/bin/bash $B/bin
ln -s /usr/bin/sh $B/bin
cp -a /usr/lib64/{libcrypt*,libnsl*} $B/usr/lib64/

# NSS,PAM
cp -a /usr/lib64/{security,libnss*} $B/usr/lib64/
cp -a /etc/{authselect,default,login.defs} $B/etc/
cp -a ./config/pam.d $B/etc/
cp ./config/{group,passwd,shadow,nsswitch.conf} $B/etc/

# Podman option
cp -a /etc/{containers,cni} $B/etc/
cp nomad-driver-podman $B/var/lib/nomad/data/plugins
for cmd in podman conmon crun nsenter; do
	add_dep $cmd
done

# Build Nomad init
gcc nomadinit.c -o $B/sbin/init || exit 1
for dep in $(ldd -v $(which $1) | grep '/.*:' | sed 's/://g'); do
	cp -n "$dep*" "$B$dep"
done

# Install extlinux bootloader
extlinux --install $B

# Inspect final layout
tree $B
umount $B
qemu-nbd --disconnect /dev/nbd0

qemu-img convert -c -O qcow2 /tmp/nomados.qcow2 /tmp/nomados.compact.qcow2
mv -f /tmp/nomados.compact.qcow2 /tmp/nomados.qcow2
#qemu-img convert -f qcow2 /tmp/nomados.qcow2 -O vmdk /tmp/nomados.vmdk&
chown jboero:kvm /tmp/nomados.qcow2
chmod 660 /tmp/nomados.qcow2
