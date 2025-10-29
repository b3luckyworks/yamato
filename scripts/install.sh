#!/usr/bin/env bash
set -Euo pipefail

MODE="${1:-client}"   # client (default) | server
REPO_DIR="${REPO_DIR:-$HOME/git/yamato}"

trap 'echo "[install] ERROR on line $LINENO"; exit 1' ERR
log(){ printf "[install] %s\n" "$*"; }

ensure_cmd() { command -v "$1" >/dev/null 2>&1; }
read_nonempty_lines() { grep -vE '^\s*#' "$1" | sed '/^\s*$/d'; }

ensure_yay() {
  if ! ensure_cmd yay; then
    log "yay nicht gefunden – installiere aus AUR…"
    sudo pacman -S --needed --noconfirm git base-devel || true
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    ( cd "$tmpdir/yay" && makepkg -si --noconfirm )
    rm -rf "$tmpdir"
  fi
}

log "System aktualisieren…"
sudo pacman -Syu --noconfirm

log "Basis-Tools…"
sudo pacman -S --needed --noconfirm git stow

# 1) Pakete aus pkglist.txt (falls vorhanden)
if [[ -f "${REPO_DIR}/packages/pkglist.txt" ]]; then
  log "Pakete aus pkglist.txt…"
  mapfile -t PKGS < <(read_nonempty_lines "${REPO_DIR}/packages/pkglist.txt")
  if (( ${#PKGS[@]} )); then
    sudo pacman -S --needed --noconfirm "${PKGS[@]}"
  else
    log "pkglist.txt leer – überspringe Paketinstallation."
  fi
fi

# 2) AUR-Pakete aus aurlist.txt (falls vorhanden)
if [[ -f "${REPO_DIR}/packages/aurlist.txt" ]]; then
  log "AUR-Pakete aus aurlist.txt…"
  mapfile -t AUR_PKGS < <(read_nonempty_lines "${REPO_DIR}/packages/aurlist.txt")
  if (( ${#AUR_PKGS[@]} )); then
    ensure_yay
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  else
    log "aurlist.txt leer – überspringe AUR-Installation."
  fi
fi

# 3) Dotfiles verlinken (stow)
if [[ -d "${REPO_DIR}/dotfiles" ]]; then
  log "Dotfiles via stow verlinken…"
  pushd "${REPO_DIR}/dotfiles" >/dev/null
  for pkg in *; do
    [[ -d "$pkg" ]] || continue
    stow -Rvt "$HOME" "$pkg"
  done
  popd >/dev/null
fi

# 4) Post-Install (idempotent halten)
if [[ -x "${REPO_DIR}/scripts/post_install.sh" ]]; then
  log "post_install.sh…"
  "${REPO_DIR}/scripts/post_install.sh" "$MODE"
fi

# 5) Timer/Services im Client-Modus
if [[ "$MODE" == "client" ]]; then
  log "Client-Modus: Marker setzen & Updater/Timer aktivieren…"

  # Globaler Client-Marker
  sudo install -Dm644 /dev/stdin /etc/yamato/is_client <<<"client=1"

  # --- pacman (Root-Units) ---
  if [[ -f "${REPO_DIR}/scripts/client/yamato-pacman-update.sh" ]]; then
    sudo install -Dm755 "${REPO_DIR}/scripts/client/yamato-pacman-update.sh" /usr/local/bin/yamato-pacman-update.sh
  else
    log "WARN: scripts/client/yamato-pacman-update.sh fehlt – pacman-Update-Job wird übersprungen."
  fi

  if [[ -f "${REPO_DIR}/scripts/client/yamato-pacman.service" && -f "${REPO_DIR}/scripts/client/yamato-pacman.timer" ]]; then
    sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-pacman.service" /etc/systemd/system/yamato-pacman.service
    sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-pacman.timer"   /etc/systemd/system/yamato-pacman.timer
    sudo systemctl daemon-reload
    sudo systemctl enable --now yamato-pacman.timer
  else
    log "WARN: yamato-pacman.{service,timer} fehlen – kein Root-Timer aktiviert."
  fi

  # --- User-Units (yay & Repo-Updater) global bereitstellen ---
  sudo install -d /etc/systemd/user

  if [[ -f "${REPO_DIR}/scripts/client/yamato-aur.service" && -f "${REPO_DIR}/scripts/client/yamato-aur.timer" ]]; then
    sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-aur.service" /etc/systemd/user/yamato-aur.service
    sudo install -Dm644 "${REPO_DIR}/scripts/client/yamato-aur.timer"   /etc/systemd/user/yamato-aur.timer
    systemctl --global enable --now yamato-aur.timer || true
  else
    log "WARN: yamato-aur.{service,timer} fehlen – kein AUR-Timer aktiviert."
  fi

  if [[ -f "${REPO_DIR}/systemd-user/yamato-updater.service" && -f "${REPO_DIR}/systemd-user/yamato-updater.timer" ]]; then
    sudo install -Dm644 "${REPO_DIR}/systemd-user/yamato-updater.service" /etc/systemd/user/yamato-updater.service
    sudo install -Dm644 "${REPO_DIR}/systemd-user/yamato-updater.timer"   /etc/systemd/user/yamato-updater.timer
    systemctl --global enable --now yamato-updater.timer || true
  else
    log "INFO: yamato-updater.{service,timer} nicht gefunden – Repo-Pull-Timer wird ausgelassen."
  fi

  # --- sofort für den aktuellen User aktivieren (falls vorhanden) ---
  systemctl --user daemon-reload
  systemctl --user enable --now yamato-aur.timer 2>/dev/null || true
  systemctl --user enable --now yamato-updater.timer 2>/dev/null || true

  # Optional sinnvoll: User-Lingering, damit User-Timer ohne Login laufen
  loginctl enable-linger "$USER" || true

  log "Client-Setup fertig."
else
  log "Server-Modus: Kein Auto-Update/Timer aktiviert. (Nutze: ${REPO_DIR}/scripts/update.sh manuell)"
fi

log "Done."
