#!/bin/bash


for i in lsblk xfce4-terminal udevadm shred-and-check-disk.sh hdparm blkdiscard checkshred; do
	which $i >/dev/null
	if [ $? -ne 0 ]; then
		echo Missing command $i. Cannot proceed.
		exit 10
	fi
done

declare -A skip_disk
skip_disk[00011008061321121256]=1
skip_disk[4C530001050614100010]=1

shopt -s lastpipe

for disk in $(lsblk --nodeps -pno name) ; do
	lsblk -no name,serial,size --nodeps "$disk" | read name serial size
	
	serialstr=$(udevadm info --query=property --name "$disk" | grep "^ID_SERIAL=" | sed -e 's/^ID_SERIAL=//')
	if [ ${skip_disk[$serial]+_} ]; then
		echo Skipping disk $name $serialstr $size
		continue;
	fi
	echo $name $serial $serialstr $size
	xfce4-terminal -T "Shred $name $size $serialstr" -e 'bash -c "shred-and-check-disk.sh '$disk'; echo; read -p \"Press Enter to close the window\""'
done
