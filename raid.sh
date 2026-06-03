#!/bin/bash

#read -p "Сколько дисков: " TYPE_DISK
#read -p "Пути для каждого диска: " TYPE_PASS
#read -p "Какой RAID 0 или 5: " TYPE_RAID 

mdadm --create /dev/md3 -l 0 -n 2 /dev/sdb /dev/sdc
#-l ${TYPE_RAID} -n ${TYPE_DISK} ${TYPE_PASS}

echo "конфиг mdadm"
mdadm --detail --scan --verbose | tee -a /etc/mdadm.conf

echo "Разметка рейда"
mkfs.ext4 /dev/md3

echo "Создание директории"
mkdir /raid 

echo "Запись в fstab"
echo "/dev/md3    /raid    ext4    defaults    0    0" >> /etc/fstab

mount -a
