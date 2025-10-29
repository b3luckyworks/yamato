#!/usr/bin/env bash
set -euo pipefail

# Optional: etwas netter zur Kiste
ionice -c2 -n7 -p $$ >/dev/null 2>&1 || true
renice 10 $$ >/dev/null 2>&1 || true

echo "[yamato] pacman -Syu startet…"
pacman -Syu --noconfirm
echo "[yamato] pacman -Syu fertig."
