#!/bin/sh
# Unmount the JETI transmitter's USB storage before unplugging it.
#
# Run it sourced, so it can move your shell out of the TX first:
#     . ~/JS/sh/umount.sh        (or: source ~/JS/sh/umount.sh)
# Run as "sh umount.sh" it works too, unless your shell's current
# directory is on the TX (e.g. ~/RS): then the mount stays busy.
#
# Because it may be sourced, it must not use "set -e" or "exit":
# either would close your shell.

jeti_umount() {
    local disk parts p

    # the TX's disk reports model DC_DS_Flash; its name (sdc, sde ...) changes
    disk=$(lsblk -dnpo NAME,MODEL | awk '$2 ~ /^DC_DS/ {print $1; exit}')
    if [ -z "$disk" ]; then
        echo "No JETI transmitter (DC_DS_Flash) found"
        return 1
    fi

    lsblk -o NAME,SIZE,MODEL,MOUNTPOINT "$disk"
    parts=$(lsblk -lnpo NAME,MOUNTPOINT "$disk" | awk 'NF == 2 {print $1}')
    if [ -z "$parts" ]; then
        echo "$disk is not mounted: safe to unplug"
        return 0
    fi

    printf "Press enter to unmount %s or ^C to abort: " "$(echo $parts)"
    read -r _ || return 1

    # leave the TX, or this shell keeps it busy (works only when sourced)
    cd ~/JS || return 1

    # udisksctl needs no sudo for removable drives
    for p in $parts; do
        if ! udisksctl unmount -b "$p"; then
            echo "$p is still in use by:"
            fuser -vm "$p"
            echo "If one of those is this shell, run it as: . ~/JS/sh/umount.sh"
            return 1
        fi
    done

    # power the drive down, like "safely remove" in a file manager
    if udisksctl power-off -b "$disk"; then
        echo "Done: safe to unplug"
    else
        echo "Unmounted, but power-off failed: still safe to unplug"
        return 1
    fi
}

jeti_umount
unset -f jeti_umount
