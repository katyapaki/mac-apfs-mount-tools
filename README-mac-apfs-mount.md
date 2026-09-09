# Mac APFS mount tools

Mounts an encrypted APFS disk (FileVault) from a Mac — internal or external —
read-only, from this Linux-on-USB install. Built because:

- The Linux kernel's native APFS driver (`linux-apfs-rw`, installed via DKMS)
  cannot read encrypted volumes at all — only `apfs-fuse` (userspace, in
  `~/apfs-fuse/build/`) supports FileVault passphrases.
- Unencrypted APFS disks already auto-mount fine via a plain double-click in
  the file manager (thanks to the DKMS module), so these tools only handle
  the encrypted case.

## Setup on a fresh install

Run `bash setup.sh` — installs build deps, builds `apfs-fuse`, registers
`linux-apfs-rw` with DKMS (replacing Ubuntu's stale packaged version), enables
`user_allow_other` in `/etc/fuse.conf`, and installs the desktop launchers.
Needs `sudo`.

## Usage

Launchers live in the Applications menu and on the Desktop ("Mount Mac Disk"
/ "Unmount Mac Disk"), backed by these scripts:

- `mount-mac-disk.sh` — lists APFS partitions found on the system, prompts
  for a mount point (remembered per-device) and a password, mounts via
  `apfs-fuse`, adds a Thunar sidebar bookmark, opens it in Thunar.
- `unmount-mac-disk.sh` — unmounts one of the currently-mounted disks
  (prompts you to pick if more than one is active), removes the bookmark.
- `mac-apfs-mount-helper.sh` — runs as root via `pkexec` (invoked by the
  mount script). Checks whether the selected device is actually encrypted
  and mounts it if so, all in one privileged call so there's only ever one
  authentication prompt.
- `mac-apfs-common.sh` — shared config paths + Thunar bookmark helpers,
  sourced by the two user-facing scripts.

State lives under `~/.config/mac-apfs-mount/`:
`mounts/<device>` tracks what's currently mounted and where;
`lastpath/<device>` remembers each device's last-used mount point.

**The file manager's own Unmount/Eject won't work** on these mounts — they're
plain `pkexec`-owned FUSE mounts, not udisks2-managed devices. Always use the
"Unmount Mac Disk" launcher.

## Known trade-offs

- The FileVault password is passed as `apfs-fuse -r <password>`, so it's
  visible via `ps aux` to any other local user on the machine for as long as
  the mount is active. Acceptable for a personal single-user boot stick;
  don't leave a disk mounted on a machine other people can poke at. (The
  interactive password prompt was tried instead, piped through a pty via
  `script`, but `apfs-fuse`'s `GetPassword()` proved unreliable outside a
  real interactive terminal — `-r` is simpler and was chosen deliberately.)
- Genuine integration with Thunar's device sidebar (double-click the actual
  drive icon to get a password prompt) isn't achievable without writing a
  custom udisks2/GVfs backend — `udisks2` only knows the kernel's own
  mount(8) support, which doesn't do encrypted APFS at all. The Thunar
  bookmark is the practical middle ground.
- `linux-apfs-rw` (kernel module) is registered with DKMS with
  `AUTOINSTALL="yes"`, so it rebuilds automatically on future kernel
  upgrades on this machine — no manual steps needed for that part.
