#define _GNU_SOURCE
#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/mount.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/socket.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

#ifndef ifr_newname
#define ifr_newname     ifr_ifru.ifru_slave
#endif

#define init_module(module_image, len, param_values) syscall(__NR_init_module, module_image, len, param_values)
#define finit_module(fd, param_values, flags) syscall(__NR_finit_module, fd, param_values, flags)

void mounter(const char * src, const char *dst, const char * type, int rwflag, const char *data)
{
    if (!mount(src, dst, type, rwflag, data))
        printf("Mounted: %s\n", dst);
    else
        printf("ERROR:   %s: %s\n", strerror(errno), dst);
}

int ifup(char *ifname)
{
    int sockfd;
    struct ifreq ifr;

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    if (sockfd < 0)
        return sockfd;

    memset(&ifr, 0, sizeof ifr);

    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    ifr.ifr_flags |= IFF_UP;
    ioctl(sockfd, SIOCSIFFLAGS, &ifr);
    
    printf("IFUP: %s\n", ifname);
    return sockfd;
}

int main()
{
    // Remount root read/write
    mounter("",           "/",                "",         MS_REMOUNT, "discard");

    mkdir("/dev",           S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mkdir("/dev/pts",       S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("devpts",     "/dev/pts",         "devpts",   0, "");
    mkdir("/dev/hugepages", S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mkdir("/dev/mqueue",    S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("mqueue",     "/dev/mqueue",      "mqueue",   0, "");
    mkdir("/dev/pts",       S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("devpts",     "/dev/pts",         "devpts",   0, "");
    mkdir("/dev/kernel",    S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mkdir("/dev/kernel/debug", S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("debugfs",     "/dev/kernel/debug","debugfs", 0, "");
    mounter("tracefs",     "/sys/kernel/tracing","tracefs", 0, "");
    mkdir("/proc",          S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("proc",       "/proc",            "proc",      0, "");
    mkdir("/proc/sys",      S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mkdir("/proc/sys/fs",   S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mkdir("/proc/sys/fs/binfmt_misc", S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("binfmt_misc","/proc/sys/fs/binfmt_misc","binfmt_misc", 
        MS_NODEV | MS_NOEXEC | MS_NOEXEC, "");
    
    mkdir("/tmp",         S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("tmpfs",      "/tmp",             "tmpfs",     0, "");
    mkdir("/sys",         S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("sysfs",      "/sys",             "sysfs",     0, "");
    mkdir("/sys/fs",      S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    mounter("selinuxfs",  "/sys/fs/selinux",  "selinuxfs", 0, "");

    while (1)
    {
        pid_t child = fork();
        if (child == -1) {
            perror("init: fork");
            return 1;
        }
        else if (child == 0)
        {
            ifup("lo");
            ifup("eth0");
            setenv("PATH", "/sbin:/usr/sbin:/usr/bin:/bin:/usr/local/bin", 1);
            system("/sbin/sdhcp -d eth0");
            system("/sbin/ip a");
            system("/usr/bin/nomad agent -dev -config=/etc/nomad/init.json");
        }
        while (1)
        {
            sleep(1);
            wait(0);
        }
    }
    
    return 0;
}
