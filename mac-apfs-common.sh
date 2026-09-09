#!/bin/bash
# Shared config paths and Thunar sidebar bookmark helpers for
# mount-mac-disk.sh and unmount-mac-disk.sh. Meant to be sourced, not run.

CONFIG_DIR="$HOME/.config/mac-apfs-mount"
MOUNTS_DIR="$CONFIG_DIR/mounts"       # one file per ACTIVE mount: <devname> -> mount path
LASTPATH_DIR="$CONFIG_DIR/lastpath"   # one file per device remembering its last-used mount path
BOOKMARKS_FILE="$HOME/.config/gtk-3.0/bookmarks"

mkdir -p "$MOUNTS_DIR" "$LASTPATH_DIR" "$(dirname "$BOOKMARKS_FILE")"
touch "$BOOKMARKS_FILE"

path_to_uri() {
    python3 -c "import urllib.parse,sys; print('file://' + urllib.parse.quote(sys.argv[1]))" "$1"
}

# add_bookmark <path> <label>: add (or refresh) a Thunar/GTK sidebar bookmark.
add_bookmark() {
    local path="$1" label="$2" uri
    uri=$(path_to_uri "$path")
    remove_bookmark "$path"
    echo "$uri $label" >> "$BOOKMARKS_FILE"
}

# remove_bookmark <path>: drop the sidebar bookmark for that path, if any.
remove_bookmark() {
    local path="$1" uri tmp
    uri=$(path_to_uri "$path")
    tmp=$(mktemp "$BOOKMARKS_FILE.XXXXXX")
    grep -vF "$uri" "$BOOKMARKS_FILE" > "$tmp" 2>/dev/null
    mv "$tmp" "$BOOKMARKS_FILE"
}
