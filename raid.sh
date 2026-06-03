#!/bin/bash

read -p "Сколько дисков: " TYPE_DISK
read -p "Пути для каждого диска: " TYPE_PASS
read -p "Какой RAID 0 или 5: " TYPE_RAID 

mdadm --craete /dev/md3 -l ${TYPE_RAID} -n ${TYPE_DISK} ${TYPE_PASS}
mdadm --dateil --scan --verbose >> /etc/mdadm.conf 
mkfs.ext4 /dev/md3
echo "/dev/md3    /raid    ext4    defaults    0    0" >> /etc/fstab
mkdir /raid 
mount -a
