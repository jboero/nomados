#!/bin/bash -x
export B=/mnt/qcow
umask 0022
qemu-img create -f qcow2 -o size=100G /tmp/nomados.qcow2
qemu-nbd --connect=/dev/nbd0 /tmp/nomados.qcow2

# EXT4 entire device
mkfs.ext4 /dev/nbd0

# Enable discard/trim
tune2fs -o discard /dev/nbd0
mount /dev/nbd0 $B

mkdir -p $B/syslinux
mkdir -p $B/{lib64,sbin,bin,usr/bin,usr/local/bin,var/lib/nomad/data/plugins,etc/nomad,lib/modules/$(uname -r)}
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
mkdir -p $B/etc/pki/ca-trust/extracted/pem/

# Copy kernel from ./bzImage
cp bzImage $B/syslinux/

# Copy minimal bins and libs.
cp /boot/extlinux/{vesamenu.c32,libcom32.c32,libutil.c32} \
   ./config/{splash.png,extlinux.conf} $B/syslinux/
cp ./config/{group,passwd,shadow,nsswitch.conf} $B/etc/
#cp -a /etc/{group,passwd,shadow,login.defs,default} ./config/nsswitch.conf $B/etc/
cp ./config/init.json $B/etc/nomad/
cp ./sdhcp /sbin/{ip,nologin} $B/sbin
cp /usr/bin/{su,nomad,df,strace,grep,kill,pkill} $B/usr/bin/
cp /bin/{bash,sh,cat,tail,ls,ipcalc} $B/bin/
cp /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
   $B/etc/pki/ca-trust/extracted/pem/

# Podman option
#mkdir -p $B/run/podman
#cp nomad-driver-podman $B/var/lib/nomad/data/plugins
#cp podman-1.9.2 $B/usr/bin/podman

cp /lib64/ld-*.so* \
   /lib64/lib{pthread,c,tinfo,dl}.so* \
   /lib64/lib{cap*,z,elf*,mnl,procps}.so* \
   /lib64/lib{pam*,audit,util,nss_compat,nsl,nss_files}.so* \
   /lib64/lib{rt,dw,selinux,lzma,bz2,pcre*}.so* \
   $B/lib64/ || exit 1

# Experimoptional - UPX binpack Nomad to shrink it.
#upx $B/usr/bin/nomad

# Build Nomad init
gcc nomadinit.c -o $B/sbin/init || exit 1

# Install extlinux bootloader
extlinux --install $B

umount $B
qemu-nbd --disconnect /dev/nbd0

qemu-img convert -c -O qcow2 /tmp/nomados.qcow2 /tmp/nomados.compact.qcow2
mv -f /tmp/nomados.compact.qcow2 /tmp/nomados.qcow2
qemu-img convert -f qcow2 /tmp/nomados.qcow2 -O vmdk /tmp/nomados.vmdk&
chown jboero:kvm /tmp/nomados.qcow2
chmod 660 /tmp/nomados.qcow2

