# utils

A collection of common Linux utility scripts.

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

## Usage

Make scripts executable and run directly, or add this directory to your
`PATH` to use them from anywhere:

```bash
export PATH="$PATH:$(pwd)"
```
