#!/bin/sh
# Mount the DS-16's USB storage on /media/ds16 (it doesn't mount itself
# like the DS-24 does). Unmount it with sh/umount.sh as for the DS-24.
#
# Both transmitters report the same disk model (DC_DS_Flash), and the
# /dev name (sdc, sde, sdf ...) changes from plug to plug, so the DS-16 is
# found by its FAT volume ID, which doesn't change.
set -e

ID=6BC5-4931            # the DS-16's volume ID (the DS-24 is 6138-3633)
MNT=/media/ds16

dev=$(lsblk -lnpo NAME,UUID | awk -v id="$ID" '$2 == id {print $1; exit}')
if [ -z "$dev" ]; then
    echo "DS-16 (volume $ID) not found. JETI disks connected:"
    lsblk -o NAME,SIZE,MODEL,UUID,MOUNTPOINT | awk 'NR == 1 || /DC_DS/ {print; f = 1; next} f && /^[└├]/ {print; next} {f = 0}'
    exit 1
fi

where=$(lsblk -no MOUNTPOINT "$dev" | head -n 1)
if [ -n "$where" ]; then
    echo "DS-16 ($dev) is already mounted on $where"
    exit 0
fi

sudo mkdir -p "$MNT"
# a DS-16 unplugged while mounted leaves its mount behind, under a /dev
# name that no longer exists; mounts stack, so clear those first
for src in $(findmnt -rno SOURCE,TARGET | awk -v m="$MNT" '$2 == m {print $1}'); do
    if [ -e "$src" ]; then
        echo "Something else ($src) is mounted on $MNT"
        exit 1
    fi
done
while mountpoint -q "$MNT"; do
    echo "Clearing a stale mount on $MNT"
    sudo umount -l "$MNT"
done
# vfat has no owners: give the files to you, so you can write without sudo
sudo mount -o uid="$(id -u)",gid="$(id -g)" "$dev" "$MNT"
echo "DS-16 ($dev) mounted on $MNT"
