#!/usr/bin/env bash
# List installed applications and their sizes, sorted largest first.
#
# By default this shows only apps you explicitly installed via apt/dpkg or
# snap (not pulled in as a dependency, and not part of the base OS image),
# hiding libraries/dev headers/locales/docs/runtime bases. Pass -A to see
# everything instead.
#
# Supports dpkg (Debian/Ubuntu), rpm/dnf (Fedora/RHEL), and pacman (Arch) as
# the native package manager, plus snap by default and flatpak with -a.

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [-n COUNT] [-a] [-A] [-h]

  -n COUNT   Show only the top COUNT largest entries per source (default: all)
  -a         Also include flatpak packages, if installed
  -A         Show ALL packages (including libraries/dependencies/snap bases),
             not just the curated "applications" view
  -h         Show this help
EOF
}

top_n=""
include_extra=0
show_all=0

while getopts ":n:aAh" opt; do
    case "$opt" in
        n) top_n="$OPTARG" ;;
        a) include_extra=1 ;;
        A) show_all=1 ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

hr() { printf '%s\n' "----------------------------------------"; }

limit() {
    if [[ -n "$top_n" ]]; then
        head -n "$top_n"
    else
        cat
    fi
}

# Patterns that are almost never what someone means by "an application":
# libraries, dev/debug headers, docs, locales, kernel packages, language
# runtimes' internal packages, distro meta-packages, and boot infrastructure
# that ships as part of the base OS install rather than being chosen by a
# user.
NOISE_REGEX='^(lib[0-9a-z.+-]*|.*-dev|.*-dbg|.*-dbgsym|.*-doc|.*-docs|.*-data|.*-common|.*-locale.*|.*-l10n.*|linux-.*|.*-headers-.*|.*-modules-.*|python3-.*|perl-.*|gir1\.2-.*|fonts-.*|hyphen-.*|mythes-.*|ibus-table-.*|language-pack-.*|ubuntu-.*|debian-.*|fedora-.*|centos-.*|rocky-.*|almalinux-.*|opensuse-.*|grub-.*|shim-signed|efibootmgr|os-prober|plymouth.*|m17n-.*)$'

names_file=$(mktemp)
trap 'rm -f "$names_file"' EXIT

format_sizes() {
    # stdin: "<size>\t<name>" (size in bytes) -> human readable, sorted desc
    sort -rn \
        | limit \
        | numfmt --field=1 --to=iec --suffix=B --padding=8 \
        | awk -F'\t' '{ printf "%-10s %s\n", $1, $2 }'
}

if command -v dpkg-query >/dev/null 2>&1; then
    if [[ "$show_all" -eq 1 ]]; then
        echo "=== Debian/Ubuntu Packages (dpkg, all) ==="
        dpkg-query -Wf '${Installed-Size}\t${Package}\n' 2>/dev/null \
            | awk -F'\t' '{ printf "%d\t%s\n", $1*1024, $2 }' \
            | format_sizes
    else
        echo "=== Debian/Ubuntu Applications (dpkg, manually installed) ==="
        comm -12 \
            <(apt-mark showmanual 2>/dev/null | sort) \
            <(dpkg-query -Wf '${Package}\t${Priority}\n' 2>/dev/null \
                | awk -F'\t' '$2!="required" && $2!="important"{print $1}' | sort) \
            | grep -vE "$NOISE_REGEX" > "$names_file"
        dpkg-query -Wf '${Installed-Size}\t${Package}\n' 2>/dev/null \
            | awk -F'\t' -v names="$names_file" '
                BEGIN { while ((getline line < names) > 0) keep[line] = 1 }
                keep[$2] { printf "%d\t%s\n", $1*1024, $2 }
            ' \
            | format_sizes
    fi
    hr
elif command -v rpm >/dev/null 2>&1; then
    if [[ "$show_all" -eq 0 ]] && command -v dnf >/dev/null 2>&1; then
        echo "=== RPM Applications (dnf, user-installed) ==="
        dnf repoquery --userinstalled -q --qf '%{NAME}\n' 2>/dev/null \
            | grep -vE "$NOISE_REGEX" > "$names_file"
        rpm -qa --qf '%{SIZE}\t%{NAME}\n' 2>/dev/null \
            | awk -F'\t' -v names="$names_file" '
                BEGIN { while ((getline line < names) > 0) keep[line] = 1 }
                keep[$2] { print }
            ' \
            | format_sizes
    else
        echo "=== RPM Packages (rpm, all) ==="
        rpm -qa --qf '%{SIZE}\t%{NAME}\n' 2>/dev/null | format_sizes
    fi
    hr
elif command -v pacman >/dev/null 2>&1; then
    if [[ "$show_all" -eq 1 ]]; then
        echo "=== Arch Packages (pacman, all) ==="
        pacman -Qi 2>/dev/null \
            | awk -F': ' '/^Name/{name=$2} /^Installed Size/{print $2"\t"name}' \
            > "$names_file"
    else
        echo "=== Arch Applications (pacman, explicitly installed) ==="
        pacman -Qei 2>/dev/null \
            | awk -F': ' '/^Name/{name=$2} /^Installed Size/{print $2"\t"name}' \
            | grep -vE "$NOISE_REGEX" \
            > "$names_file"
    fi
    numfmt --field=1 --from=iec --to=iec --suffix=B --padding=8 < "$names_file" 2>/dev/null \
        | sort -rh \
        | limit \
        | awk -F'\t' '{ printf "%-10s %s\n", $1, $2 }'
    hr
else
    echo "No supported package manager (dpkg, rpm, pacman) found." >&2
fi

# Canonical's own infrastructure snaps that ship by default on stock Ubuntu
# Desktop (content/base packs, the app store, the firmware updater, etc.) -
# not something a user chose to install.
SNAP_NOISE_REGEX='^(bare|core[0-9]*|snapd|gtk-common-themes|gnome-[0-9].*|mesa-[0-9].*|snap-store|firmware-updater|snapd-desktop-integration|snapd-control|prompting-client)$'

if command -v snap >/dev/null 2>&1; then
    if [[ "$show_all" -eq 1 ]]; then
        echo "=== Snap Packages (all) ==="
    else
        echo "=== Snap Applications ==="
    fi
    snap list 2>/dev/null | awk 'NR>1{print $1}' | while read -r name; do
        if [[ "$show_all" -eq 0 ]]; then
            [[ "$name" =~ $SNAP_NOISE_REGEX ]] && continue
            yaml="/snap/$name/current/meta/snap.yaml"
            # Runtime bases/content/kernel/gadget snaps have no "apps:"
            # section (nothing runnable) - skip those, keep real apps.
            grep -q '^apps:' "$yaml" 2>/dev/null || continue
        fi
        size=$(du -sh "/snap/$name" 2>/dev/null | cut -f1) || true
        [[ -n "$size" ]] && printf '%s\t%s\n' "$size" "$name"
    done | sort -rh | limit | awk -F'\t' '{ printf "%-10s %s\n", $1, $2 }'
    hr
fi

if [[ "$include_extra" -eq 1 ]]; then
    if command -v flatpak >/dev/null 2>&1; then
        echo "=== Flatpak Packages ==="
        flatpak list --columns=size,application 2>/dev/null \
            | sort -rh \
            | limit \
            | awk -F'\t' '{ printf "%-10s %s\n", $1, $2 }'
        hr
    fi
fi
