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
#
# Coded by Claude Code with guidance from D. McQueeney

jeti_umount() {
    local disk parts p

    # the TX's disk reports model DC_DS_Flash; its name (sdc, sde ...) changes
    disk=$(lsblk -dnpo NAME,MODEL | awk '$2 ~ /^DC_DS/ {print $1; exit}')
    if [ -z "$disk" ]; then
        echo "No JETI transmitter (DC_DS_Flash) found"
        return 1
    fi

    # every mount of every partition: a partition can be mounted more than
    # once (the desktop's /media/$USER/... and sh/ds16.sh's /media/ds16),
    # and lsblk shows only one of them
    parts=$(lsblk -lnpo NAME "$disk" | tail -n +2)
    mounts() {
        for p in $parts; do
            findmnt -rno SOURCE,TARGET | awk -v p="$p" '$1 == p'
        done
    }
    lsblk -o NAME,SIZE,MODEL "$disk"
    if [ -z "$(mounts)" ]; then
        echo "$disk is not mounted: safe to unplug"
        return 0
    fi
    echo "Mounted:"
    mounts | sed 's/^/    /'

    printf "Press enter to unmount all of them or ^C to abort: "
    read -r _ || return 1

    # leave the TX, or this shell keeps it busy (works only when sourced)
    cd ~/JS || return 1

    # udisksctl needs no sudo for the desktop's mounts; a mount made with
    # sudo mount (sh/ds16.sh) may need sudo umount
    local n src tgt
    n=0
    while [ -n "$(mounts)" ] && [ $n -lt 10 ]; do
        n=$((n + 1))
        set -- $(mounts | head -n 1)
        src=$1 tgt=$2
        if ! udisksctl unmount -b "$src" 2>/dev/null; then
            echo "Unmounting $tgt with sudo"
            if ! sudo umount "$tgt"; then
                echo "$tgt is still in use by:"
                fuser -vm "$tgt"
                echo "If one of those is this shell, run it as: . ~/JS/sh/umount.sh"
                return 1
            fi
        fi
    done
    if [ -n "$(mounts)" ]; then
        echo "NOT safe to unplug, still mounted:"
        mounts | sed 's/^/    /'
        return 1
    fi

    # power the drive down, like "safely remove" in a file manager
    if udisksctl power-off -b "$disk"; then
        echo "Done: safe to unplug"
    else
        echo "Power-off failed, but nothing is mounted: safe to unplug"
        return 1
    fi
}

jeti_umount
unset -f jeti_umount mounts
