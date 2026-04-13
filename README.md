# dotfiles

Chezmoi-managed dotfiles for Arch Linux + Hyprland across multiple machines.

## Fresh install

```bash
# 1. Install chezmoi + apply in one shot (even if chezmoi isn't installed yet)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply PatFitzner/omarchy_dotfiles

# 2. Drop the age decryption key (get it from your vault / backup)
mkdir -p ~/.config/chezmoi
cp /path/to/key.txt ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# 3. Re-apply so encrypted files (SSH keys) get decrypted
chezmoi apply
```

Unknown hostnames get sane defaults (no GPU, auto-detected monitor, common packages only). Add a host entry in `.chezmoidata.yaml` to customize.

## Day-to-day cheat sheet

| Do this                        | Command                            |
|--------------------------------|------------------------------------|
| See what would change          | `chezmoi diff`                     |
| Apply all changes              | `chezmoi apply`                    |
| Edit a managed file            | `chezmoi edit ~/.config/hypr/hyprland.conf` |
| Edit + apply in one go         | `chezmoi edit --apply <file>`      |
| Add a new file                 | `chezmoi add ~/.config/foo/bar`    |
| Add a file as a template       | `chezmoi add --template <file>`    |
| Add a secret (age-encrypted)   | `chezmoi add --encrypt <file>`     |
| Pull latest + apply            | `chezmoi update`                   |
| Re-enter source dir            | `chezmoi cd` or `cd ~/dotfiles`    |

## Secrets (age encryption)

Encrypted files end in `.age` in the source dir. They're decrypted on `chezmoi apply` using `~/.config/chezmoi/key.txt`.

```bash
# Decrypt and view a secret without applying
chezmoi cat ~/.ssh/id_ed25519

# Add a new secret
chezmoi add --encrypt ~/.ssh/some_key

# Re-encrypt after rotating the age key
chezmoi re-add ~/.ssh/id_ed25519
```

Currently encrypted: SSH private keys + Oracle certs.

## Adding a new host

Works out of the box with defaults. To customize:

1. Add a section under `hosts:` in `.chezmoidata.yaml` matching the new hostname
2. Only set fields you want to override — everything else falls back to `defaults:`
3. Add any host-specific ignore rules in `.chezmoiignore.tmpl`
4. `chezmoi apply`

## Repo layout

```
.chezmoidata.yaml          # Per-host variables (gpu, monitors, packages)
.chezmoiignore.tmpl        # Per-host file exclusions
dot_config/                 # ~/.config/*
dot_local/                  # ~/.local/*
dot_ssh/                    # ~/.ssh/* (encrypted private keys)
dot_bashrc.tmpl             # Templated shell configs
dot_zshenv.tmpl
run_onchange_before_*       # Auto-runs: package install
run_onchange_after_*        # Auto-runs: systemd reload
```

Files ending in `.tmpl` are Go templates — they use values from `.chezmoidata.yaml` and `chezmoi.hostname`.
