#!/bin/bash
mdadm --craete /dev/md3 -l 5 -n 3 /dev/sdb /dev/sdc /dev/sdd
mdadm --dateil --scan --verbose >> /etc/mdadm.conf 
mkfs.ext4 /dev/md3
echo "/dev/md0    /raid    ext4    defaults    0    0" >> /etc/fstab
mkdir /raid 
mount -a
