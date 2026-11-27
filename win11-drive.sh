#!/bin/bash
# Mount this machine's Windows VM disk read-only.
set -euo pipefail

image=/var/lib/libvirt/images/win11.qcow2
folder=/mnt/Win11
device=/dev/nbd0
mapper=Win11ReadOnly
state=/run/pcgeos-win11-drive
operation=${1:-mount}

case "$operation" in
    mount)
        if [[ $(LC_ALL=C virsh -c qemu:///system domid win11) != - ]]; then
            echo 'Shut down win11 before mounting its disk.' >&2
            exit 1
        fi
        ;;
    unmount|umount) ;;
    *) echo "Usage: $0 [mount|unmount]" >&2; exit 1 ;;
esac

if (( EUID != 0 )); then
    exec sudo -- "$(readlink -f "$0")" "$operation"
fi

exec 9>/run/lock/pcgeos-win11-drive.lock
flock -n 9 || { echo 'Another mount operation is running.' >&2; exit 1; }

Unmount()
{
    if mountpoint -q "$folder"; then
        case $(findmnt -nr -o SOURCE --mountpoint "$folder") in
            "${device}p3"|"/dev/mapper/$mapper") umount "$folder" || return 1 ;;
            *) echo "Another filesystem is mounted at $folder." >&2; return 1 ;;
        esac
    fi
    if [[ -e /dev/mapper/$mapper ]]; then
        cryptsetup close "$mapper" || return 1
    fi
    qemu-nbd --disconnect "$device" || return 1
    rm -f "$state"
}

if [[ $operation != mount ]]; then
    if [[ -f $state ]]; then Unmount; else echo 'Not mounted by this script.'; fi
    exit
fi

if [[ -e $state ]] || mountpoint -q "$folder"; then
    echo "Run $0 unmount first." >&2
    exit 1
fi
modprobe nbd max_part=8
if [[ -e /sys/block/nbd0/pid || -e /dev/mapper/$mapper ]]; then
    echo 'The NBD device or Windows mapping is already in use.' >&2
    exit 1
fi

mkdir -p "$folder"
qemu-nbd --read-only --format=qcow2 --connect="$device" "$image" 9>&-
trap 'result=$?; if (( result != 0 )); then Unmount || true; fi; exit "$result"' EXIT
touch "$state"
udevadm settle

# ATTENTION: This win11 image uses partition 3 for C:. Change this for another layout.
partition=${device}p3
if [[ $(blkid -p -s TYPE -o value "$partition") == BitLocker ]]; then
    echo 'BitLocker: enter the Windows recovery password when requested.'
    cryptsetup open --type bitlk --readonly "$partition" "$mapper"
    partition=/dev/mapper/$mapper
fi
mount -t ntfs-3g -o "ro,uid=${SUDO_UID:-0},gid=${SUDO_GID:-0},umask=077" "$partition" "$folder" 9>&-
echo "Windows is mounted read-only at $folder"
