#!/bin/bash

#Adapted from PopOS guide
#The purpose of this script is to bind all non-boot GPUs to the vfio driver MX Linux

#Detecting CPU
CPU=$(lscpu | grep GenuineIntel | rev | cut -d ' ' -f 1 | rev )

INTEL="0"

if [ "$CPU" = "GenuineIntel" ]
	then
	INTEL="1"
fi

echo "Please wait"

IDS="vfio-pci.ids="
BOOTGPU=""

#Identify a boot GPU

for i in $(find /sys/devices/pci* -name boot_vga); do
    if [ $(cat $i) -eq 1 ]; then

        BOOTGPU_PART=`lspci -n | grep $(echo $i | rev | cut -d '/' -f 2 | rev | cut -d ':' -f2,3,4)`
        BOOTGPU=$(echo $BOOTGPU_PART | cut -d ' ' -f 3)

        echo
        echo "Boot GPU:" `lspci -nn | grep $BOOTGPU`
    fi
done

#Identify any non-boot GPUs

for i in $(find /sys/devices/pci* -name boot_vga); do
    if [ $(cat $i) -eq 0 ]; then
        echo

        GPU=`echo $(dirname $i) | cut -d '/' -f6 | cut -d ':' -f 2,3,4 `
        GPU_ID=$(echo `lspci -n | grep $GPU | cut -d ':' -f 3,4 | cut -d ' ' -f 2`)

        #If a boot GPU has the same id as a non-boot GPU, then terminate 

        if [ $GPU_ID = $BOOTGPU ]
            then
                printf "ERROR! \nYour boot/primary GPU has the same id as one of the GPUs you are trying to bind to vfio-pci!\n"
                exit 1
        fi

        GPU_PATH=`echo $(dirname $i)`
        SRCH_PATH="${GPU_PATH:0:-1}*"

        #Identify the all GPU functions of detected GPUs

        for d in $(ls -d $SRCH_PATH); do
            #Add necessary commas to separate the ids
            if [[ $IDS != *"\"" ]] && [[ $IDS != "vfio-pci.ids=" ]]; then
                IDS+=","
            fi

            DEVICE=`echo $d | cut -d '/' -f 6 | cut -d ':' -f 2,3,4 `
            DEVICE_ID=$(echo `lspci -n | grep $DEVICE | cut -d ':' -f 3,4 | cut -d ' ' -f 2`)

            echo "Found:" `lspci -k | grep $DEVICE`

            #Build a string that will be passed to IDS
            IDS+=$(echo `lspci -n | grep $DEVICE_ID | cut -d ':' -f 3,4 | cut -d ' ' -f 2`)
        done
    fi
done


echo
echo $IDS

#Building string Intel or AMD iommu=on
if [ $INTEL = 1 ]
	then
	IOMMU="intel_iommu=on kvm.ignore_msrs=1"
	echo "Set Intel IOMMU On"
	else
	IOMMU="amd_iommu=on kvm.ignore_msrs=1"
	echo "Set AMD IOMMU On"
fi

#Putting together new grub string
OLD_OPTIONS=`cat /etc/default/grub | grep GRUB_CMDLINE_LINUX_DEFAULT | cut -d '"' -f 1,2`

NEW_OPTIONS="$OLD_OPTIONS $IOMMU $IDS\""
echo $NEW_OPTIONS

#Rebuilding grub 
sed -i -e "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|${NEW_OPTIONS}|" /etc/default/grub

echo 'vfio-pci' >> /etc/modules

update-grub


apt-get install qemu virt-manager libvirt-daemon libvirt-daemon-system qemu-kvm ovmf qemu-utils
