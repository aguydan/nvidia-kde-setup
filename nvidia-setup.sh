#!/bin/bash

#check if nvidia drivers are installed and if not install them

function check_answer () {
	if [ $1 = 'y' ]
	then
		return 0
	elif [ $1 = 'N' ]
	then
		return 1
	else
		echo "$1 is not a valid answer"
		exit 1
	fi
}

packages_search_res=$(pacman -Qs 'nvidia')

if $(echo $packages_search_res | grep -qE 'nvidia-open'); then
  echo 'nvidia-open drivers are installed, but they are prone to bugs as of October 2024. See more: https://github.com/NVIDIA/open-gpu-kernel-modules/issues/538'
  echo 'Do you wish to remove nvidia-open drivers and install proprietary ones? [y/N]'

  read answer

  check_answer $answer

  echo $answer
  exit 1
elif ! $(echo $packages_search_res | grep -qE 'nvidia\s'); then
  echo 'Proprietary Nvidia drivers were not found, please run the following command:'
  echo 'sudo pacman -S nvidia'
  exit 1
fi

#add nvidia kernel modules to mkinitcpio.conf

nvidia_modules=(nvidia nvidia_modeset nvidia_drm)
modules_to_add=()

if ! grep -qE '^MODULES=(\(.*\))' ~/Desktop/mkinitcpio.conf; then
  echo 'MODULES=()' >>~/Desktop/mkinitcpio.conf
fi

existing_modules=$(grep -Po '(?<=^MODULES=\().*(?=\))' ~/Desktop/mkinitcpio.conf)

for module in ${nvidia_modules[@]}; do
  if ! $(echo $existing_modules | grep -qw $module); then
    modules_to_add+=($module)
  fi
done

if [ ${#modules_to_add[@]} ]; then #why do we need -eq 0? it still evaluates to zero
  echo "No Nvidia modules to add"
else

  new_modules="${modules_to_add[@]}"

  if [ ! $existing_modules ]; then
    new_modules+=($existing_modules)
  fi

  sed -i -E "s/^MODULES=\((.*)\)/MODULES=($new_modules)/" ~/Desktop/mkinitcpio.conf

  echo "Nvidia modules have been added, recreating initramfs..."
fi

# add variables to modeprobe.d

touch nvidia.conf

cat >nvidia.conf <<-EOM
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp
options nvidia NVreg_EnableGpuFirmware=0
options nvidia_drm modeset=1
options nvidia_drm fbdev=1
EOM

# mkinitcpio -P

echo 'Now reboot your OS'
