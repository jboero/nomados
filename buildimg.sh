#!/bin/bash -x
export B=/mnt/aux
qemu-img create -f qcow2 -o size=4G nomados.qcow2
qemu-nbd --connect=/dev/nbd0 nomados.qcow2

mkfs.ext4 /dev/nbd0
mount /dev/nbd0 $B

mkdir -p $B/{lib64,sbin,bin,usr/bin,usr/local/bin,var/lib/nomad,etc/nomad,lib/modules/$(uname -r)}
mkdir -p $B/sys/{kernel/tracing,fs/fuse/connections}
mkdir -p $B/dev/{pts,mqueue,hugepages,kernel/debug}
mkdir -p $B/proc/sys/fs/binfmt_misc
mkdir -p $B/var/{run,log,lib}
mkdir -p $B/var/lib/dhclient
mkdir -p $B/var/lib/nomad/data/{plugins,allocations}
mkdir -p $B/tmp $B/sys/kernel/tracing $B/sys/fs/fuse/connections $B/sys/kernel/security
mkdir -p $B/modules
mkdir -p $B/usr/sbin
mkdir -p $B/etc/dhcp

# Copy kernel from ./bzimage
cp bzimage $B/

# Copy minimal bins and libs.
cp ./config/extlinux.conf $B/
cp ./config/init.json $B/etc/nomad/
cp ./sdhcp $B/sbin
cp /usr/bin/{nomad,df} $B/usr/bin/
cp /bin/{bash,sh,cat,ls,ipcalc} $B/bin/
cp /sbin/{ip,nologin} $B/sbin/
cp /etc/passwd $B/etc

cp /lib64/{libpthread.so*,libc.so*,libtinfo.so*,libdl.so*,ld-*} \
   /lib64/{libcap.*,libz.*,libelf*,libmnl.so*} $B/lib64/

# Experimoptional - UPX binpack Nomad to shrink it.
#upx $B/usr/bin/nomad

# Build Nomad init
gcc nomadinit.c -o $B/sbin/init

# Install extlinux bootloader
extlinux --install $B

umount $B
qemu-nbd --disconnect /dev/nbd0

#xz -T0 -f -k nomados.qcow2

