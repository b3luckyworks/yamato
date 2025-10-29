# in scripts/post_install.sh – optional
sudo pacman -S --needed --noconfirm base-devel git
if ! command -v yay >/dev/null 2>&1; then
  tmpdir=$(mktemp -d) && cd "$tmpdir"
  git clone https://aur.archlinux.org/yay.git
  cd yay && makepkg -si --noconfirm
  cd ~ && rm -rf "$tmpdir"
fi

