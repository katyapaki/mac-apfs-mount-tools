#!/bin/bash
# Unmount one of the disks currently mounted by mount-mac-disk.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-apfs-common.sh"

# Drop stale entries for mounts that no longer exist.
for f in "$MOUNTS_DIR"/*; do
    [ -e "$f" ] || continue
    mountpoint -q "$(cat "$f")" 2>/dev/null || rm -f "$f"
done

mapfile -t active < <(ls "$MOUNTS_DIR" 2>/dev/null)

if [ "${#active[@]}" -eq 0 ]; then
    zenity --info --title="Mac Disk" --text="Nothing is currently mounted." --width=300
    exit 0
fi

if [ "${#active[@]}" -eq 1 ]; then
    DEVNAME="${active[0]}"
else
    LIST_ARGS=()
    for name in "${active[@]}"; do
        LIST_ARGS+=("/dev/$name" "$(cat "$MOUNTS_DIR/$name")")
    done
    DEVPATH=$(zenity --list --title="Unmount Mac Disk" \
        --text="Multiple disks are mounted. Choose one to unmount:" \
        --column="Device" --column="Mount point" --print-column=1 \
        --width=420 --height=250 \
        "${LIST_ARGS[@]}")
    [ -z "$DEVPATH" ] && exit 0
    DEVNAME=$(basename "$DEVPATH")
fi

MOUNTPOINT=$(cat "$MOUNTS_DIR/$DEVNAME")

if pkexec fusermount3 -u "$MOUNTPOINT"; then
    rm -f "$MOUNTS_DIR/$DEVNAME"
    remove_bookmark "$MOUNTPOINT"
    zenity --info --title="Mac Disk" --text="Unmounted /dev/$DEVNAME from $MOUNTPOINT." --width=300
else
    zenity --error --title="Mac Disk" \
        --text="Failed to unmount /dev/$DEVNAME.\n\nMake sure no application has files open in $MOUNTPOINT." \
        --width=350
    exit 1
fi
