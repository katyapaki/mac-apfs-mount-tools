#!/bin/bash
# Detect an APFS disk (internal or external) and mount it read-only via apfs-fuse.
# Supports multiple disks mounted at once: each device gets its own tracked
# mount point under CONFIG_DIR, keyed by device name (e.g. "sda2").
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/mac-apfs-common.sh"

APFS_FUSE="$HOME/apfs-fuse/build/apfs-fuse"
APFSUTIL="$HOME/apfs-fuse/build/apfsutil"
MOUNT_HELPER="$SCRIPT_DIR/mac-apfs-mount-helper.sh"

# Drop stale entries for mounts that no longer exist (e.g. unmounted from a terminal).
for f in "$MOUNTS_DIR"/*; do
    [ -e "$f" ] || continue
    mountpoint -q "$(cat "$f")" 2>/dev/null || rm -f "$f"
done

if [ ! -x "$APFS_FUSE" ] || [ ! -x "$APFSUTIL" ]; then
    zenity --error --title="Mac Disk" --text="apfs-fuse/apfsutil not found under $HOME/apfs-fuse/build" --width=380
    exit 1
fi

mapfile -t apfs_parts < <(lsblk -rno NAME,TYPE,FSTYPE | awk '$2=="part" && $3=="apfs" {print $1}')

if [ "${#apfs_parts[@]}" -eq 0 ]; then
    zenity --error --title="Mac Disk" --text="No APFS partitions found on this machine." --width=350
    exit 1
fi

# Whether each one is actually encrypted is only known after authenticating
# (checking requires root), so that's deferred to the single mount step below
# rather than done here — this keeps the whole flow to one auth prompt.
if [ "${#apfs_parts[@]}" -eq 1 ]; then
    DEVNAME="${apfs_parts[0]}"
else
    LIST_ARGS=()
    for name in "${apfs_parts[@]}"; do
        size=$(lsblk -rno SIZE "/dev/$name")
        pk=$(lsblk -rno PKNAME "/dev/$name")
        tran=$(lsblk -rno TRAN "/dev/$pk")
        status="not mounted"
        [ -f "$MOUNTS_DIR/$name" ] && status="mounted at $(cat "$MOUNTS_DIR/$name")"
        LIST_ARGS+=("/dev/$name" "$size" "${tran:-?}" "$status")
    done
    DEVPATH=$(zenity --list --title="Select APFS Disk" \
        --text="APFS partitions found (internal or external):" \
        --column="Device" --column="Size" --column="Connection" --column="Status" --print-column=1 \
        --width=480 --height=250 \
        "${LIST_ARGS[@]}")
    [ -z "$DEVPATH" ] && exit 1
    DEVNAME=$(basename "$DEVPATH")
fi

DEVICE="/dev/$DEVNAME"

# If this specific device is already mounted, just reopen it instead of remounting.
if [ -f "$MOUNTS_DIR/$DEVNAME" ]; then
    EXISTING=$(cat "$MOUNTS_DIR/$DEVNAME")
    zenity --info --title="Mac Disk" \
        --text="$DEVICE is already mounted at $EXISTING\n\nTo unmount, use the \"Unmount Mac Disk\" launcher — the file manager's own Unmount/Eject option won't work on this mount." \
        --width=380
    thunar "$EXISTING" &
    exit 0
fi

DEFAULT_MOUNTPOINT="$HOME/apfs_mnt_$DEVNAME"
[ -f "$LASTPATH_DIR/$DEVNAME" ] && DEFAULT_MOUNTPOINT=$(cat "$LASTPATH_DIR/$DEVNAME")

MOUNTPOINT=$(zenity --entry --title="Mac Disk" --text="Mount point for $DEVICE:" --entry-text="$DEFAULT_MOUNTPOINT")
[ -z "$MOUNTPOINT" ] && exit 1
case "$MOUNTPOINT" in
    "~") MOUNTPOINT="$HOME" ;;
    "~/"*) MOUNTPOINT="$HOME/${MOUNTPOINT#\~/}" ;;
esac

# Refuse a mount point already in use by another active mount.
for f in "$MOUNTS_DIR"/*; do
    [ -e "$f" ] || continue
    if [ "$(cat "$f")" = "$MOUNTPOINT" ] && [ "$(basename "$f")" != "$DEVNAME" ]; then
        zenity --error --title="Mac Disk" --text="$MOUNTPOINT is already used by /dev/$(basename "$f")." --width=350
        exit 1
    fi
done

echo "$MOUNTPOINT" > "$LASTPATH_DIR/$DEVNAME"

PASS=$(zenity --password --title="Mac Disk" \
    --text="Enter the password for $DEVICE:\n\n(If this disk turns out not to be encrypted, the password will simply be ignored.)")
if [ -z "$PASS" ]; then
    exit 1
fi

# Write the password to a private one-time file rather than passing it as a
# command argument, so it never appears in `ps aux` for any process. apfs-fuse's
# -R flag (via the helper) reads and deletes this file itself; the trap below
# is just a safety net for exit paths that never reach that point (e.g. the
# pkexec authentication being cancelled).
PASSFILE=$(mktemp)
trap 'rm -f "$PASSFILE"' EXIT
printf '%s\n' "$PASS" > "$PASSFILE"
unset PASS

# One pkexec call covers checking encryption and mounting, so there's only
# ever one authentication prompt regardless of what it finds.
pkexec "$MOUNT_HELPER" "$APFSUTIL" "$APFS_FUSE" "$DEVICE" "$MOUNTPOINT" "$(id -u)" "$(id -g)" "$PASSFILE"
RESULT=$?

if [ "$RESULT" -eq 42 ]; then
    zenity --error --title="Mac Disk" \
        --text="$DEVICE isn't encrypted.\n\nIt already mounts automatically — just double-click it in the file manager." \
        --width=380
    exit 1
elif [ "$RESULT" -eq 0 ] && mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
    echo "$MOUNTPOINT" > "$MOUNTS_DIR/$DEVNAME"
    add_bookmark "$MOUNTPOINT" "Mac Disk ($DEVNAME)"
    zenity --info --title="Mac Disk" \
        --text="Mounted $DEVICE at $MOUNTPOINT\n\nTo unmount, use the \"Unmount Mac Disk\" launcher — the file manager's own Unmount/Eject option won't work on this mount." \
        --width=380
    thunar "$MOUNTPOINT" &
else
    zenity --error --title="Mac Disk" \
        --text="Failed to mount $DEVICE.\n\nWrong password, or this volume isn't supported." \
        --width=350
    exit 1
fi
