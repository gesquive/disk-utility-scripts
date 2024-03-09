#!/usr/bin/env bash

# Check required dependencies
readonly DEPENDENCIES="date dd pv xz udevadm blockdev"
for dependency in ${DEPENDENCIES}; do
  if ! command -v "${dependency}" > /dev/null 2>&1; then
    echo "ERROR: command '${dependency}' not found" >&2
    exit 2
  fi
done

USAGE=\
"NAME
    $(basename "$0") -- disk image script

SYNOPSIS
    $(basename "$0") [-h] [-a] [-d] <disk> <image>

DESCRIPTION
    A script to simplify the process of making a disk image. 

OPTIONS
    -h                Show help text
    -a                Compress the image with xz
    -d                Run in debug mode
    <disk>            Disk to image (/dev/ may be omitted)
    <image>           Optional output image path

EXAMPLES
    $(basename "$0") sda /path/to/image.img
                      save disk /dev/sda to /path/to/image.img

    $(basename "$0") -c /dev/sdb /path/to/image.img.xz
                      save /dev/sdb to to /path/to/image.img.xz
"
readonly USAGE

# parse options
while getopts ':had' option; do
  case "${option}" in
    h)  echo "${USAGE}"
        exit
        ;;
    a)  readonly ARCHIVE=true
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
  echo "ERROR: Missing disk argument" >&2
  echo "${USAGE}" >&2
  exit 2
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
# Check for device
if [ ! -b "${DEVICE}" ]; then
  echo "ERROR: Device does not exist: ${DEVICE}" >&2
  exit 4
fi
IMAGE="$2"

UDEV_INFO="$(udevadm info --query=property --name="${DEVICE}")"
readonly UDEV_INFO

get_device_label() {
  # Get vendor, model, and serial number using various commands
  vendor=$(echo "${UDEV_INFO}" | grep -E 'ID_VENDOR=' | cut -d '=' -f 2)
  model=$(echo "${UDEV_INFO}" | grep -E 'ID_MODEL=' | cut -d '=' -f 2)
  serial=$(echo "${UDEV_INFO}" | grep -E 'ID_SERIAL_SHORT=' | cut -d '=' -f 2)

  label=""
  if [ -n "${vendor}" ]; then
    label+="${vendor}_"
  fi
  if [ -n "${model}" ]; then
    label+="${model}_"
  fi
  if [ -z "${label}" ]; then
    short_device="$(basename "${DEVICE}")"
    label+="${short_device}_"
  fi
  if [ -n "${serial}" ]; then
    label+="${serial}_"
  fi
  timestamp=$(date +"%Y%d%m%H%M%S")
  echo "${label}${timestamp}"
}

run() {
  if [ -n "$DEBUG" ]; then
      echo "RUN: $*"
      return 0
  fi
  "$@" || return
}

save_image() {
  if [ -z "${IMAGE}" ]; then
    # no image name was provided, make our own
    image="$(get_device_label).img"
  else
    image="${IMAGE}"
  fi


  disk_size="$(blockdev --getsize64 "${DEVICE}")"
  block_size="$(blockdev --getbsz "${DEVICE}")"
  bs=$((block_size * 4))
  if [ -z "${ARCHIVE}" ]; then
    run "dd if=${DEVICE} bs=${bs} conv=noerror,sync | pv -s ${disk_size} > ${image}"
  else
    run "dd if=${DEVICE} bs=${bs} conv=noerror,sync | xz -T0 -9 -v > ${image}.xz"
  fi
}

main() {
  save_image
}

main
