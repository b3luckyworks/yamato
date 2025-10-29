#!/usr/bin/env bash
set -Euo pipefail

MODE="${1:-client}"   # client (default) | server
REPO_DIR="${REPO_DIR:-$HOME/git/yamato}"

trap 'echo "[install] ERROR on line $LINENO"; exit 1' ERR
log(){ printf "[install] %s\n" "$*"; }

log "System aktualisieren…"
sudo pacman -Syu --noconfirm

log "Basis-Tools…"
sudo pacman -S --needed --noconfirm git stow

# Pakete aus pkglist.txt (falls vorhanden)
if [[ -f "${REPO_DIR}/packages/pkglist.txt" ]]; then
  log "Pakete aus pkglist.txt…"
  # sicher parsen, kein leerer pacman-Aufruf
  mapfile -t PKGS < <(grep -vE '^\s*#' "${REPO_DIR}/packages/pkglist.txt" | sed '/^\s*$/d')
  if (( ${#PKGS[@]} )); then
    sudo pacman -S --needed --noconfirm "${PKGS[@]}"
  else
    log "pkglist.txt leer – überspringe Paketinstallation."
  fi
fi

# Dotfiles verlinken (stow)
if [[ -d "${REPO_DIR}/dotfiles" ]]; then
  log "Dotfiles via stow verlinken…"
  pushd "${REPO_DIR}/dotfiles" >/dev/null
  for pkg in *; do
    [[ -d "$pkg" ]] || continue
    stow -Rvt "$HOME" "$pkg"
  done
  popd >/dev/null
fi

# Deine idempotenten Systemanpassungen
if [[ -x "${REPO_DIR}/scripts/post_install.sh" ]]; then
  log "post_install.sh…"
  "${REPO_DIR}/scripts/post_install.sh"
fi

if [[ "$MODE" == "client" ]]; then
  log "Client-Modus: Marker setzen & Updater/Timer aktivieren…"

  # Globaler Client-Marker (kein Username nötig)
  sudo install -Dm644 /dev/stdin /etc/yamato/is_client <<<"client=1"

  # --- pacman (Root) ---
  sudo install -Dm755 "${REPO_DIR}/scripts/client/yamato-pacman-update.sh" /usr/local/bin/yamato-pacman-update.sh
  sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-pacman.service"   /etc/systemd/system/yamato-pacman.service
  sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-pacman.timer"     /etc/systemd/system/yamato-pacman.timer
  sudo systemctl daemon-reload
  sudo systemctl enable --now yamato-pacman.timer

  # --- yay (AUR) & Yamato-Git-Updater als globale User-Units bereitstellen ---
  sudo install -d /etc/systemd/user

  sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-aur.service" /etc/systemd/user/yamato-aur.service
  sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-aur.timer"   /etc/systemd/user/yamato-aur.timer

  if [[ -f "${REPO_DIR}/systemd-user/yamato-updater.service" && -f "${REPO_DIR}/systemd-user/yamato-updater.timer" ]]; then
    sudo install -Dm644 "${REPO_DIR}/systemd-user/yamato-updater.service" /etc/systemd/user/yamato-updater.service
    sudo install -Dm644 "${REPO_DIR}/systemd-user/yamato-updater.timer"   /etc/systemd/user/yamato-updater.timer
  fi

  # global für alle User aktivieren (wirksam bei zukünftigen Logins)
  systemctl --global enable --now yamato-aur.timer || true
  systemctl --global enable --now yamato-updater.timer 2>/dev/null || true

  # --- sofort für den *aktuellen* User aktivieren (direkt wirksam) ---
  systemctl --user daemon-reload
  systemctl --user enable --now yamato-aur.timer 2>/dev/null || true
  if systemctl --user list-unit-files | grep -q '^yamato-updater.timer'; then
    systemctl --user enable --now yamato-updater.timer 2>/dev/null || true
  fi

  log "Client-Setup fertig."

else
  log "Server-Modus: Kein Auto-Update/Timer aktiviert. (Nutze: ./scripts/update.sh manuell)"
fi

log "Done."
