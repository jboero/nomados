# Nomad Init
An experiment after Hashiconf Digital 2020 for building a minimal Linux Nomad agent. This build has been developed and tested on Fedora 32, and copies some local dependencies into the qcow image during packaging.  Qemu-img must be installed and the nbd kernel module loaded to mount the qcow2 image created during `buildimg.sh`.  Accompanying blog post on Medium: https://medium.com/@boeroboy/nomad-vs-systemd-e0db80d34e8a

Here we attempt to turn HashiCorp's Cloud Operating Model upside down, using Nomad as a foundation to run everything from scratch rather than Terraform to provision first.
![image](https://user-images.githubusercontent.com/7536012/159683583-618a326d-80ab-4d37-8f9a-d54d6fb18635.png)

Source for sdhcp can be found here: https://git.2f30.org/sdhcp/.  
Source for Linux kernel built directly:
```
git clone --depth=1 git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux
# Some distros require a make allnoconfig first.
make allnoconfig
make kvm_guest.config
make -j
```

Command to run qemu vm:
```
qemu-system-x86_64 -m 2G -smp cpus=4 -nographic \
-kernel bzImage-linux58 -append "console=ttyS0 root=/dev/sda" \
-net nic,model=virtio -net bridge,br=virbr0 \
-hda ~/Desktop/nomadinit/nomados.qcow2 --enable-kvm
```

Nomad is run at boot with config config/init.json

# NomadOS
NomadOS can be built from the Nomad Init project.  It adds the extlinux bootloader and bare minimal OS into a fully-contained QCOW or VMDK for virtualized or cloud compatible image.  It is currently an experimental community project and not supported by HashiCorp.  It can be built on a Linux distribution so long as all dependency paths in the build script are present in the environment.
