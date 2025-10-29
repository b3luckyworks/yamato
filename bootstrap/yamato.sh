#!/usr/bin/env bash
set -Eeuo pipefail

REPO="b3luckyworks/yamato"
RAW="https://raw.githubusercontent.com/${REPO}/main/bootstrap"

log(){ printf "[yamato-bootstrap] %s\n" "$*"; }

log "Netz prüfen…"
ping -c1 archlinux.org >/dev/null 2>&1 || { echo "Kein Netz. Verbinde dich (iwctl) und starte erneut."; exit 1; }

log "Werkzeuge installieren…"
pacman -Sy --noconfirm archinstall git curl

work=/tmp/yamato
rm -rf "$work"; mkdir -p "$work"
curl -fsSLo "$work/firstboot.sh"      "$RAW/yamato-firstboot.sh"
curl -fsSLo "$work/firstboot.service" "$RAW/yamato-firstboot.service"
chmod +x "$work/firstboot.sh"

echo
echo ">>> Jetzt startet der interaktive archinstall-Dialog."
echo ">>> Bitte ALLES nach Wunsch für DIESEN Client setzen (Disk, User, Locale, …)."
echo

# (interaktives TUI; keine feste Config -> alles wird pro Maschine bestimmt)
archinstall || { echo "archinstall wurde abgebrochen/fehlgeschlagen."; exit 1; }

# archinstall mountet das Ziel üblicherweise unter /mnt
target="/mnt"
[ -d "$target/etc" ] || { echo "Zielsystem nicht unter /mnt gefunden. Abbruch."; exit 1; }

log "First-boot Hook ins Zielsystem deployen…"
install -Dm755 "$work/firstboot.sh"      "$target/usr/local/bin/yamato-firstboot.sh"
install -Dm644 "$work/firstboot.service" "$target/etc/systemd/system/yamato-firstboot.service"

log "Client-Marker setzen (global)…"
mkdir -p "$target/etc/yamato"
echo "client=1" > "$target/etc/yamato/is_client"

log "First-boot Service aktivieren…"
arch-chroot "$target" systemctl enable yamato-firstboot.service

echo
echo "Fertig. System neu starten, dann richtet Yamato beim ERSTEN Boot alles ein."
echo "reboot"
