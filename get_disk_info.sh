#!/usr/bin/env bash

# Check required dependencies
readonly DEPENDENCIES="udevadm blockdev numfmt"
for dependency in ${DEPENDENCIES}; do
  if ! command -v "${dependency}" > /dev/null 2>&1; then
    echo "ERROR: command '${dependency}' not found" >&2
    exit 2
  fi
done

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

# Check if the device path is provided as an argument
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi

device="$1"

# Check if the device exists
if [[ ! -b "$device" ]]; then
    echo "Device $device does not exist"
    exit 1
fi

# Get vendor, model, and serial number using various commands
vendor=$(udevadm info --query=property --name="$device" | grep -E 'ID_VENDOR=' | cut -d '=' -f 2)
model=$(udevadm info --query=property --name="$device" | grep -E 'ID_MODEL=' | cut -d '=' -f 2)
serial=$(udevadm info --query=property --name="$device" | grep -E 'ID_SERIAL_SHORT=' | cut -d '=' -f 2)
disk_size=$(blockdev --getsize64 "$device")

# Convert disk size to human-readable format
disk_size_human=$(numfmt --to=iec-i --suffix=B "$disk_size")

# Output the collected information
echo "Vendor: $vendor"
echo "Model: $model"
echo "Serial Number: $serial"
echo "Disk Size: $disk_size_human"
