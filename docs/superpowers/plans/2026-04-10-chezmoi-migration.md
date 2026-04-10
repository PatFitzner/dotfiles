# chezmoi Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-branch (main + guruwalk) stow-managed dotfiles repo with a single-branch chezmoi-managed repo where host-specific values live in `.chezmoidata.yaml` and are injected via Go templates.

**Architecture:** chezmoi source tree at repo root. Static files (identical across hosts) sit as plain files under `dot_config/`, `dot_local/bin/`, etc. Host-specific values live in `.chezmoidata.yaml` as structured data (GPU, monitors, packages) consumed by `*.tmpl` files. One-off host toggles (e.g., NVIDIA env vars) use `{{ if eq .chezmoi.hostname "omarchy" }}` blocks. Package installation runs via `run_onchange_before_` scripts; user-systemd reload via `run_onchange_after_`. Per-host autostart exclusions via `.chezmoiignore.tmpl`.

**Tech Stack:** chezmoi (dotfile manager, Go templates), git, bash, pacman.

**Environment:** All work happens in `/home/pat/omarchy_dotfiles_chezmoi/` — a physical copy of the live repo. The live `/home/pat/omarchy_dotfiles/` stays stowed and functional until phase 5 (cutover on pat-ws). The spec for this work lives at `docs/superpowers/specs/2026-04-10-chezmoi-migration-design.md` inside the copy.

**Two hosts at migration time:**
- `omarchy` — NVIDIA desktop (currently `main` branch)
- `pat-ws` — non-NVIDIA machine, the one this plan executes on (currently `guruwalk` branch)

---

## Task 1: Prep the copy repo and clean stale files

**Files:**
- Create: `/home/pat/omarchy_dotfiles_chezmoi/.chezmoiignore`
- Modify: `/home/pat/omarchy_dotfiles_chezmoi/.gitignore`
- Delete (tracked cruft): `hypr/.config/hypr/hyprlock.conf.bak.1760864957`, `hypr/.config/hypr/hyprlock.conf.bak.1764149403`, `waybar/.config/waybar/nohup.out`, `home/stow_it.sh`, `home/.stow-local-ignore`, `pacman_installed_packages.txt` (the root-level duplicate)

- [ ] **Step 1: Verify the copy exists and is clean**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git status
git log --oneline -3
```
Expected: clean working tree, HEAD at `0c60461` (systemd amendment) or later, branch `guruwalk`.

- [ ] **Step 2: Install chezmoi if not already present**

```bash
command -v chezmoi || sudo pacman -S --needed --noconfirm chezmoi
chezmoi --version
```
Expected: `chezmoi version v2.x.x …`

- [ ] **Step 3: Create the migration branch**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git checkout -b chezmoi-migration
git branch --show-current
```
Expected: `chezmoi-migration`

- [ ] **Step 4: Delete tracked cruft files**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git rm hypr/.config/hypr/hyprlock.conf.bak.1760864957
git rm hypr/.config/hypr/hyprlock.conf.bak.1764149403
git rm waybar/.config/waybar/nohup.out
git rm home/stow_it.sh
git rm home/.stow-local-ignore
git rm pacman_installed_packages.txt
git status --short
```
Expected: 6 files shown as `D`.

- [ ] **Step 5: Write the chezmoi-level ignore file**

Create `/home/pat/omarchy_dotfiles_chezmoi/.chezmoiignore` with content:

```
README.md
docs
.git
.gitignore
```

This tells chezmoi: "these paths exist in the source tree but are NOT dotfiles to deploy."

- [ ] **Step 6: Update `.gitignore` to exclude runtime omarchy state**

Read current `.gitignore`, then overwrite it with:

```
dot_config/omarchy/current/
```

(The previous contents — if any — are replaced. This is the new repo layout's ignore.)

- [ ] **Step 7: Stage and commit setup**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add .chezmoiignore .gitignore
git commit -m "chezmoi: prep migration branch, cleanup cruft, add ignore files"
git log --oneline -3
```
Expected: new commit on `chezmoi-migration`.

---

## Task 2: Create `.chezmoidata.yaml` skeleton

**Files:**
- Create: `/home/pat/omarchy_dotfiles_chezmoi/.chezmoidata.yaml`

- [ ] **Step 1: Write the skeleton file**

Create `/home/pat/omarchy_dotfiles_chezmoi/.chezmoidata.yaml` with content:

```yaml
# Host-specific facts consumed by *.tmpl files.
# Add a new host = add a key under `hosts:` whose name matches `hostname`.
# Unknown hosts cause templates to error loudly (intentional — no silent defaults).

hosts:
  omarchy:
    gpu: nvidia
    monitors: []         # filled in Task 14
    packages_extra: []   # filled in Task 14
    autostart: []        # filled in Task 14
    systemd_user_enable: []

  pat-ws:
    gpu: none
    monitors: []
    packages_extra: []
    autostart: []
    systemd_user_enable: []

packages_common: []      # filled in Task 14
```

- [ ] **Step 2: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add .chezmoidata.yaml
git commit -m "chezmoi: add empty host data skeleton"
```

---

## Task 3: Move hypr static files to `dot_config/hypr/`

The hypr config has static files (bindings, input, scripts, shaders, hypridle, hyprlock, looknfeel, autostart, hyprsunset, xdph) and files that will become templates (hyprland, monitors, envs). This task moves only the static ones. Templates are handled in later tasks; the template source files are moved in this task too, and renamed to `*.tmpl` with their content transformed later.

**Files:**
- Move: everything under `hypr/.config/hypr/` → `dot_config/hypr/`

- [ ] **Step 1: Move the whole hypr subtree with git mv**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config
git mv hypr/.config/hypr dot_config/hypr
rmdir hypr/.config 2>/dev/null || true
rmdir hypr 2>/dev/null || true
git status --short | head -20
```
Expected: renames from `hypr/.config/hypr/…` → `dot_config/hypr/…`. About 160+ files renamed (most are shaders).

- [ ] **Step 2: Verify directory structure**

```bash
ls /home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/ | head
```
Expected: `autostart.conf bindings.conf envs.conf hypridle.conf hyprland.conf hyprlock.conf hyprsunset.conf input.conf looknfeel.conf monitors.conf scripts shaders xdph.conf`

- [ ] **Step 3: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: move hypr config into dot_config/hypr/"
```

---

## Task 4: Move small static config dirs (alacritty, git, nvim, tmux, menus)

**Files:**
- Move: `alacritty/.config/alacritty/` → `dot_config/alacritty/`
- Move: `git/.config/git/` → `dot_config/git/`
- Move: `nvim/.config/nvim/` → `dot_config/nvim/`
- Move: `tmux/.tmux.conf` → `dot_tmux.conf`
- Move: `menus/.config/menus/` → `dot_config/menus/`

- [ ] **Step 1: Move each dir**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv alacritty/.config/alacritty dot_config/alacritty
git mv git/.config/git dot_config/git
git mv nvim/.config/nvim dot_config/nvim
git mv menus/.config/menus dot_config/menus
mkdir -p $(dirname dot_tmux.conf)
git mv tmux/.tmux.conf dot_tmux.conf
# clean up now-empty stow package dirs
for d in alacritty git nvim tmux menus; do
  rmdir "$d/.config" 2>/dev/null || true
  rmdir "$d" 2>/dev/null || true
done
git status --short | head
```
Expected: renames shown, no errors.

- [ ] **Step 2: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: move alacritty, git, nvim, tmux, menus into place"
```

---

## Task 5: Move scripts to `dot_local/bin/` with executable prefix

`~/.local/bin` is already on PATH on omarchy. Files get the `executable_` prefix so chezmoi marks them +x on apply. This also eliminates the custom PATH entry in `.bashrc` — removed in Task 13.

**Files:**
- Move: everything in `home/my_scripts/` → `dot_local/bin/`
- Rename each moved file to prepend `executable_`

Note: `home/my_scripts/pacman_installed_packages.txt` is data, not a script. Move it too but without the `executable_` prefix.

- [ ] **Step 1: Move and rename in one pass**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_local/bin
for f in home/my_scripts/*; do
  base=$(basename "$f")
  if [ "$base" = "pacman_installed_packages.txt" ]; then
    git mv "$f" "dot_local/bin/$base"
  else
    git mv "$f" "dot_local/bin/executable_$base"
  fi
done
rmdir home/my_scripts 2>/dev/null || true
git status --short
```
Expected: files under `dot_local/bin/` with `executable_` prefix, one data file without.

- [ ] **Step 2: Also handle untracked scripts in the live repo**

The live repo at `/home/pat/omarchy_dotfiles` has these untracked scripts (not currently committed but present on disk): `new-worktree`, `tmux-dropdown-session`, `tmux-main`, `tmux-select-branch`, `toggle-tmux-dropdown`. Check whether they're already captured in the `home/my_scripts/` move above.

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
ls dot_local/bin/ | sort
```
If any of the five names above are missing, copy them in from the live repo:
```bash
for f in new-worktree tmux-dropdown-session tmux-main tmux-select-branch toggle-tmux-dropdown; do
  if [ ! -f "dot_local/bin/executable_$f" ] && [ -f /home/pat/omarchy_dotfiles/home/my_scripts/$f ]; then
    cp /home/pat/omarchy_dotfiles/home/my_scripts/$f "dot_local/bin/executable_$f"
    git add "dot_local/bin/executable_$f"
  fi
done
git status --short
```

- [ ] **Step 3: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: move my_scripts to dot_local/bin/ with executable_ prefix"
```

---

## Task 6: Move omarchy static files (excluding volatile `current/`)

Omarchy's config dir has two kinds of content: *static* (branding, themes library, hooks samples) and *volatile* (`current/` — written by the theme switcher at runtime). Only static goes into chezmoi; `current/` is both un-deployed and gitignored.

**Files:**
- Move: `omarchy/.config/omarchy/{branding,hooks,themes}/` → `dot_config/omarchy/{branding,hooks,themes}/`
- `omarchy/.config/omarchy/current/` → remove from git (see Task 18 for full handling; this task does the file move, Task 18 re-asserts the ignore)

- [ ] **Step 1: Move static subdirs**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config/omarchy
git mv omarchy/.config/omarchy/branding dot_config/omarchy/branding
git mv omarchy/.config/omarchy/hooks dot_config/omarchy/hooks
git mv omarchy/.config/omarchy/themes dot_config/omarchy/themes
git status --short | head
```
Expected: three directory renames.

- [ ] **Step 2: Remove `current/` from tracking**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git rm -r omarchy/.config/omarchy/current 2>/dev/null || echo "already absent"
rmdir omarchy/.config/omarchy 2>/dev/null || true
rmdir omarchy/.config 2>/dev/null || true
rmdir omarchy 2>/dev/null || true
git status --short | head
```
Expected: `current/` files marked deleted (if any were tracked).

- [ ] **Step 3: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: move omarchy static config, drop volatile current/"
```

---

## Task 7: Move autostart `.desktop` files

**Files:**
- Move: `autostart/.config/autostart/*.desktop` → `dot_config/autostart/*.desktop`

- [ ] **Step 1: Move the autostart dir**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config/autostart
git mv autostart/.config/autostart/insync.desktop dot_config/autostart/insync.desktop
git mv autostart/.config/autostart/org.keepassxc.KeePassXC.desktop dot_config/autostart/org.keepassxc.KeePassXC.desktop
git mv autostart/.config/autostart/pacman_installed_dump.desktop dot_config/autostart/pacman_installed_dump.desktop
git mv autostart/.config/autostart/walker.desktop dot_config/autostart/walker.desktop
rmdir autostart/.config 2>/dev/null || true
rmdir autostart 2>/dev/null || true
git status --short
```
Expected: four renames.

- [ ] **Step 2: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: move autostart .desktop files"
```

---

## Task 8: Move waybar, strawberry, sofle_choc, vault, and shell files

Everything else that's a plain static file goes here. Waybar `config.jsonc` moves in as a static file for now — it becomes a template in Task 12.

**Files:**
- Move: `waybar/.config/waybar/*` → `dot_config/waybar/*`
- Move: `strawberry/.config/strawberry/strawberry.conf` → `dot_config/strawberry/strawberry.conf`
- Move: `sofle_choc/` → `dot_local/share/sofle_choc/` (out of `~/`, lives under `.local/share`)
- Move: `vault` → `dot_vault`
- Move: `home/.bashrc` → `dot_bashrc`
- Move: `home/.zshenv` → `dot_zshenv`

- [ ] **Step 1: Waybar**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config/waybar
git mv waybar/.config/waybar/config.jsonc dot_config/waybar/config.jsonc
git mv waybar/.config/waybar/style.css dot_config/waybar/style.css
rmdir waybar/.config 2>/dev/null || true
rmdir waybar 2>/dev/null || true
```

- [ ] **Step 2: Strawberry**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config/strawberry
git mv strawberry/.config/strawberry/strawberry.conf dot_config/strawberry/strawberry.conf
rmdir strawberry/.config 2>/dev/null || true
rmdir strawberry 2>/dev/null || true
```

- [ ] **Step 3: Sofle choc keyboard firmware**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_local/share
git mv sofle_choc dot_local/share/sofle_choc
```

- [ ] **Step 4: Vault**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv vault dot_vault
```

- [ ] **Step 5: Shell files**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv home/.bashrc dot_bashrc
git mv home/.zshenv dot_zshenv
rmdir home 2>/dev/null || true
```

- [ ] **Step 6: Sanity check — no leftover stow-style dirs**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
ls -1
```
Expected: `.chezmoidata.yaml .chezmoiignore .gitignore dot_bashrc dot_config dot_local dot_tmux.conf dot_vault dot_zshenv docs` (and `.git`). No `alacritty/`, `hypr/`, `waybar/`, etc.

- [ ] **Step 7: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add -A
git commit -m "chezmoi: move waybar, strawberry, sofle_choc, vault, shell files"
```

---

## Task 9: Convert `dot_config/hypr/monitors.conf` to a data-driven template

**Files:**
- Modify: `dot_config/hypr/monitors.conf` → `dot_config/hypr/monitors.conf.tmpl`

- [ ] **Step 1: Rename the file to `.tmpl`**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv dot_config/hypr/monitors.conf dot_config/hypr/monitors.conf.tmpl
```

- [ ] **Step 2: Replace the file contents with a data-driven template**

Overwrite `/home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/monitors.conf.tmpl` with:

```
# Generated by chezmoi — edit .chezmoidata.yaml, not this file directly.
# See https://wiki.hyprland.org/Configuring/Monitors/

{{- $host := index .hosts .chezmoi.hostname -}}
{{ range $host.monitors }}
monitor={{ .port }},{{ .mode }},{{ .position }},{{ .scale }}
{{- end }}
```

- [ ] **Step 3: Dry-run verify the template parses**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < dot_config/hypr/monitors.conf.tmpl
```
Expected: empty output (pat-ws has `monitors: []` in the skeleton) OR an error if the template is malformed. Empty output is the correct state at this point in the plan — real data is filled in Task 14.

- [ ] **Step 4: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add dot_config/hypr/monitors.conf.tmpl
git commit -m "chezmoi: convert hypr/monitors.conf to data-driven template"
```

---

## Task 10: Convert `dot_config/hypr/envs.conf` to an NVIDIA-conditional template

**Files:**
- Modify: `dot_config/hypr/envs.conf` → `dot_config/hypr/envs.conf.tmpl`

- [ ] **Step 1: Read the current content**

```bash
cat /home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/envs.conf
```
Note what's in it. On guruwalk this is typically a small file with a few `env = ...` lines. Any line that's NVIDIA-specific goes inside the conditional block; everything else stays unconditional.

- [ ] **Step 2: Rename the file**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv dot_config/hypr/envs.conf dot_config/hypr/envs.conf.tmpl
```

- [ ] **Step 3: Rewrite with NVIDIA wrapped in a conditional**

Edit `/home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/envs.conf.tmpl`. Take whatever non-NVIDIA env lines existed in the original and leave them at the top. Append (or wrap, if NVIDIA lines already existed) the NVIDIA block:

```
{{- $host := index .hosts .chezmoi.hostname }}
{{- if eq $host.gpu "nvidia" }}
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
{{- end }}
```

If the current `envs.conf` on guruwalk already contains those NVIDIA lines unconditionally (a known drift bug), REMOVE the unconditional copies — they're replaced by the conditional block.

- [ ] **Step 4: Verify the template renders correctly on pat-ws (non-NVIDIA)**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < dot_config/hypr/envs.conf.tmpl
```
Expected: output contains only the non-NVIDIA lines (if any). No `NVD_BACKEND` line — because pat-ws has `gpu: none`.

- [ ] **Step 5: Simulate the omarchy host to confirm NVIDIA lines appear**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. --init \
  --promptString 'hostname=omarchy' \
  < dot_config/hypr/envs.conf.tmpl 2>/dev/null || \
echo '{{ define "host" }}omarchy{{ end }}' # fallback if --init syntax unavailable
```

If the above doesn't cleanly simulate an alternate hostname, an alternative: temporarily edit `.chezmoidata.yaml` to change `pat-ws` to `gpu: nvidia`, re-render, visually confirm NVIDIA lines, then revert. Commit includes no data changes.

- [ ] **Step 6: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add dot_config/hypr/envs.conf.tmpl
git commit -m "chezmoi: wrap NVIDIA env vars in gpu=nvidia conditional"
```

---

## Task 11: Convert `dot_config/hypr/hyprland.conf` to a host-conditional template

The current `hyprland.conf` has: shared `source = ...` directives, shared windowrules, and a few host-specific bits: `allow_tearing`, the NVIDIA `env = …` lines (which should already be in `envs.conf` via Task 10 — remove them here), per-machine `monitor=` override lines (remove — `monitors.conf.tmpl` owns those), `misc { … dpms }` block (likely host-specific on desktop only), and the `tmux-main` / `claude-dropdown` windowrules (shared).

**Files:**
- Modify: `dot_config/hypr/hyprland.conf` → `dot_config/hypr/hyprland.conf.tmpl`

- [ ] **Step 1: Read the current content**

```bash
cat /home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/hyprland.conf
```
Identify:
- Lines that should be removed (NVIDIA env vars — moved to envs.conf.tmpl; `monitor=` override lines — moved to monitors.conf.tmpl).
- Lines that are host-specific and need a conditional (`allow_tearing = true` is only for `omarchy` gaming; `misc { mouse_move_enables_dpms... }` is desktop-only).
- Lines that are shared (keep unconditionally).

- [ ] **Step 2: Rename**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv dot_config/hypr/hyprland.conf dot_config/hypr/hyprland.conf.tmpl
```

- [ ] **Step 3: Rewrite with conditionals**

Edit `/home/pat/omarchy_dotfiles_chezmoi/dot_config/hypr/hyprland.conf.tmpl`. Structure:

```
# Use Omarchy defaults
source = ~/.local/share/omarchy/default/hypr/autostart.conf
source = ~/.local/share/omarchy/default/hypr/bindings/media.conf
source = ~/.local/share/omarchy/default/hypr/bindings/tiling.conf
source = ~/.local/share/omarchy/default/hypr/bindings/utilities.conf
source = ~/.local/share/omarchy/default/hypr/envs.conf
source = ~/.local/share/omarchy/default/hypr/looknfeel.conf
source = ~/.local/share/omarchy/default/hypr/input.conf
source = ~/.local/share/omarchy/default/hypr/windows.conf
source = ~/.config/omarchy/current/theme/hyprland.conf

# User configs
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/bindings.conf
source = ~/.config/hypr/envs.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/autostart.conf

{{- $host := index .hosts .chezmoi.hostname }}

{{- if eq $host.gpu "nvidia" }}
general {
    allow_tearing = true
}

misc {
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
}
{{- end }}

# Shared window rules
windowrule {
  name = windowrule-cs2
  immediate = on
  match:class = ^(cs2)$
}

windowrule {
  name = chrome-pseudo-fullscreen
  fullscreen_state = 0 2
  match:class = ^(chrome|google-chrome|Google-chrome)$
}

# Tmux main dropdown terminal
windowrule {
  name = tmux-dropdown
  match:initial_class = ^(com\.omarchy\.tmux-main)$
  float = on
  size = 800 600
  move = 5% 15%
  workspace = special:tmux-main silent
  animation = slide top
}

# Claude Code dropdown terminal
windowrule {
  name = claude-dropdown
  match:initial_class = ^(com\.omarchy\.claude)$
  float = on
  size = 90% 70%
  move = 5% 15%
  workspace = special:claude silent
  animation = slide top
}

animation = specialWorkspace, 1, 1, default, fade
```

IMPORTANT: this template deliberately does NOT contain any `env = NVD_BACKEND...` lines (they live in `envs.conf.tmpl`) and does NOT contain any `monitor=…` lines (they live in `monitors.conf.tmpl`). Verify those lines are absent before committing.

- [ ] **Step 4: Render and inspect**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < dot_config/hypr/hyprland.conf.tmpl
```
Expected on pat-ws (`gpu: none`): the `general { allow_tearing }` and `misc { dpms }` blocks are absent; everything else is present.

- [ ] **Step 5: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add dot_config/hypr/hyprland.conf.tmpl
git commit -m "chezmoi: template hyprland.conf with nvidia-only general/misc blocks"
```

---

## Task 12: Convert `dot_config/waybar/config.jsonc` to a host-conditional template

Waybar JSON has no native include support, so host-specific modules (e.g., NVIDIA GPU temperature on `omarchy`, laptop battery on a future laptop host) are expressed as `{{ if }}` blocks inside the JSON.

**Files:**
- Modify: `dot_config/waybar/config.jsonc` → `dot_config/waybar/config.jsonc.tmpl`

- [ ] **Step 1: Read current content and diff against main**

```bash
cat /home/pat/omarchy_dotfiles_chezmoi/dot_config/waybar/config.jsonc
echo "---"
cd /home/pat/omarchy_dotfiles_chezmoi
git show main:waybar/.config/waybar/config.jsonc 2>/dev/null | head -100
```
Goal: understand what modules are guruwalk-specific vs main-specific. Typical splits: GPU temperature/usage modules (omarchy-only), strawberry MPRIS (currently guruwalk-only), tray behavior, opencode-usage module (main).

- [ ] **Step 2: Rename**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv dot_config/waybar/config.jsonc dot_config/waybar/config.jsonc.tmpl
```

- [ ] **Step 3: Edit the template**

Open `/home/pat/omarchy_dotfiles_chezmoi/dot_config/waybar/config.jsonc.tmpl`. At the top of the file (before the JSON object starts, which works because `//` line comments are allowed in jsonc):

```
// Generated by chezmoi — edit .chezmoidata.yaml or the .tmpl file, not the rendered file.
{{- $host := index .hosts .chezmoi.hostname -}}
```

Then inside the `"modules-right"` (or wherever host-specific modules live) array, wrap host-specific module names in conditionals. Example:

```jsonc
"modules-right": [
    "network",
    "pulseaudio",
    {{- if eq $host.gpu "nvidia" }}
    "custom/gpu",
    {{- end }}
    {{- if eq .chezmoi.hostname "pat-ws" }}
    "mpris",
    {{- end }}
    "clock"
],
```

And wrap any module *definition* that only applies to one host in a similar conditional:

```jsonc
{{- if eq $host.gpu "nvidia" }}
"custom/gpu": {
    "exec": "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader",
    "format": "{} C",
    "interval": 5
},
{{- end }}
```

Trailing comma rules in JSON are strict; use the `{{- ... -}}` whitespace-eating syntax to keep the rendered JSON valid. Test by rendering and running through `jq`.

- [ ] **Step 4: Render and validate as JSON**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < dot_config/waybar/config.jsonc.tmpl | \
  sed '/^[[:space:]]*\/\//d' | jq .
```
Expected: valid JSON output (jq exits 0, prints formatted JSON). If jq errors, a trailing comma slipped through — inspect and fix whitespace trimming.

- [ ] **Step 5: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add dot_config/waybar/config.jsonc.tmpl
git commit -m "chezmoi: template waybar config.jsonc with host-specific modules"
```

---

## Task 13: Convert shell files to templates (`dot_bashrc`, `dot_zshenv`)

Two goals: (1) remove the stow-era custom PATH entry that points to `~/omarchy_dotfiles/home/my_scripts/` (no longer valid — scripts are in `~/.local/bin`), (2) add a trailing host-specific block.

**Files:**
- Modify: `dot_bashrc` → `dot_bashrc.tmpl`
- Modify: `dot_zshenv` → `dot_zshenv.tmpl`

- [ ] **Step 1: Rename both**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git mv dot_bashrc dot_bashrc.tmpl
git mv dot_zshenv dot_zshenv.tmpl
```

- [ ] **Step 2: Edit `dot_bashrc.tmpl`**

Open the file. Find and remove any line resembling:

```
export PATH="$HOME/omarchy_dotfiles/home/my_scripts:$PATH"
```

(or similar referring to `omarchy_dotfiles/home/my_scripts`). `~/.local/bin` should already be on PATH via omarchy defaults; if not, add `export PATH="$HOME/.local/bin:$PATH"` unconditionally.

Add two chezmoi aliases near the top:

```bash
alias ce='chezmoi edit --apply'
alias ca='chezmoi apply'
```

At the very bottom, add a host-conditional block:

```
{{- $host := index .hosts .chezmoi.hostname }}

{{- if eq .chezmoi.hostname "omarchy" }}
# omarchy-specific bash tweaks
{{- end }}

{{- if eq .chezmoi.hostname "pat-ws" }}
# pat-ws-specific bash tweaks
{{- end }}
```

Empty conditional blocks are intentional — they're placeholder hooks for when host-specific shell config is needed. Leave them empty if there's nothing host-specific today.

- [ ] **Step 3: Edit `dot_zshenv.tmpl`**

Same treatment. Remove any stale PATH entries, add empty host-conditional placeholder blocks at the end.

- [ ] **Step 4: Render both and spot-check**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < dot_bashrc.tmpl | tail -20
chezmoi execute-template --source=. < dot_zshenv.tmpl | tail -10
```
Expected: no stale `my_scripts` PATH; chezmoi aliases present in bashrc; host blocks empty (no NVIDIA on pat-ws).

- [ ] **Step 5: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add dot_bashrc.tmpl dot_zshenv.tmpl
git commit -m "chezmoi: template shell files, drop stale PATH, add host blocks"
```

---

## Task 14: Populate `.chezmoidata.yaml` with real values

Fill in the monitors, packages, and autostart entries for both hosts by reading the existing files. This is the step that replaces the skeleton with reality.

**Files:**
- Modify: `.chezmoidata.yaml`

- [ ] **Step 1: Extract pat-ws monitor values**

These come from the current `monitors.conf` that was templated in Task 9. Look at the live values:

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git show HEAD~11:hypr/.config/hypr/monitors.conf 2>/dev/null || \
  cat /home/pat/omarchy_dotfiles/hypr/.config/hypr/monitors.conf
```
(Adjust `HEAD~N` to point at the last commit before Task 3 — or just read from the live symlinked repo.)

Also cross-check the actual `hyprland.conf`-level `monitor=` overrides that were in effect on guruwalk — those are the real live values:

```bash
grep '^monitor=' /home/pat/omarchy_dotfiles/hypr/.config/hypr/hyprland.conf
```
From the spec we know pat-ws is:
- `eDP-1,1920x1080@60.02,1920x0,1.25`
- `DP-1,1920x1080@60.00,0x0,1.00`

- [ ] **Step 2: Extract omarchy monitor values**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git show main:hypr/.config/hypr/monitors.conf | grep '^monitor='
git show main:hypr/.config/hypr/hyprland.conf | grep '^monitor=' || true
```
Record the results.

- [ ] **Step 3: Extract common vs host-specific pacman lists**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
# The canonical package list is at dot_local/bin/pacman_installed_packages.txt now.
cat dot_local/bin/pacman_installed_packages.txt | sort > /tmp/pkg-current.txt
git show main:home/my_scripts/pacman_installed_packages.txt 2>/dev/null | sort > /tmp/pkg-main.txt
comm -12 /tmp/pkg-current.txt /tmp/pkg-main.txt > /tmp/pkg-common.txt
comm -23 /tmp/pkg-current.txt /tmp/pkg-main.txt > /tmp/pkg-patws-only.txt
comm -13 /tmp/pkg-current.txt /tmp/pkg-main.txt > /tmp/pkg-omarchy-only.txt
wc -l /tmp/pkg-common.txt /tmp/pkg-patws-only.txt /tmp/pkg-omarchy-only.txt
```
`/tmp/pkg-common.txt` → goes into `packages_common`. `/tmp/pkg-patws-only.txt` → `pat-ws.packages_extra`. `/tmp/pkg-omarchy-only.txt` → `omarchy.packages_extra`.

Review the lists manually. Some "host-only" packages may actually be shared (installed on one host, wanted on both). Move those into `packages_common`. Judgment call per package.

- [ ] **Step 4: Identify per-host autostart and systemd units**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
ls dot_config/autostart/
```
For each `.desktop` file, decide which host(s) should run it. Record the exclusions — they feed `.chezmoiignore.tmpl` in Task 17.

For systemd user units: `.chezmoidata.yaml` already has `systemd_user_enable: []` — leave empty unless you have specific units in mind today.

- [ ] **Step 5: Edit `.chezmoidata.yaml` with the real data**

Overwrite `/home/pat/omarchy_dotfiles_chezmoi/.chezmoidata.yaml` with (using the values gathered above):

```yaml
hosts:
  omarchy:
    gpu: nvidia
    monitors:
      # Fill from Step 2 output. Example format:
      # - { port: eDP-1, mode: "2560x1600@240", position: "auto", scale: 1.25 }
    packages_extra:
      # Paste contents of /tmp/pkg-omarchy-only.txt as list items
    autostart: []
    systemd_user_enable: []

  pat-ws:
    gpu: none
    monitors:
      - { port: eDP-1, mode: "1920x1080@60.02", position: "1920x0", scale: 1.25 }
      - { port: DP-1,  mode: "1920x1080@60.00", position: "0x0",    scale: 1.00 }
    packages_extra:
      # Paste contents of /tmp/pkg-patws-only.txt as list items
    autostart: []
    systemd_user_enable: []

packages_common:
  # Paste contents of /tmp/pkg-common.txt as list items
```

- [ ] **Step 6: Verify YAML parses and templates render**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
python3 -c "import yaml; yaml.safe_load(open('.chezmoidata.yaml'))" && echo "YAML OK"
chezmoi execute-template --source=. < dot_config/hypr/monitors.conf.tmpl
```
Expected: YAML OK; monitors.conf renders two `monitor=` lines for pat-ws.

- [ ] **Step 7: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add .chezmoidata.yaml
git commit -m "chezmoi: populate host data (monitors, packages)"
```

---

## Task 15: Add the package install `run_onchange_before` script

**Files:**
- Create: `run_onchange_before_10-install-packages.sh.tmpl`

- [ ] **Step 1: Create the script**

Create `/home/pat/omarchy_dotfiles_chezmoi/run_onchange_before_10-install-packages.sh.tmpl` with content:

```bash
#!/usr/bin/env bash
# chezmoi re-runs this whenever its rendered content changes.
# Hash markers below force re-render when the data sources change:
# common-sha: {{ .packages_common | toYaml | sha256sum }}
# extras-sha: {{ (index .hosts .chezmoi.hostname).packages_extra | toYaml | sha256sum }}
set -euo pipefail

PACKAGES=(
{{- range .packages_common }}
  {{ . | quote }}
{{- end }}
{{- range (index .hosts .chezmoi.hostname).packages_extra }}
  {{ . | quote }}
{{- end }}
)

if [ "${#PACKAGES[@]}" -gt 0 ]; then
  sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
fi
```

- [ ] **Step 2: Render and inspect**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < run_onchange_before_10-install-packages.sh.tmpl | head -30
```
Expected: a shell script with a long list of quoted package names inside `PACKAGES=(...)`. If empty, the data from Task 14 wasn't saved — revisit.

- [ ] **Step 3: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add run_onchange_before_10-install-packages.sh.tmpl
git commit -m "chezmoi: add pacman install run_onchange script"
```

---

## Task 16: Add the systemd-user reload `run_onchange_after` script

**Files:**
- Create: `run_onchange_after_50-reload-systemd-user.sh.tmpl`
- Create (as empty dir marker): `dot_config/systemd/user/.keep`

- [ ] **Step 1: Create the reload script**

Create `/home/pat/omarchy_dotfiles_chezmoi/run_onchange_after_50-reload-systemd-user.sh.tmpl` with content:

```bash
#!/usr/bin/env bash
# Runs when any managed user-systemd unit changes.
# Hash marker forces re-render when the enable list changes:
# enable-sha: {{ (index .hosts .chezmoi.hostname).systemd_user_enable | toYaml | sha256sum }}
set -euo pipefail

systemctl --user daemon-reload

{{ range (index .hosts .chezmoi.hostname).systemd_user_enable -}}
systemctl --user enable --now {{ . | quote }}
{{ end -}}
```

- [ ] **Step 2: Create the systemd user dir with a keep marker**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p dot_config/systemd/user
touch dot_config/systemd/user/.keep
```
(`.keep` ensures git tracks the empty dir. Remove it when real units arrive.)

- [ ] **Step 3: Render and inspect**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < run_onchange_after_50-reload-systemd-user.sh.tmpl
```
Expected: a script that contains `systemctl --user daemon-reload` and no `enable --now` lines (empty list on pat-ws).

- [ ] **Step 4: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add run_onchange_after_50-reload-systemd-user.sh.tmpl dot_config/systemd/user/.keep
git commit -m "chezmoi: add systemd-user reload script and empty user unit dir"
```

---

## Task 17: Add `.chezmoiignore.tmpl` for per-host autostart exclusions

**Files:**
- Create: `.chezmoiignore.tmpl`

- [ ] **Step 1: Determine which autostart entries are host-specific**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
ls dot_config/autostart/
```

Decide per file: does it belong on `omarchy`, `pat-ws`, or both? Likely:
- `walker.desktop` — shared (walker launcher)
- `pacman_installed_dump.desktop` — shared (keeps the pacman list fresh)
- `org.keepassxc.KeePassXC.desktop` — host-specific (only where keepassxc is installed)
- `insync.desktop` — host-specific (only where insync is installed)

Record decisions.

- [ ] **Step 2: Write `.chezmoiignore.tmpl`**

Create `/home/pat/omarchy_dotfiles_chezmoi/.chezmoiignore.tmpl` with content (adjust the hostname lists per Step 1's decisions):

```gotemplate
# Files listed here are NOT deployed. Use to exclude host-specific files.

{{- if ne .chezmoi.hostname "pat-ws" }}
.config/autostart/org.keepassxc.KeePassXC.desktop
.config/autostart/insync.desktop
{{- end }}

{{- if ne .chezmoi.hostname "omarchy" }}
# add omarchy-only exclusions here as needed
{{- end }}
```

Note: chezmoi merges `.chezmoiignore` and `.chezmoiignore.tmpl`. Both can exist; we already have a static `.chezmoiignore` (for `docs/`, `README.md`).

- [ ] **Step 3: Verify the template renders without errors**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi execute-template --source=. < .chezmoiignore.tmpl
```
Expected: plain-text list of paths, with the pat-ws-only exclusions suppressed (because we ARE pat-ws) and the omarchy-only ones visible.

- [ ] **Step 4: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git add .chezmoiignore.tmpl
git commit -m "chezmoi: per-host autostart exclusions via .chezmoiignore.tmpl"
```

---

## Task 18: Resolve remaining cross-branch drift

During the restructuring we've used guruwalk's version of every shared file. Main has legitimately newer versions of some shared files (waybar, nvim theme, dropdown scripts, etc.). This task manually reviews and merges those.

**Files (based on the earlier main..guruwalk diff):**
- `dot_config/nvim/lua/plugins/theme.lua`
- `dot_config/nvim/plugin/after/transparency.lua`
- `dot_config/waybar/style.css`
- `dot_config/waybar/config.jsonc.tmpl` (careful — already templated)
- `dot_config/hypr/bindings.conf`
- `dot_config/hypr/hypridle.conf`
- `dot_config/hypr/looknfeel.conf`
- `dot_config/alacritty/alacritty.toml`
- `dot_config/git/config`
- `dot_bashrc.tmpl` (post-template)

Plus files that exist only on `main` and should be brought over:
- `dot_local/bin/executable_dropdown-opencode.sh` and/or opencode-usage waybar module bits
- `dot_local/bin/executable_waybar-mouse-battery`
- Any others found in the earlier diff labeled `D` (deleted on guruwalk vs main)

- [ ] **Step 1: Produce a current drift list**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
# Compare main vs the current migration branch, filtering out already-processed files.
git diff --name-status main..chezmoi-migration | head -50
```
The output shows what each branch has. Cross-reference with Tasks 3-14 to identify files where a main-side change wasn't pulled over.

- [ ] **Step 2: For each drift file, decide and merge**

For each file identified in Step 1, one of:

**Option A — keep chezmoi-migration's version**: do nothing, commit nothing for this file.

**Option B — pull the main version wholesale**:
```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git checkout main -- <OLD_PATH>
# Then git mv it to its new chezmoi location if it lands at the old stow path
git mv <OLD_PATH> <NEW_PATH>
```

**Option C — merge by hand**:
```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git show main:<OLD_PATH> > /tmp/main-version
# Open both in an editor, merge manually
$EDITOR <NEW_PATH> /tmp/main-version
```

Keep a running note of decisions for the commit message.

- [ ] **Step 3: Also bring over any main-only files that should be shared**

Files that exist on main but not guruwalk (identified earlier): dropdown scripts, opencode-usage widget, waybar-mouse-battery, some autostart entries. For each:

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git show main:<OLD_PATH> > dot_local/bin/executable_<BASENAME>  # or appropriate new path
chmod +x dot_local/bin/executable_<BASENAME> 2>/dev/null || true
git add dot_local/bin/executable_<BASENAME>
```

- [ ] **Step 4: Commit**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git commit -m "chezmoi: merge non-hardware drift from main branch

Files merged:
- <list decisions per file from Step 2>
New files from main:
- <list new files from Step 3>"
```

---

## Task 19: Preview-render for pat-ws and review the diff

This is the last check before touching the live system. Render the entire chezmoi source into a temp dir and diff it against the current live `~` to see exactly what `chezmoi apply` would change.

**Files:** none modified.

- [ ] **Step 1: Render into a temp destination**

```bash
rm -rf /tmp/cz-preview-patws
mkdir -p /tmp/cz-preview-patws
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi apply \
  --source=/home/pat/omarchy_dotfiles_chezmoi \
  --destination=/tmp/cz-preview-patws \
  --dry-run --verbose 2>&1 | tee /tmp/cz-dryrun.log
```
Expected: a long list of would-be writes. Exit status 0. No "template: unable to execute" errors.

- [ ] **Step 2: Render for real into the temp destination**

```bash
chezmoi apply \
  --source=/home/pat/omarchy_dotfiles_chezmoi \
  --destination=/tmp/cz-preview-patws
ls /tmp/cz-preview-patws/
```
Expected: `.config`, `.local`, `.bashrc`, `.zshenv`, `.tmux.conf`, `.vault`.

- [ ] **Step 3: Diff against live `~`**

```bash
diff -rq /tmp/cz-preview-patws ~ 2>&1 | grep -v "Only in $HOME" | less
```
Expected differences (the intentional fixes):
- NVIDIA `env = ...` lines REMOVED from `dot_config/hypr/envs.conf` (was drift on pat-ws).
- Any main-side files merged in Task 18 now appear.
- Scripts at `~/.local/bin/*` (where previously they were reachable via the old PATH entry).
- No other surprises.

If diffs include changes that weren't expected — stop and investigate before proceeding.

- [ ] **Step 4: Lint each templated file with chezmoi**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
chezmoi doctor
chezmoi managed --source=. | head -30
```
Expected: `doctor` reports all green (or only non-blocking warnings); `managed` lists every path chezmoi will deploy.

- [ ] **Step 5: Spot-check rendered content of key files**

```bash
cat /tmp/cz-preview-patws/.config/hypr/monitors.conf
cat /tmp/cz-preview-patws/.config/hypr/envs.conf
grep -A2 "allow_tearing" /tmp/cz-preview-patws/.config/hypr/hyprland.conf || echo "allow_tearing absent (correct on pat-ws)"
```
Expected:
- `monitors.conf` contains both pat-ws monitor lines.
- `envs.conf` does NOT contain `NVD_BACKEND`, `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`.
- `allow_tearing` is absent from `hyprland.conf`.

- [ ] **Step 6: No commit — this is a read-only verification task.** Proceed only if everything looks right. If not, go back and fix.

---

## Task 20: Cutover on `pat-ws` (this machine)

Replace the live stow-managed `~` with chezmoi-managed `~`. This is the first irreversible-ish step. A backup is taken so rollback is ~2 minutes.

**Files:** user's live `~/.config`, `~/.bashrc`, etc.

- [ ] **Step 1: Backup live `.config`**

```bash
cp -a ~/.config ~/.config.prechezmoi.bak
cp -a ~/.bashrc ~/.bashrc.prechezmoi.bak
cp -a ~/.zshenv ~/.zshenv.prechezmoi.bak 2>/dev/null || true
ls -d ~/.config.prechezmoi.bak
```
Expected: backup exists.

- [ ] **Step 2: Un-stow the old repo**

```bash
cd /home/pat/omarchy_dotfiles
ls -1 | grep -v -E '(^\.|README|pacman_installed|vault|docs)' > /tmp/stow-packages.txt
cat /tmp/stow-packages.txt
for pkg in $(cat /tmp/stow-packages.txt); do
  stow -D -t ~ "$pkg" 2>&1 || echo "SKIP: $pkg"
done
```
Expected: symlinks removed from `~`. Any package that wasn't stowed errors harmlessly.

- [ ] **Step 3: Verify symlinks are gone**

```bash
ls -la ~/.config/hypr/hyprland.conf
```
Expected: file missing (no symlink). If it's still a symlink, `stow -D` didn't catch it — remove manually.

- [ ] **Step 4: Initialize chezmoi from the local migration source**

```bash
chezmoi init --apply --source=/home/pat/omarchy_dotfiles_chezmoi
```
Expected: chezmoi clones (or just references) the local dir, runs templates, deploys files, runs the package install script (will prompt for sudo). On error, proceed to rollback (Step 7).

- [ ] **Step 5: Verify deployment**

```bash
ls -la ~/.config/hypr/hyprland.conf
cat ~/.config/hypr/monitors.conf | head
echo $PATH | tr ':' '\n' | grep -E '\.local/bin'
```
Expected:
- `hyprland.conf` is a real file (not a symlink).
- `monitors.conf` shows the two pat-ws monitor lines.
- `~/.local/bin` is on PATH.

- [ ] **Step 6: Reload the desktop and test**

```bash
hyprctl reload
killall -SIGUSR2 waybar 2>/dev/null || systemctl --user restart waybar 2>/dev/null || true
exec bash
```
Exercise: open a tmux session, launch a dropdown (Super+...), check waybar modules render, check keybindings work. Don't proceed until everything looks normal.

- [ ] **Step 7: ROLLBACK PROCEDURE (only if Step 5 or 6 failed)**

```bash
chezmoi purge --force      # removes chezmoi state
rm -rf ~/.config
mv ~/.config.prechezmoi.bak ~/.config
mv ~/.bashrc.prechezmoi.bak ~/.bashrc
mv ~/.zshenv.prechezmoi.bak ~/.zshenv 2>/dev/null || true
cd /home/pat/omarchy_dotfiles
for pkg in $(cat /tmp/stow-packages.txt); do
  stow -t ~ "$pkg" 2>&1 || echo "SKIP: $pkg"
done
hyprctl reload
```
You're back on the old stow system. Debug the issue before re-attempting.

- [ ] **Step 8: (only on success) Stop here for the day**

Do NOT proceed to publishing until the machine has run stably for at least a few hours. This is the safety gate.

---

## Task 21: Publish to origin and update `main`

Only run this after Task 20 succeeds and pat-ws has been stable for at least a few hours.

**Files:** remote branches only.

- [ ] **Step 1: Push the migration branch to origin**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git push origin chezmoi-migration
```
Expected: new branch on origin.

- [ ] **Step 2: Force-update `main` to the migration tip**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git push origin +chezmoi-migration:main
```
Expected: `main` on origin now points at the migration tip. Force-push is deliberate and documented in the spec.

- [ ] **Step 3: Delete the old `guruwalk` branch**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git push origin :guruwalk
git branch -D guruwalk 2>/dev/null || true
```
Expected: `guruwalk` gone on origin.

- [ ] **Step 4: Update local main and clean up migration branch**

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
git fetch origin
git checkout main
git reset --hard origin/main
git branch -D chezmoi-migration 2>/dev/null || true
git log --oneline -3
```
Expected: local `main` tracks `origin/main` at the migration tip.

---

## Task 22: Cutover on `omarchy` (the NVIDIA host)

Same procedure as Task 20, run ON the `omarchy` physical machine. Note this is executed on a different machine — the steps below are what you type there.

- [ ] **Step 1: On omarchy, verify hostname**

```bash
hostname
```
Expected: `omarchy`.

- [ ] **Step 2: Install chezmoi**

```bash
sudo pacman -S --needed --noconfirm chezmoi
```

- [ ] **Step 3: Back up live config**

```bash
cp -a ~/.config ~/.config.prechezmoi.bak
cp -a ~/.bashrc ~/.bashrc.prechezmoi.bak
cp -a ~/.zshenv ~/.zshenv.prechezmoi.bak 2>/dev/null || true
```

- [ ] **Step 4: Un-stow the old repo**

```bash
cd ~/omarchy_dotfiles  # adjust path if different on omarchy
ls -1 | grep -v -E '(^\.|README|pacman_installed|vault|docs)' > /tmp/stow-packages.txt
for pkg in $(cat /tmp/stow-packages.txt); do
  stow -D -t ~ "$pkg" 2>&1 || echo "SKIP: $pkg"
done
```

- [ ] **Step 5: Init chezmoi from GitHub**

```bash
chezmoi init --apply https://github.com/PatFitzner/omarchy_dotfiles.git
```
Expected: clones from origin, renders templates for hostname=`omarchy`, installs packages. NVIDIA env vars SHOULD appear in the rendered `envs.conf`; `allow_tearing` SHOULD appear in `hyprland.conf`.

- [ ] **Step 6: Verify NVIDIA-specific content rendered**

```bash
grep NVD_BACKEND ~/.config/hypr/envs.conf && echo "NVIDIA env OK"
grep allow_tearing ~/.config/hypr/hyprland.conf && echo "allow_tearing OK"
cat ~/.config/hypr/monitors.conf
```
Expected: both greps succeed; monitors.conf shows omarchy's display layout.

- [ ] **Step 7: Reload and test**

```bash
hyprctl reload
killall -SIGUSR2 waybar || true
exec bash
```
Exercise the normal workflows. If broken, run the rollback (same as Task 20 Step 7).

- [ ] **Step 8: Push the old guruwalk repo out of mind**

On omarchy the old `~/omarchy_dotfiles/` stow repo is now inert. Leave it in place for a week as safety, then delete.

---

## Task 23: Cleanup

After both hosts have been running cleanly for ~1 week.

**Files:** local scratch only.

- [ ] **Step 1: Delete the old stow repo on pat-ws**

```bash
rm -rf /home/pat/omarchy_dotfiles
```

- [ ] **Step 2: Delete the migration-copy repo**

The copy served its purpose: it was the workspace for the restructuring. chezmoi's source of truth is now `~/.local/share/chezmoi` (cloned from origin during `chezmoi init`).

```bash
rm -rf /home/pat/omarchy_dotfiles_chezmoi
```

- [ ] **Step 3: Delete backups**

```bash
rm -rf ~/.config.prechezmoi.bak ~/.bashrc.prechezmoi.bak ~/.zshenv.prechezmoi.bak
```

- [ ] **Step 4: Confirm chezmoi source is the cloned repo**

```bash
chezmoi source-path
```
Expected: `/home/pat/.local/share/chezmoi`

- [ ] **Step 5: Repeat the cleanup on omarchy**

SSH in or physically use the machine, run the same three `rm -rf` commands.

- [ ] **Step 6: Celebrate — single-branch dotfiles with host-conditional config is live.**

---

## Self-review checklist (run after completing all tasks)

- `chezmoi diff` on both hosts → empty (no pending changes).
- `chezmoi apply` on both hosts → no-op (idempotent).
- Edit a test file via `ce ~/.bashrc` → verify change lands.
- Break a template on purpose (e.g., reference an undefined var), run `chezmoi apply`, confirm a clear error → undo.
- Add a fake host #3 to `.chezmoidata.yaml`, render templates in simulation, remove the fake host.
