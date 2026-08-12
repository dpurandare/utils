# utils

A collection of common Linux utility scripts.

> Tested on Ubuntu 24.04 LTS. The dpkg/snap code paths are exercised
> directly; the rpm/dnf (Fedora/RHEL) and pacman (Arch) paths in
> `installed_app_sizes.sh` are best-effort and untested.

## Scripts

### `sysinfo.sh`

Displays system information: hostname, OS, kernel, CPU, RAM (including
speed), disk usage, and GPU details.

```bash
./sysinfo.sh          # basic info
sudo ./sysinfo.sh      # includes RAM speed (requires dmidecode/root)
```

### `top_level_sizes.sh`

Shows the size of each top-level item in a directory, sorted largest first.

```bash
./top_level_sizes.sh [DIRECTORY]   # defaults to current directory
```

### `installed_app_sizes.sh`

Lists installed applications and their sizes, sorted largest first. By
default this shows a curated "applications" view: only packages you
explicitly installed via apt/dpkg or snap, excluding libraries,
dev/doc/locale packages, dependencies, and stuff that ships with the base OS
image (distro meta-packages, bootloader packages, snap content/base packs,
Canonical's default snap-store/firmware-updater, etc.).

Supports dpkg (Debian/Ubuntu), rpm/dnf (Fedora/RHEL), and pacman (Arch) as
the native package manager, plus snap by default and flatpak with `-a`.

```bash
./installed_app_sizes.sh              # curated apps view, largest first
./installed_app_sizes.sh -n 20        # top 20 only
./installed_app_sizes.sh -a           # also include flatpak
./installed_app_sizes.sh -A           # show everything, unfiltered
```

## Usage

Make scripts executable and run directly, or add this directory to your
`PATH` to use them from anywhere:

```bash
export PATH="$PATH:$(pwd)"
```
