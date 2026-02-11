# Development

## Adding a Custom Chroot Hook

Chroot hooks are shell scripts that run inside the Debian filesystem during the build. They are the primary mechanism for customizing the installed system.

### Creating a new hook

Edit `scripts/07-hooks.sh` and add a new hook block. Hooks are numbered and executed in order:

```bash
# Hook: My Custom Configuration
cat > "${CONFIG_DIR}/hooks/normal/070-my-custom.chroot" <<'EOF'
#!/bin/sh
set -e

# Your commands here — these run inside the chroot as root
echo "Custom hook running"

# Example: install a systemd service
cat > /etc/systemd/system/my-service.service << 'EOS'
[Unit]
Description=My Custom Service

[Service]
ExecStart=/usr/local/bin/my-script
Restart=always

[Install]
WantedBy=multi-user.target
EOS

systemctl enable my-service
EOF
chmod +x "${CONFIG_DIR}/hooks/normal/070-my-custom.chroot"
```

### Hook numbering convention

| Range | Purpose |
|-------|---------|
| 010-019 | Core system (password, SSH, networking) |
| 020-029 | Kiosk mode setup |
| 030-039 | Login and autologin |
| 040-049 | Security hardening |
| 050-059 | Package management (APT) |
| 060-069 | Desktop, GRUB, wallpaper, shortcuts |
| 070+ | Custom / user hooks |

### Using template variables

If your hook needs values from `config.env`, use the template pattern:

```bash
cat > "${CONFIG_DIR}/hooks/normal/070-my-custom.chroot" <<'EOF'
#!/bin/sh
set -e
echo "Product: {{MY_VARIABLE}}"
EOF

# Substitute the variable
sed -i "s|{{MY_VARIABLE}}|${MY_VARIABLE}|g" \
  "${CONFIG_DIR}/hooks/normal/070-my-custom.chroot"
chmod +x "${CONFIG_DIR}/hooks/normal/070-my-custom.chroot"
```

Note the use of `<<'EOF'` (single-quoted) to prevent premature expansion, followed by explicit `sed` substitution.

## Adding Files to the Installed System

To include files in the installed system, add them to `config/includes.chroot/` during the build. This is done in `scripts/05-config-tree.sh`:

```bash
# Example: add a custom script
cat > "${CONFIG_DIR}/includes.chroot/usr/local/bin/my-script" <<'EOF'
#!/bin/bash
echo "Hello from DisplayOS"
EOF
chmod +x "${CONFIG_DIR}/includes.chroot/usr/local/bin/my-script"
```

Files placed in `config/includes.chroot/` are copied directly into the root filesystem of the installed system, preserving their path structure.

## Adding Files to the ISO

To include files on the ISO medium (not in the installed system), add them to `config/includes.binary/`:

```bash
mkdir -p "${CONFIG_DIR}/includes.binary/my-data"
cp my-file.txt "${CONFIG_DIR}/includes.binary/my-data/"
```

These files are accessible from the boot media at `/cdrom/my-data/` (or wherever the ISO is mounted).

## Adding a New Build Stage

If you need a new build step, create a script in `scripts/` with the next available number and add a `run_script` call in `build.sh`:

1. Create the script:

```bash
# scripts/055-my-step.sh
#!/usr/bin/env bash
echo -e "${BLUE}[+] Running my custom step...${NOCOLOR}"

# Your build logic here

echo -e "${GREEN}[+] My custom step completed${NOCOLOR}"
```

2. Add it to `build.sh` between the appropriate existing steps:

```bash
run_script "05-config-tree.sh"
run_script "055-my-step.sh"        # <-- new step
run_script "06-installer-branding.sh"
```

Since scripts are sourced (not executed), they have full access to all environment variables and functions defined in `build.sh` and `config.env`.

## Adding a New Configuration Variable

1. Define the variable with a default in `config.env`:

```bash
export MY_VARIABLE="${MY_VARIABLE:-default_value}"
```

2. Use it in the relevant script (via direct reference or template substitution).

3. Document it in `docs/Configuration.md`.

## Project Conventions

### Shell scripts

- All scripts use `#!/usr/bin/env bash`.
- `build.sh` sets `set -euo pipefail` — all sourced scripts inherit this.
- Color codes (`$RED`, `$GREEN`, `$YELLOW`, `$BLUE`, `$NOCOLOR`) are defined in `build.sh`.
- Log messages use `echo -e` for color support.
- Status prefixes: `[+]` for actions, `[i]` for info, `[!]` for warnings/errors.

### Template substitution

- Templates use `{{VARIABLE_NAME}}` placeholders.
- Substitution is performed with `sed -i` after writing the file.
- Heredocs that contain templates use `<<'EOF'` (single-quoted) to prevent bash from expanding `$` characters prematurely.

### Generated files

- All files under `config/` are generated at build time and should not be edited manually.
- The `config/` directory is deleted and recreated at the start of `scripts/05-config-tree.sh`.

## Testing Changes

1. Build with debug mode to see detailed output:
   ```bash
   sudo -E DEBUG=yes ./build.sh
   ```

2. Test the ISO in a VM (QEMU example):
   ```bash
   qemu-system-x86_64 \
     -m 4096 \
     -cdrom output/DisplayOS-bookworm-amd64-unattended.iso \
     -boot d \
     -enable-kvm \
     -bios /usr/share/ovmf/OVMF.fd
   ```

3. For faster iteration, inspect generated files before running `lb build`:
   ```bash
   # Run only up to step 8 (preseed), then inspect
   # Check generated hooks:
   cat config/hooks/normal/*.chroot
   # Check preseed:
   cat config/includes.binary/preseed/displayos.cfg
   # Check package list:
   cat config/package-lists/displayos.list.chroot
   ```

## Related Docs

- [Build Process](BuildProcess.md) — full pipeline reference
- [Directory Structure](DirectoryStructure.md) — where files go
- [Configuration](Configuration.md) — adding new variables
