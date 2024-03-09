#!/usr/bin/env bash

# Check required dependencies
readonly DEPENDENCIES="shred udevadm blockdev numfmt grep sha256sum"
for dependency in ${DEPENDENCIES}; do
  if ! command -v "${dependency}" > /dev/null 2>&1; then
    echo "ERROR: command '${dependency}' not found" >&2
    exit 2
  fi
done

USAGE=\
"NAME
    $(basename "$0") -- disk shred script

SYNOPSIS
    $(basename "$0") [-h] [-f] [-s] [-d] <disk>

DESCRIPTION
    A script to simplify the process of shredding disks. Only intended for use
    on disks which do not contain any wanted data, such as old disks or disks which
    are being tested or re-purposed.

    The script runs in dry-run mode by default, so you can check the disk
    you are wiping is correct.

    In order to wipe the disk, you will need to provide the -f option.

OPTIONS
    -h                Show help text
    -f                Force script to run in destructive mode
                      ALL DATA ON THE DISK WILL BE LOST!
    -s                Skip disk initialization
    -d                Run in debug mode
    <disk>            Disk to burn-in (/dev/ may be omitted)

EXAMPLES
    $(basename "$0") sda
                      run on disk /dev/sda

    $(basename "$0") -f /dev/sdb
                      run in destructive mode on disk /dev/sdb
"
readonly USAGE

# parse options
while getopts ':hfsd' option; do
  case "${option}" in
    h)  echo "${USAGE}"
        exit
        ;;
    f)  readonly FORCE=true
        ;;
    s)  readonly SKIP_INIT=true
        ;;
    d)  readonly DEBUG=true
        ;;
    :)  printf 'Missing argument for -%s\n' "${OPTARG}" >&2
        echo "${USAGE}" >&2
        exit 2
        ;;
   \?)  printf 'Illegal option: -%s\n' "${OPTARG}" >&2
        echo "${USAGE}" >&2
        exit 2
        ;;
  esac
done
shift $(( OPTIND - 1 ))

if [ -z "$1" ]; then
  echo "ERROR: Missing disk path argument" >&2
  echo "${USAGE}" >&2
  exit 3
fi

# Check if running as root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: Must be run as root" >&2
  exit 2
fi

DEVICE="$1"
# prepend /dev/ if necessary
if ! printf '%s' "${DEVICE}" | grep "/dev/\w*" > /dev/null 2>&1; then
  DEVICE="/dev/${DEVICE}"
fi
readonly DEVICE
# Check for block device
if ! [ -b "${DEVICE}" ]; then
  echo "the device ${DEVICE} is not a block device" >&2
  exit 4
fi

UDEV_INFO="$(udevadm info --query=property --name="${DEVICE}")"
readonly UDEV_INFO

print_device_info() {
  # Get disk model
  disk_model=$(echo "${UDEV_INFO}" | grep -E 'ID_MODEL=' | cut -d '=' -f 2)

  # Get disk serial number
  disk_serial=$(echo "${UDEV_INFO}" | grep -E 'ID_SERIAL_SHORT=' | cut -d '=' -f 2)
  disk_size=$(blockdev --getsize64 "${DEVICE}")
  disk_size=$(numfmt --to=iec-i --suffix=B "$disk_size")

  echo "Device:                 ${DEVICE}"
  echo "Drive Model:            ${disk_model}"
  echo "Serial Number:          ${disk_serial}"
  echo "Disk Size:              ${disk_size}"
  echo ""
}

confirm_continue() {
    if [ -n "${FORCE}" ]; then
        return 0  # Skip user interaction
    fi

    print_device_info

    read -r -p "Do you want to continue? [y/N]: " choice
    case "$choice" in
        [Yy]|[Yy][Ee][Ss]) return 0;;  # Continue
        *) return 1;;  # Do not continue
    esac
}

run() {
  if [ -n "$DEBUG" ]; then
      echo "RUN: $*"
      return 0
  fi
  "$@" || return
}

shred_disk() {
  run "shred -vz \"${DEVICE}\""
}

get_partition_label() {
  disk_serial=$(echo "${UDEV_INFO}" | grep -E 'ID_SERIAL_SHORT=' | cut -d '=' -f 2)
  label=$(echo "${disk_serial}" | sha256sum)
  formatted_label=$(echo "$label" | tr '[:lower:]' '[:upper:]' | tr -d '-')

  # Truncate to 16 characters
  formatted_label="${formatted_label:0:16}"

  echo "$formatted_label"
}

init_disk() {
  if [ -n "$SKIP_INIT" ]; then
    return 0
  fi

  label=$(get_partition_label)
  run "mkfs.ntfs -f -L \"${label}\" \"${DEVICE}\""
}

main() {
  confirm_continue || exit 0
  shred_disk
  init_disk
}

main
