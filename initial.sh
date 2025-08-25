#!/bin/sh
# Author: RubikPi Team
# Date: 2024-12-21
# Optimized initial setup script for RUBIK Pi 3 with parameter support
# Based on original initial.sh and UbunInitScripts

set -e

# Configuration constants
REPO_ENTRY="deb http://apt.rubikpi.ai ppa main"
HOST_ENTRY="151.106.120.85 apt.rubikpi.ai"
XDG_EXPORT="export XDG_RUNTIME_DIR=/run/user/\$(id -u)"
CAMERA_SETTINGS="/var/cache/camera/camxoverridesettings.txt"
USER_HOME="/home/ubuntu"
USER_NAME="ubuntu"

# Script execution flags
do_ppa_flag=0
do_camera_flag=0
do_software_flag=0
do_upgrade_flag=0
do_reboot_flag=1
do_hostname_flag=0
target_hostname=""

# Usage function with colored output
usage() {
	printf "\033[1;37mUsage:\033[0m\n"
	printf "  bash %s [options]\n" "$0"
	printf "\n"
	printf "\033[1;37mDescription:\033[0m\n"
	printf "  Helps you quickly enable RUBIK Pi's peripheral functions (CAM, AI, Audio, etc.)\n"
	printf "\n"
	printf "\033[1;37mOptions:\033[0m\n"
	printf "\033[1;37m  -h, --help\033[0m              display this help message\n"
	printf "\033[1;37m  -p, --ppa-only\033[0m          only add PPA repositories\n"
	printf "\033[1;37m  -c, --camera-only\033[0m       only install camera packages\n"
	printf "\033[1;37m  -s, --software-only\033[0m     only install RubikPi software packages\n"
	printf "\033[1;37m  -u, --upgrade-only\033[0m      only run system upgrade\n"
	printf "\033[1;37m  --no-reboot\033[0m             skip automatic reboot\n"
	printf "\033[1;37m  --hostname=<name>\033[0m       set system hostname\n"
	printf "\033[1;37m  -a, --all\033[0m               run all components (default behavior)\n"
	printf "\n"
	printf "\033[1;37mExamples:\033[0m\n"
	printf "  bash %s                          # Run all components (original behavior)\n" "$0"
	printf "  bash %s --ppa-only               # Only add repositories\n" "$0"
	printf "  bash %s --camera-only --no-reboot  # Install camera without reboot\n" "$0"
	printf "  bash %s --hostname=mypi          # Set hostname and run all\n" "$0"
	printf "\n"
}

# Set hostname function
set_hostname() {
	if [ -n "$1" ]; then
		echo "Setting hostname to: $1"
		sudo hostnamectl set-hostname "$1"
		sudo sed -i "s/^127\.0\.1\.1\s\+.*/127.0.1.1 $1/" /etc/hosts
		echo "Hostname set successfully"
	fi
}

# Add PPA repositories
add_ppa()
{
	echo "Adding PPA repositories..."
	if ! grep -q "^[^#]*$REPO_ENTRY" /etc/apt/sources.list; then
		echo "$REPO_ENTRY" | sudo tee -a /etc/apt/sources.list >/dev/null
	fi
	if ! grep -q "$HOST_ENTRY" /etc/hosts; then
		echo "$HOST_ENTRY" | sudo tee -a /etc/hosts >/dev/null
	fi

	# Add the GPG key for the apt.rubikpi.ai PPA
	wget -qO - https://thundercomm.s3.dualstack.ap-northeast-1.amazonaws.com/uploads/web/rubik-pi-3/tools/key.asc | sudo tee /etc/apt/trusted.gpg.d/rubikpi3.asc

	sudo apt update -y
	echo "PPA repositories added successfully"
}

# Install camera packages
camera_install()
{
	echo "Installing camera packages..."
	sudo mkdir -p /opt
	sudo chmod 755 /opt
	grep -qxF "$XDG_EXPORT" "$USER_HOME/.bashrc" || echo "$XDG_EXPORT" >> "$USER_HOME/.bashrc"
	sudo bash -c "grep -qxF '${XDG_EXPORT}' /root/.bashrc || echo '${XDG_EXPORT}' >> /root/.bashrc"
	sudo mkdir -p /var/cache/camera
	sudo sh -c "echo 'enableNCSService=FALSE' > $CAMERA_SETTINGS"

	# CAM/AI -- QCOM PPA
	sudo apt install -y \
		gstreamer1.0-qcom-sample-apps qcom-sensors-test-apps \
		gstreamer1.0-tools qcom-fastcv-binaries-dev qcom-video-firmware \
		weston-autostart libgbm-msm1 qcom-adreno1 qcom-ib2c qcom-camera-server \
		qcom-camx

	# CAM/wiringrp -- RUBIK Pi PPA
	sudo apt install -y \
		rubikpi3-cameras
	echo "Camera packages installed successfully"
}

# Install RubikPi software packages
rubikpi_software_install()
{
	echo "Installing RubikPi software packages..."
	sudo apt install -y \
		wiringrp wiringrp-python
	echo "RubikPi software packages installed successfully"
}

# Upgrade system packages
do_upgrade()
{
	echo "Upgrading system packages..."
	sudo apt upgrade -y
	echo "System upgrade completed successfully"
}

# Parameter parsing
parse_arguments() {
	if [ "$#" -eq 0 ]; then
		# Default behavior: run all components
		do_ppa_flag=1
		do_camera_flag=1
		do_software_flag=1
		do_upgrade_flag=1
		return
	fi

	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h|--help)
				usage
				exit 0
				;;
			-p|--ppa-only)
				do_ppa_flag=1
				;;
			-c|--camera-only)
				do_camera_flag=1
				;;
			-s|--software-only)
				do_software_flag=1
				;;
			-u|--upgrade-only)
				do_upgrade_flag=1
				;;
			-a|--all)
				do_ppa_flag=1
				do_camera_flag=1
				do_software_flag=1
				do_upgrade_flag=1
				;;
			--no-reboot)
				do_reboot_flag=0
				;;
			--hostname=*)
				target_hostname="${1#*=}"
				do_hostname_flag=1
				;;
			*)
				echo "Unknown option: $1"
				echo "Use --help for usage information"
				exit 1
				;;
		esac
		shift
	done
}

# Main execution logic
main() {
	echo "RUBIK Pi 3 Initial Setup Script"
	echo "==============================="
	
	# Parse command line arguments
	parse_arguments "$@"
	
	# Set hostname if requested
	if [ "$do_hostname_flag" -eq 1 ]; then
		set_hostname "$target_hostname"
	fi
	
	# Execute requested components
	if [ "$do_ppa_flag" -eq 1 ]; then
		add_ppa
	fi
	
	if [ "$do_camera_flag" -eq 1 ]; then
		camera_install
	fi
	
	if [ "$do_software_flag" -eq 1 ]; then
		rubikpi_software_install
	fi
	
	if [ "$do_upgrade_flag" -eq 1 ]; then
		do_upgrade
	fi
	
	echo "Setup completed successfully!"
	
	# Handle reboot
	if [ "$do_reboot_flag" -eq 1 ]; then
		echo "System will reboot in 10 seconds..."
		sleep 10
		sudo reboot
	else
		echo "Skipping reboot as requested."
		echo "Some configurations may require a reboot to take effect."
	fi
}

# Start the script
main "$@"
