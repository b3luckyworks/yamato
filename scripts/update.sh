#!/usr/bin/env bash
set -euo pipefail
log(){ printf "[yamato-pacman] %s\n" "$*"; }

# Nur als Client laufen
[[ -f /etc/yamato/is_client ]] || { log "no client marker -> exit"; exit 0; }

# Optional: Mirrors optimieren
if command -v reflector >/dev/null 2>&1; then
  log "refreshing mirrors via reflector…"
  reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist || true
fi

log "system upgrade (pacman)…"
pacman -Syyu --noconfirm

# Cache aufräumen (3 Versionen behalten)
if command -v paccache >/dev/null 2>&1; then
  log "clean cache (paccache)…"
  paccache -rk3 || true
fi

# Reboot-Hinweis, wenn Kernel-Version wechselte
INSTALLED_KERNEL=$(pacman -Q linux 2>/dev/null | awk '{print $2}' | cut -d- -f1 || true)
RUNNING_KERNEL=$(uname -r | cut -d- -f1)
if [[ -n "$INSTALLED_KERNEL" && "$INSTALLED_KERNEL" != "$RUNNING_KERNEL" ]]; then
  log "kernel updated ($RUNNING_KERNEL -> $INSTALLED_KERNEL) -> reboot recommended"
  mkdir -p /var/lib/yamato && date > /var/lib/yamato/needs-reboot
else
  rm -f /var/lib/yamato/needs-reboot 2>/dev/null || true
fi

log "done."
