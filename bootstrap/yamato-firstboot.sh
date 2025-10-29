#!/usr/bin/env bash
set -Eeuo pipefail

REPO_SSH="git@github.com:b3luckyworks/yamato.git"
REPO_HTTPS="https://github.com/b3luckyworks/yamato.git"

log(){ printf "[yamato-firstboot] %s\n" "$*"; }

# 1) normalen Benutzer finden (kein fester Name nötig)
TARGET_USER="$(awk -F: '$3>=1000 && $1!="nobody"{print $1; exit}' /etc/passwd)"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_USER" ] || { log "Kein normaler Benutzer gefunden."; exit 1; }

# 2) Repo klonen
log "Repo für $TARGET_USER clonen…"
sudo -u "$TARGET_USER" mkdir -p "$TARGET_HOME/git"
if command -v git >/dev/null 2>&1; then
  sudo -u "$TARGET_USER" bash -lc "cd ~/git && (git clone '$REPO_SSH' yamato || git clone '$REPO_HTTPS' yamato)"
else
  pacman -Sy --noconfirm git
  sudo -u "$TARGET_USER" bash -lc "cd ~/git && (git clone '$REPO_SSH' yamato || git clone '$REPO_HTTPS' yamato)"
fi

# 3) client-Install starten (richtet Marker/Timer/Updates/Dotfiles ein)
if [ -x "$TARGET_HOME/git/yamato/scripts/install.sh" ]; then
  log "install.sh client ausführen…"
  sudo -u "$TARGET_USER" bash -lc "~/git/yamato/scripts/install.sh client"
else
  log "install.sh nicht gefunden! Prüfe Repo."
fi

# 4) First-boot Service deaktivieren
log "First-boot Service deaktivieren…"
systemctl disable yamato-firstboot.service || true

log "Done."
