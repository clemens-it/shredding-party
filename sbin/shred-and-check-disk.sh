#!/bin/bash
if [ -z "$1" ]; then
	echo Usage: $0 block-device
	exit 9
fi
dev="$1"

if [ ! -b "$dev" ]; then
	echo $dev is not a block device
	exit 8
fi

# Get info whether hard disk is rotary type or not (i.e. solid state)
rot=$(lsblk --nodeps -no rota "$dev" | sed -Ee 's/\s//g')

# Get info whether disk security is frozen
frozen=$(hdparm -I "$dev" | grep frozen | sed -Ee 's/\s+//g')
if [ "$frozen" != "notfrozen" ]; then
	echo -e "Disk security security is frozen on device $dev. Abort and try to supend the system to unfreeze.\n"
	echo -e "Hit enter to proceed with classic shredding mthods or press Ctrl+C to abort.\n"
	echo -e "\nWARNING!!!\n"
	echo -e "This will destroy all the data on block device $dev\n"
	read -p "Hit Enter to continue. Press Ctrl+C to abort."

	if [ "$rot" = "1" ]; then
		echo "Rotatory device. Classic shredding"
		dd_rescue -4 /dev/urandom -M "$dev"
	else
		echo "Non rotatory i.e. Solid State Device"
		echo "Running secure blkdiscard"
		blkdiscard -v -f --secure "$dev"
		if [ $? -ne 0 ]; then
			#fallback to unsecure discard
			echo Falling back to unsecure blkdiscard
			blkdiscard -v -f "$dev"
		fi
		echo Zeroing out disk
		blkdiscard -v -f --zeroout "$dev"
	fi
	exit 7
fi

# Print info on screen and ask for last confirmation before proceeding
# with data destruction
echo -e "\nWARNING!!!\n"
echo -e "This will destroy all the data on block device $dev\n"
lsblk -o name,serial,size,model,tran,vendor,rota --nodeps "$dev"
echo -e "\n"
read -p "Hit Enter to continue. Press Ctrl+C to abort."
date

# Try to erase disk using built in security mechanism.
# Activation via hdparm command

# Before erasing we need to set a user password for the disk
echo "Setting security user password"
hdparm --user-master u --security-set-pass pass "$dev"
secenabled=$(hdparm -I "$dev" | grep enabled | sed -Ee 's/\s+//g')
# Check if security (password) is enabled and proceed with erase procedure
if [ "$secenabled" = "enabled" ]; then
	echo "Issue ATS secure erase command"
	time hdparm --user-master u --security-erase-enhanced pass "$dev"
	#time hdparm --user-master u --security-erase pass "$dev"
else
	echo "Security not enabled. Cannot proceed"
	exit 6
fi

# Once the erasing is done, security should be automatically reset.
# Make sure that security is disabled
echo "Checking security setting after secure erase"
secenabled=$(hdparm -I "$dev" | grep enabled | sed -Ee 's/\s+//g')
if [ "$secenabled" = "notenabled" ]; then
	echo "Security is disabled, you're all good!"
else
	echo "Security is still enabled. Trying to disable it"
	hdparm --security-disable pass "$dev"
	echo -e "Checking status - should be 'not enabled'\n"
	hdparm -I "$dev" | grep enabled
	echo -e "\n"
fi

date
echo "Done shredding. Checking result"
checkshred -p 15 -v "$dev"
