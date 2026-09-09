#!/bin/bash
# Run as root (via pkexec), one call covering both steps so only one
# authentication is needed: check encryption, then mount if it's encrypted.
# Usage: mac-apfs-mount-helper.sh <apfsutil> <apfs-fuse> <device> <mountpoint> <uid> <gid> <passfile>
# <passfile> is a one-time file holding the password; apfs-fuse's -R flag
# reads and deletes it itself. The password never appears in any argv here.
# Exit codes: 0 = mounted, 42 = device isn't encrypted (nothing done), 1 = mount failed.
set -u

APFSUTIL="$1" APFS_FUSE="$2" DEVICE="$3" MOUNTPOINT="$4" MOUNT_UID="$5" MOUNT_GID="$6" PASSFILE="$7"

if ! "$APFSUTIL" "$DEVICE" 2>/dev/null | grep -Eq "FileVault:\s*Yes"; then
    rm -f "$PASSFILE"
    exit 42
fi

mkdir -p "$MOUNTPOINT"
"$APFS_FUSE" -o "ro,allow_other,uid=$MOUNT_UID,gid=$MOUNT_GID" -R "$PASSFILE" "$DEVICE" "$MOUNTPOINT"
