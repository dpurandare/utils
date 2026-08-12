#!/usr/bin/env bash
# Show size of each top-level item in a directory, sorted largest first.

set -euo pipefail

usage() {
    echo "Usage: $0 [DIRECTORY]"
    echo "If DIRECTORY is omitted, the current directory is used."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

target_dir="${1:-.}"

if [[ ! -d "$target_dir" ]]; then
    echo "Error: '$target_dir' is not a directory or does not exist." >&2
    exit 1
fi

# Find immediate children (including hidden ones), compute size for each, then sort.
if ! find "$target_dir" -mindepth 1 -maxdepth 1 -print0 | grep -qz .; then
    echo "No files or folders found in: $target_dir"
    exit 0
fi

find "$target_dir" -mindepth 1 -maxdepth 1 -print0 \
    | du -h --max-depth=0 --files0-from=- 2>/dev/null \
    | sort -hr
