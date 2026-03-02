#!/bin/bash

# omarchy-install-extra-themes: Clone all themes from the Omarchy extra themes directory
# Source: https://learn.omacom.io/2/the-omarchy-manual/90/extra-themes
# Themes are cloned into ~/.config/omarchy/themes/ without changing the active theme.

THEMES_DIR="$HOME/.config/omarchy/themes"
mkdir -p "$THEMES_DIR"

REPOS=(
  https://github.com/JJDizz1L/aetheria
  https://github.com/tahfizhabib/omarchy-amberbyte-theme
  https://github.com/vale-c/omarchy-arc-blueberry
  https://github.com/davidguttman/archwave
  https://github.com/bjarneo/omarchy-ash-theme
  https://github.com/tahfizhabib/omarchy-artzen-theme
  https://github.com/bjarneo/omarchy-aura-theme
  https://github.com/guilhermetk/omarchy-all-hallows-eve-theme
  https://github.com/atif-1402/omarchy-atelier-theme
  https://github.com/abhijeet-swami/omarchy-ayaka-theme
  https://github.com/Hydradevx/omarchy-azure-glow-theme
  https://github.com/HANCORE-linux/omarchy-batou-theme
  https://github.com/somerocketeer/omarchy-bauhaus-theme
  https://github.com/OldJobobo/omarchy-biscuit-de-mar-dark-theme
  https://github.com/ankur311sudo/black_arch
  https://github.com/HANCORE-linux/omarchy-blackgold-theme
  https://github.com/HANCORE-linux/omarchy-blackturq-theme
  https://github.com/mishonki3/omarchy-bliss-theme
  https://github.com/dotsilva/omarchy-bluedotrb-theme
  https://github.com/hipsterusername/omarchy-blueridge-dark-theme
  https://github.com/Luquatic/omarchy-catppuccin-dark
  https://github.com/Grey-007/citrus-cynapse
  https://github.com/OldJobobo/omarchy-city-783-theme
  https://github.com/hoblin/omarchy-cobalt2-theme
  https://github.com/stannorbvb-cmd/cpunk
  https://github.com/noahljungberg/omarchy-darcula-theme
  https://github.com/HANCORE-linux/omarchy-demon-theme
  https://github.com/dotsilva/omarchy-dotrb-theme
  https://github.com/ShehabShaef/omarchy-drac-theme
  https://github.com/catlee/omarchy-dracula-theme
  https://github.com/eldritch-theme/omarchy
  https://github.com/OldJobobo/omarchy-event-horizon-theme
  https://github.com/celsobenedetti/omarchy-evergarden
  https://github.com/TyRichards/omarchy-felix-theme
  https://github.com/bjarneo/omarchy-fireside-theme
  https://github.com/OldJobobo/omarchy-flat-dracula-theme
  https://github.com/euandeas/omarchy-flexoki-dark-theme
  https://github.com/abhijeet-swami/omarchy-forest-green-theme
  https://github.com/bjarneo/omarchy-frost-theme
  https://github.com/bjarneo/omarchy-futurism-theme
  https://github.com/row-huh/omarchy-ghost-pastel-theme
  https://github.com/tahayvr/omarchy-gold-rush-theme
  https://github.com/HANCORE-linux/omarchy-thegreek-theme
  https://github.com/kalk-ak/omarchy-green-garden-theme
  https://github.com/joaquinmeza/omarchy-hakker-green-theme
  https://github.com/ankur311sudo/gruvu
  https://github.com/HANCORE-linux/omarchy-harbor-theme
  https://github.com/HANCORE-linux/omarchy-harbordark-theme
  https://github.com/OldJobobo/omarchy-hinterlands-theme
  https://github.com/RiO7MAKK3R/omarchy-infernium-dark-theme
  https://github.com/HANCORE-linux/omarchy-lasthorizon-theme
  https://github.com/ItsABigIgloo/omarchy-mapquest-theme
  https://github.com/steve-lohmeyer/omarchy-mars-theme
  https://github.com/HANCORE-linux/omarchy-mechanoonna-theme
  https://github.com/OldJobobo/omarchy-miasma-theme
  https://github.com/JaxonWright/omarchy-midnight-theme
  https://github.com/hipsterusername/omarchy-milkmatcha-light-theme
  https://github.com/Swarnim114/omarchy-monochrome-theme
  https://github.com/bjarneo/omarchy-monokai-theme
  https://github.com/somerocketeer/omarchy-nagai-poolside-theme
  https://github.com/monoooki/omarchy-neo-sploosh-theme
  https://github.com/RiO7MAKK3R/omarchy-neovoid-theme
  https://github.com/bjarneo/omarchy-nes-theme
  https://github.com/RiO7MAKK3R/omarchy-omacarchy-theme
  https://github.com/sc0ttman/omarchy-one-dark-pro-theme
  https://github.com/HANCORE-linux/omarchy-oxocarbon-theme
  https://github.com/imbypass/omarchy-pandora-theme
  https://github.com/bjarneo/omarchy-pina-theme
  https://github.com/ITSZXY/pink-blood-omarchy-theme
  https://github.com/bjarneo/omarchy-pulsar-theme
  https://github.com/Grey-007/purple-moon
  https://github.com/dotsilva/omarchy-purplewave-theme
  https://github.com/atif-1402/omarchy-rainynight-theme
  https://github.com/kamatealif/omarchy-red-monarch-theme
  https://github.com/rondilley/omarchy-retropc-theme
  https://github.com/robzolkos/omarchy-robzee84-theme
  https://github.com/guilhermetk/omarchy-rose-pine-dark
  https://github.com/HANCORE-linux/omarchy-roseofdune-theme
  https://github.com/bjarneo/omarchy-sakura-theme
  https://github.com/HANCORE-linux/omarchy-sapphire-theme
  https://github.com/HANCORE-linux/omarchy-shadesofjade-theme
  https://github.com/TyRichards/omarchy-space-monkey-theme
  https://github.com/bjarneo/omarchy-snow-theme
  https://github.com/ankur311sudo/snow_black
  https://github.com/Gazler/omarchy-solarized-theme
  https://github.com/dfrico/omarchy-solarized-light-theme
  https://github.com/motorsss/omarchy-solarizedosaka-theme
  https://github.com/rondilley/omarchy-sunset-theme
  https://github.com/tahayvr/omarchy-sunset-drive-theme
  https://github.com/TyRichards/omarchy-super-game-bro-theme
  https://github.com/omacom-io/omarchy-synthwave84-theme
  https://github.com/Ahmad-Mtr/omarchy-temerald-theme
  https://github.com/Justin-De-Sio/omarchy-tokyoled-theme
  https://github.com/monoooki/omarchy-torrentz-hydra-theme
  https://github.com/leonardobetti/omarchy-tycho
  https://github.com/OldJobobo/omarchy-waffle-cat-theme
  https://github.com/hipsterusername/omarchy-waveform-dark-theme
  https://github.com/HANCORE-linux/omarchy-whitegold-theme
  https://github.com/Nirmal314/omarchy-van-gogh-theme
  https://github.com/HANCORE-linux/omarchy-velvetnight-theme
  https://github.com/thmoee/omarchy-vesper-theme
  https://github.com/tahayvr/omarchy-vhs80-theme
  https://github.com/vyrx-dev/omarchy-void-theme
)

clone_theme() {
  local url="$1"
  local name
  name=$(basename "$url" .git | sed -E 's/^omarchy-//; s/-theme$//')
  local dest="$THEMES_DIR/$name"

  if [[ -d "$dest" ]]; then
    echo "SKIP $name (already exists)"
  elif git clone --depth=1 -q "$url" "$dest" 2>/dev/null; then
    echo "OK   $name"
  else
    echo "FAIL $name ($url)"
  fi
}

export -f clone_theme
export THEMES_DIR

CURRENT_THEME=$(omarchy-theme-current)

echo "Installing extra Omarchy themes..."
printf '%s\n' "${REPOS[@]}" | xargs -P 8 -I{} bash -c 'clone_theme "$@"' _ {}

echo ""
echo "Restoring theme: $CURRENT_THEME"
omarchy-theme-set "$CURRENT_THEME"
