# chezmoi Migration: Single-Branch Dotfiles with Host-Conditional Config

**Date:** 2026-04-10
**Status:** Design approved, pending spec review
**Author:** Pat (with Claude)

## Problem

The `omarchy_dotfiles` repo currently uses one git branch per machine (`main` for the `omarchy` host, `guruwalk` for `pat-ws`), deployed with GNU stow. Branches drift on both hardware-specific and shared concerns, creating a constant merge burden and making it unclear which changes are per-host versus global. Example of drift visible today: NVIDIA env vars in `hyprland.conf` apply on `pat-ws` despite that machine having no NVIDIA GPU, because the setting was originally authored on the `omarchy` branch and propagated.

## Goal

Consolidate to a single `main` branch managed by [chezmoi](https://chezmoi.io). Host-specific values (monitors, GPU driver env vars, installed packages, autostart entries) are expressed as either data in a central file or inline template conditionals. Adding a new machine is a single PR that adds a host entry; no branches, no merges.

## Non-goals

- Encrypted secret management via chezmoi. The existing `vault` file is already encrypted externally and is shipped as a plain static file. Secret management can be added later with age or gpg if needed.
- Full home-manager / Nix-style declarative **system** state. System-level systemd units (in `/etc/systemd/system/`), `/etc/` files, sysctls, modprobe configs, kernel modules, bootloader, initramfs, partitioning, and display managers remain managed outside this repo. User-level systemd units (`~/.config/systemd/user/`) **are** in scope — they're dotfiles.
- Runtime omarchy theme state (`~/.config/omarchy/current/`). This directory is written to on the fly by omarchy's theme switcher and is explicitly excluded.

## What differs per host, and how it's represented

| Category | Machine-specific? | Representation |
|---|---|---|
| Hardware (monitors, scaling, GPU env vars) | Yes | `.chezmoidata.yaml` (data) + templates |
| Peripherals (input, keyboard firmware) | No | Static files |
| Theme look, shaders, colors | No | Static files |
| Keybindings | No | Static files |
| Autostart services | Hybrid (shared + extras) | Static `.desktop` files + per-host `.chezmoiignore.tmpl` exclusions |
| Installed pacman packages | Hybrid (common + extras) | `packages_common` + per-host `packages_extra` in `.chezmoidata.yaml`, installed by `run_onchange_` script |
| Scripts (my_scripts, tmux helpers) | No | Static, relocated to `dot_local/bin/` |
| Shell (`.bashrc`, `.zshenv`) | Hybrid | Templates with host-conditional blocks |
| User systemd units (`~/.config/systemd/user/*.service`, `*.timer`) | Hybrid | Static or `.tmpl`; activated by a `run_onchange_after_` script |
| `vault` (encrypted) | No | Static, shipped as-is |
| `omarchy/current/` runtime state | N/A | Excluded from chezmoi source and git |

## Architecture

### Three chezmoi primitives

1. **Templates (`*.tmpl`)** — any file that needs host-conditional logic. Uses Go template syntax: `{{ if eq .chezmoi.hostname "pat-ws" }}…{{ end }}` for one-off toggles, `{{ range … }}` for structured data.
2. **Host data file (`.chezmoidata.yaml`)** — structured facts per host (GPU, monitors, package lists). Templates read it via top-level keys.
3. **Run-on-change scripts (`run_onchange_*.sh.tmpl`)** — chezmoi re-runs when rendered content changes. Used for package installation and any other idempotent bootstrap.

### Styling rule

**Data-driven where the variation is structured; `if` blocks for one-off cases.** Monitor specs are data (they repeat, have fields, appear on every host). NVIDIA env vars are an `if` block (one-off toggle, only one host has them). When in doubt, prefer data — it scales better to host #3.

## Host data model

File: `.chezmoidata.yaml` at the root of the chezmoi source tree.

```yaml
hosts:
  omarchy:
    gpu: nvidia
    monitors:
      - { port: eDP-1, mode: "2560x1600@240", position: "auto", scale: 1.25 }
    packages_extra:
      - nvidia
      - nvidia-utils
      # (to be filled from current main branch during migration)
    autostart:
      # host-specific .desktop basenames
    systemd_user_enable: []   # user unit names to enable --now

  pat-ws:
    gpu: none
    monitors:
      - { port: eDP-1, mode: "1920x1080@60.02", position: "1920x0", scale: 1.25 }
      - { port: DP-1,  mode: "1920x1080@60.00", position: "0x0",    scale: 1.00 }
    packages_extra: []   # filled during migration
    autostart: []
    systemd_user_enable: []

packages_common:
  # shared pacman list, derived from the current pacman_installed_packages.txt
  # minus anything identified as host-specific
```

### Rules

- Each host key is the literal output of `hostname` on that machine.
- Adding host #3 = adding a key. No new files, no new branches.
- Unknown hostname on `chezmoi init` **fails loudly** (template errors on missing map key) — silent defaults hide problems.
- Secrets do NOT go in this file. It's committed plain.

### Starter field set (YAGNI)

Begin with exactly: `gpu`, `monitors`, `packages_extra`, `autostart`, `systemd_user_enable`. Add fields (`features`, `role`, etc.) only when a concrete case requires them.

## Repo layout

```
omarchy_dotfiles/                          # repo root; chezmoi source dir
├── .chezmoidata.yaml
├── .chezmoiignore.tmpl                    # per-host file exclusion
├── .gitignore                             # excludes docs/ deployment? no — see below
│
├── dot_config/
│   ├── hypr/
│   │   ├── hyprland.conf.tmpl             # host-conditional blocks
│   │   ├── monitors.conf.tmpl             # data-driven from .chezmoidata
│   │   ├── envs.conf.tmpl                 # NVIDIA block wrapped in {{ if }}
│   │   ├── bindings.conf                  # static
│   │   ├── looknfeel.conf                 # static
│   │   ├── input.conf                     # static
│   │   ├── hypridle.conf                  # static (or .tmpl if diverged laptop/desktop)
│   │   ├── hyprlock.conf                  # static
│   │   ├── scripts/                       # static
│   │   └── shaders/                       # static
│   ├── waybar/
│   │   ├── config.jsonc.tmpl              # host-conditional modules
│   │   └── style.css                      # static
│   ├── alacritty/alacritty.toml           # static (promote to .tmpl if host-specific)
│   ├── git/config                         # static
│   ├── mako/, walker/, ghostty/, kitty/   # static
│   ├── nvim/                              # static
│   ├── tmux/tmux.conf                     # static
│   ├── autostart/
│   │   ├── org.keepassxc.KeePassXC.desktop
│   │   └── (other .desktop files, excluded per-host via .chezmoiignore.tmpl)
│   ├── systemd/user/
│   │   ├── (e.g. foo.service, foo.timer)  # static or .tmpl; per-host via .chezmoiignore.tmpl
│   └── strawberry/strawberry.conf         # static
│
├── dot_local/bin/
│   ├── executable_new-worktree
│   ├── executable_tmux-main
│   ├── executable_tmux-dropdown-session
│   ├── executable_tmux-select-branch
│   ├── executable_toggle-tmux-dropdown
│   ├── executable_toggle-claude-dropdown
│   └── executable_omarchy-install-extra-themes.sh
│
├── dot_bashrc.tmpl                        # host-conditional block at bottom
├── dot_zshenv.tmpl                        # host-conditional block at bottom
├── dot_vault                              # pre-encrypted, static
│
├── run_onchange_before_10-install-packages.sh.tmpl
├── run_onchange_after_50-reload-systemd-user.sh.tmpl
│
├── docs/                                  # NOT deployed; excluded via .chezmoiignore
│   └── superpowers/specs/
│       └── 2026-04-10-chezmoi-migration-design.md
│
└── README.md                              # NOT deployed
```

### Layout notes

- **No `.chezmoiroot`.** Source lives at repo root. `docs/` and `README.md` are excluded via `.chezmoiignore` (static lines, not the templated `.chezmoiignore.tmpl`).
- **`my_scripts/` → `dot_local/bin/`.** `~/.local/bin` is already on PATH on omarchy. The custom PATH entry in `.bashrc` is removed as part of the migration.
- **`executable_` prefix** on files in `dot_local/bin/` sets the +x bit.
- **`dot_config/omarchy/current/` is NOT in source and IS in `.gitignore`.** This directory is volatile runtime state written by omarchy's theme switcher. The migration also `git rm`s whatever is currently tracked there (visible on `main`).
- **Theme files** (static files under omarchy's theme path, *not* `current/`) are static — shared across hosts.
- **`vault`** is a plain static file at `dot_vault` → `~/.vault`. Already encrypted externally; chezmoi does not peek inside.

### Templated file details

**`dot_config/hypr/monitors.conf.tmpl`** — data-driven:

```gotemplate
# Generated by chezmoi — edit .chezmoidata.yaml, not this file directly.
{{- $host := index .hosts .chezmoi.hostname -}}
{{ range $host.monitors }}
monitor={{ .port }},{{ .mode }},{{ .position }},{{ .scale }}
{{- end }}
```

**`dot_config/hypr/envs.conf.tmpl`** — `if` block:

```gotemplate
{{- $host := index .hosts .chezmoi.hostname -}}
{{- if eq $host.gpu "nvidia" }}
env = NVD_BACKEND,direct
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
{{- end }}
```

**`run_onchange_before_10-install-packages.sh.tmpl`** — installs common + host-extra packages. Re-runs when rendered content changes:

```bash
#!/usr/bin/env bash
# chezmoi re-runs on change. Hash markers below force re-render when data changes:
# common:  {{ .packages_common | toYaml | sha256sum }}
# extras:  {{ (index .hosts .chezmoi.hostname).packages_extra | toYaml | sha256sum }}
set -euo pipefail
sudo pacman -S --needed --noconfirm \
  {{ range .packages_common }}{{ . }} {{ end }} \
  {{ range (index .hosts .chezmoi.hostname).packages_extra }}{{ . }} {{ end }}
```

**`run_onchange_after_50-reload-systemd-user.sh.tmpl`** — runs only when user systemd units change. Reloads the user daemon and enables any units that should be enabled on this host:

```bash
#!/usr/bin/env bash
# Re-runs when any managed user unit changes.
set -euo pipefail
systemctl --user daemon-reload
{{ range (index .hosts .chezmoi.hostname).systemd_user_enable -}}
systemctl --user enable --now {{ . }}
{{ end -}}
```

The list of units to enable lives in `.chezmoidata.yaml` under each host as `systemd_user_enable: []`. Keep the list small — units authored as "enabled by default" only.

**`.chezmoiignore.tmpl`** — excludes autostart entries that don't belong on the current host:

```gotemplate
{{- if ne .chezmoi.hostname "pat-ws" }}
.config/autostart/org.keepassxc.KeePassXC.desktop
{{- end }}
# ...add more per-host exclusions as needed
```

**`dot_bashrc.tmpl`** and **`dot_zshenv.tmpl`** — shared content at top, host-conditional block at bottom. If the host-specific section grows large, split it into a sourced file later.

## Bootstrap and daily workflow

### New-machine bootstrap

```bash
sudo pacman -S --needed chezmoi git
chezmoi init --apply https://github.com/PatFitzner/omarchy_dotfiles.git
```

Source dir: `~/.local/share/chezmoi` (chezmoi default). Hidden, matches upstream docs.

If the hostname isn't in `.chezmoidata.yaml`, chezmoi fails with a clear error. Fix:

```bash
chezmoi edit .chezmoidata.yaml    # add new host key
chezmoi apply
```

### Daily editing workflow

The biggest UX change from stow: edits don't happen directly on the live file.

Preferred command (added as alias `ce`):
```bash
chezmoi edit ~/.config/hypr/hyprland.conf --apply
```
Opens the *source* file (finds the `.tmpl` if present), applies on save.

Fallbacks:
- Edit source directly in `~/.local/share/chezmoi/`, then `chezmoi apply` (alias `ca`).
- `chezmoi re-add <file>` to capture changes made directly to the live file.

### Inspection

- `chezmoi diff` — preview what `apply` would change.
- `chezmoi status` — one-letter summary.
- `chezmoi managed` — list all managed paths.
- `chezmoi doctor` — sanity check.

### Reload

No change from today:
- Hyprland: `hyprctl reload` / Super+Esc.
- Waybar: `killall -SIGUSR2 waybar`.
- Shell: new terminal or `exec $SHELL`.

No automatic `run_onchange_after_*` reload scripts at migration time. Add later if useful (YAGNI).

## Migration plan

All migration work happens in `/home/pat/omarchy_dotfiles_chezmoi/` (a copy of the live repo). The live `/home/pat/omarchy_dotfiles/` remains stowed and functional throughout phases 0–3. The copy exists because stow symlinks would otherwise propagate in-progress restructuring to live configs.

### Phase 0 — Prep

- Create branch `chezmoi-migration` in the copy.
- `sudo pacman -S chezmoi` (if not already installed).
- All subsequent phases commit onto this branch.

### Phase 1 — Restructure the file tree

- `git rm -r` the stow-style top-level dirs: `hypr/`, `waybar/`, `home/`, `alacritty/`, `git/`, `autostart/`, `nvim/`, `tmux/`, `omarchy/`, `menus/`, `strawberry/`, `sofle_choc/`.
- Recreate files under the new layout (`dot_config/…`, `dot_local/bin/…`, `dot_bashrc.tmpl`, etc.). Use `git mv` where possible to preserve rename history.
- Add `.chezmoiignore` excluding `docs/` and `README.md`.
- Add `.gitignore` rule for `dot_config/omarchy/current/`.
- Commit: `chezmoi: restructure source tree`.

### Phase 2 — Write `.chezmoidata.yaml` and convert host-specific files

- Author `.chezmoidata.yaml` with entries for `omarchy` and `pat-ws`. Values are pulled from both branches: `git show main:hypr/.config/hypr/monitors.conf` for omarchy's monitor layout, the current working copy for pat-ws.
- Convert to templates: `hyprland.conf`, `monitors.conf`, `envs.conf`, `waybar/config.jsonc`, `.bashrc`, `.zshenv`, anything else identified as host-specific.
- Build `run_onchange_before_10-install-packages.sh.tmpl`. Split the current `pacman_installed_packages.txt` into `packages_common` and per-host `packages_extra`.
- Resolve non-hardware drift between branches (shaders, themes, dropdown scripts, waybar styling): pick the intended canonical version for each, commit once.
- Add `.chezmoiignore.tmpl` for per-host autostart exclusions.
- Commit: `chezmoi: add host data and convert host-specific files`.

### Phase 3 — Verify without deploying

Render into a temp destination and inspect:

```bash
cd /home/pat/omarchy_dotfiles_chezmoi
mkdir -p /tmp/cz-preview-patws
chezmoi apply \
  --source=. \
  --destination=/tmp/cz-preview-patws \
  --dry-run --verbose
chezmoi apply --source=. --destination=/tmp/cz-preview-patws
diff -r /tmp/cz-preview-patws ~ | less
```

Expected differences (reviewed manually):

- NVIDIA env vars **removed** from `hyprland`/`envs` on pat-ws (the intentional drift fix).
- Any shared-but-out-of-sync files now matching their canonical version.
- No other surprises.

Simulate the `omarchy` host as well by forcing hostname data:

```bash
mkdir -p /tmp/cz-preview-omarchy
chezmoi apply \
  --source=. \
  --destination=/tmp/cz-preview-omarchy \
  --config-format=yaml \
  <override hostname via config>
```
(Exact incantation verified during implementation; chezmoi supports `--data` injection.)

Iterate on templates until both rendered trees look correct.

### Phase 4 — Cutover on `pat-ws`

1. Backup: `cp -a ~/.config ~/.config.prechezmoi.bak`.
2. Un-stow the old repo: `cd /home/pat/omarchy_dotfiles && stow -D -t ~ <each package>`. Leaves repo files intact, removes symlinks from `~`.
3. `chezmoi init --apply --source=/home/pat/omarchy_dotfiles_chezmoi`. (Local source; we push to origin only after cutover is verified.)
4. Reload: `hyprctl reload`, restart waybar, open new shell. Verify hypr, waybar, shell, autostart, key apps all work.
5. **Rollback plan** (if broken): `chezmoi purge`, restore from `~/.config.prechezmoi.bak`, re-stow the old repo. Target rollback time: under two minutes.

### Phase 5 — Publish and cutover on `omarchy`

1. `git push origin chezmoi-migration`.
2. Force-update main: `git push origin +chezmoi-migration:main`. This replaces `main` with the new layout. Force-push is intentional and acceptable because the dotfiles repo has one consumer (the user).
3. Delete `guruwalk`: `git push origin :guruwalk` and `git branch -D guruwalk` locally.
4. On the `omarchy` physical machine: un-stow, `chezmoi init --apply https://github.com/PatFitzner/omarchy_dotfiles.git`. Same backup/rollback procedure as phase 4.

### Phase 6 — Cleanup

- After a week of stable running on both machines: delete `/home/pat/omarchy_dotfiles/` on pat-ws and the `.config.prechezmoi.bak` backup.
- Reset chezmoi source to the GitHub URL if phase 4 used a local path (done automatically if `chezmoi init --apply <url>` was used).

## Testing strategy

Dotfiles don't have traditional unit tests. Verification is manual but structured:

1. **Template rendering correctness** (phase 3): `chezmoi apply --destination=/tmp/…` on both host identities, visual review of the rendered tree.
2. **Live behavior** (phase 4/5): after cutover, verify on each machine — hypr reloads cleanly, waybar shows expected modules, keybindings work, autostart apps launch, shell aliases resolve, `$PATH` includes `~/.local/bin`.
3. **Idempotency**: `chezmoi apply` twice in a row — second run should be a no-op.
4. **Package script re-run safety**: `run_onchange` script uses `pacman -S --needed`, safe to re-invoke.

No automated CI — too much friction for a personal dotfiles repo at two machines. Revisit if the repo grows more consumers.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Cutover breaks a running machine | Backup `.config`, rollback via un-apply + restore + re-stow |
| Template error from typo in `.chezmoidata.yaml` | `chezmoi apply --dry-run` before every real apply during early use |
| Forgetting `chezmoi apply` after editing source | Alias `ce='chezmoi edit --apply'` trains the habit |
| Accidentally editing a live file instead of source | `chezmoi re-add` recovers; eventually becomes muscle memory |
| Package script runs on every apply | `run_onchange_` prefix + hash markers ensure it only re-runs on content change |
| Host #3 has subtly different hardware assumptions | Starter fields (`gpu`, `monitors`, `packages_extra`, `autostart`) cover most cases; add fields as needed (no premature abstraction) |

## Open questions for implementation time

These are deliberately deferred to avoid premature decisions:

- Does `hypridle.conf` need to differ between laptop and desktop? Revisit when a laptop host appears.
- Do we want `run_onchange_after_*` reload scripts for waybar/hypr? Only if manual reload becomes annoying.
- Does `alacritty.toml` need per-host font sizing? Only if it actually differs.
- Does `vault` belong under `private_dot_vault` (0600 perms) rather than plain `dot_vault`? Likely yes — confirm at implementation time.
