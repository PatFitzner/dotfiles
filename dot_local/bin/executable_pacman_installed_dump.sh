#!/usr/bin/env bash
# Write a snapshot of explicitly-installed packages to ~/.local/bin/pacman_installed_packages.txt
# (truncates on each run; this file is intentionally not tracked by chezmoi/git).
set -euo pipefail
out="$HOME/.local/bin/pacman_installed_packages.txt"
pacman -Qqe > "$out"
