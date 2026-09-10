# Mac APFS mount tools

Mounts an encrypted APFS disk (FileVault) from a Mac — internal or external —
read-only, on Linux. Originally built for a persistent Linux-on-USB install
that gets plugged into many different Mac computers, so the disk picker
auto-detects whatever's connected rather than assuming a fixed machine — but
nothing here is USB-specific; it works the same on a regular install. Built
because:

- The Linux kernel's native APFS driver (`linux-apfs-rw`, installed via DKMS)
  cannot read encrypted volumes at all — only `apfs-fuse` (userspace, in
  `~/apfs-fuse/build/`, built from
  [our fork](https://github.com/katyapaki/apfs-fuse)) supports FileVault
  passphrases. The fork's only change (a `-R <path>` flag, see below) has a
  [PR open against upstream](https://github.com/sgan81/apfs-fuse/pull/223) —
  once that merges, `setup.sh` can go back to cloning upstream directly.
- Unencrypted APFS disks already auto-mount fine via a plain double-click in
  the file manager (thanks to the DKMS module), so these tools only handle
  the encrypted case.

## Setup on a fresh install

This directory is a git repo, pushed to
[github.com/katyapaki/mac-apfs-mount-tools](https://github.com/katyapaki/mac-apfs-mount-tools).
To set it up on a new machine:

```
gh repo clone katyapaki/mac-apfs-mount-tools ~/bin/mac-apfs-mount-tools
bash ~/bin/mac-apfs-mount-tools/setup.sh
```

`setup.sh` installs build deps, builds `apfs-fuse`, registers `linux-apfs-rw`
with DKMS (replacing Ubuntu's stale packaged version), enables
`user_allow_other` in `/etc/fuse.conf`, and installs the desktop launchers.
Needs `sudo`.

After editing any script here, commit and push:

```
cd ~/bin/mac-apfs-mount-tools && git add -A && git commit -m "describe the change" && git push
```

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

- The FileVault password never appears in any process's command line.
  `apfs-fuse`'s built-in `-r <password>` flag does put it in argv (visible via
  `ps aux` to any local user for as long as the mount is active), and its
  interactive prompt requires a real terminal — piping it through a pty via
  `script` was tried and proved unreliable. Instead, our fork adds a
  `-R <path>` flag: the password is written to a one-time file (`mktemp`,
  mode 600) that `apfs-fuse` reads and deletes immediately on startup, so the
  plaintext value is never a command-line argument to anything.
- Genuine integration with Thunar's device sidebar (double-click the actual
  drive icon to get a password prompt) isn't achievable without writing a
  custom udisks2/GVfs backend — `udisks2` only knows the kernel's own
  mount(8) support, which doesn't do encrypted APFS at all. The Thunar
  bookmark is the practical middle ground.
- `linux-apfs-rw` (kernel module) is registered with DKMS with
  `AUTOINSTALL="yes"`, so it rebuilds automatically on future kernel
  upgrades — no manual steps needed for that part.

## License

[MIT](LICENSE)
