#!/usr/bin/env bash
set -euo pipefail

# Reihenfolge der Themes & Größen, die wir probieren
themes=(/usr/share/icons/Papirus-Dark /usr/share/icons/Papirus /usr/share/icons/Adwaita)
sizes=(64x64 48x48 32x32 24x24 scalable)

# Mögliche Dateinamen (Papirus nutzt "system-log-out.svg")
declare -A names=(
  [lock]="system-lock-screen"
  [reboot]="system-reboot"
  [shutdown]="system-shutdown"
  [suspend]="system-suspend"
  [logout]="system-log-out"
)

# Findet die erste existierende Datei (svg/png) für ein Icon
find_icon() {
  local base="$1" size="$2" name="$3"
  for ext in svg png; do
    # Adwaita nutzt oft "-symbolic.svg"
    for cand in \
      "$base/$size/actions/$name.$ext" \
      "$base/$size/actions/$name-symbolic.$ext" \
      "$base/$size/actions/${name//-/_}.$ext" \
      "$base/$size/actions/${name//-/_}-symbolic.$ext"
    do
      [[ -f "$cand" ]] && { echo "$cand"; return 0; }
    done
  done
  return 1
}

declare -A icon
for key in lock reboot shutdown suspend logout; do
  icon[$key]=""
done

# Wir suchen pro Icon den ersten Treffer über alle themes/sizes
for t in "${themes[@]}"; do
  [[ -d "$t" ]] || continue
  for s in "${sizes[@]}"; do
    for key in "${!icon[@]}"; do
      [[ -n "${icon[$key]}" ]] && continue
      path="$(find_icon "$t" "$s" "${names[$key]}")" || true
      [[ -n "${path:-}" ]] && icon[$key]="$path"
    done
  done
done

# Prüfen ob wir mindestens eins gefunden haben
found_any=false
for key in "${!icon[@]}"; do
  [[ -n "${icon[$key]}" ]] && found_any=true
done
$found_any || { echo "Kein passendes Icon gefunden. Bitte papirus-icon-theme oder adwaita-icon-theme installieren."; exit 1; }

# style.css schreiben
cat > ~/.config/wlogout/style.css <<CSS
window {
  background-color: rgba(12,14,18,0.55);
  color: #eaeaea;
  font-family: "MesloLGS Nerd Font", "Inter", "Noto Sans", Cantarell, sans-serif;
}
#outer-box { padding: 32px; }
#layout-box { padding: 6px; }
button {
  min-width: 140px; min-height: 140px; margin: 12px;
  background-color: rgba(28,32,38,0.75);
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 22px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.25);
  background-repeat: no-repeat; background-position: center 28px; background-size: 48px;
  padding-top: 92px;
  font-weight: 600; font-size: 14px; letter-spacing: 0.2px;
}
button:hover { background-color: rgba(36,41,49,0.85); transform: translateY(-1px); transition: 120ms ease; }
button:focus { outline: 2px solid rgba(255,255,255,0.15); }

/* Dynamisch gefundene Icon-Pfade */
CSS

for key in lock reboot shutdown suspend logout; do
  if [[ -n "${icon[$key]}" ]]; then
    printf '#%s { background-image: url("%s"); }\n' "$key" "${icon[$key]}" >> ~/.config/wlogout/style.css
  fi
done

echo "Fertig: ~/.config/wlogout/style.css aktualisiert."
