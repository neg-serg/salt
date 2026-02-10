# Remaining Packages — Installation Plan

Execution plan for installing all remaining ~47 packages from the NixOS migration.
Each step includes the exact changes needed in Salt states and supporting files.

---

## Phase 0: Mark as SKIP / Not Needed

These items should be removed from the inventory and marked done:

| Package | Reason |
|---------|--------|
| spotify-tui | Abandoned (2021), broken Spotify API. Use `spotatui` fork if needed later |
| wireless-tools | Deprecated; `iw` (already installed) is the modern replacement |
| update-resolv-conf | Fedora uses systemd-resolved; not applicable |
| read-edid | Use `edid-decode` (in Fedora repos) instead; `ddcutil` already installed |
| cider | Paid app ($3.49 on itch.io); Apple Music only; skip |
| beautifulsoup4 | Not needed (was a Python lib in NixOS, not a standalone tool) |
| pynvim | Not needed (already present via pip, nvr works) |
| fontforge | Not needed |
| fonttools | Not needed |

**Action**: Remove these 9 entries from `nixos-packages-inventory.md`.

---

## Phase 1: Fedora RPM Repos (3 packages)

Add to `states/system_description.sls` in appropriate categories.

| Package | RPM Name | Category |
|---------|----------|----------|
| below | `below` | Monitoring |
| media-player-info | `media-player-info` | Multimedia |
| kernel-tools (turbostat) | `kernel-tools` | Monitoring |

**File**: `states/system_description.sls`
**Action**: Add `{name: 'below', desc: 'BPF time-traveling system monitor'}`,
`{name: 'media-player-info', desc: 'udev data for media players'}`,
`{name: 'kernel-tools', desc: 'turbostat and other kernel utilities'}` to the
appropriate category dicts.

---

## Phase 2: COPR Repositories (7 packages)

Each needs a `copr_<name>` + `install_<name>` state pair in `system_description.sls`,
following the existing `copr_dualsensectl` pattern.

| Package | COPR Repo | RPM Name |
|---------|-----------|----------|
| espanso | `eclipseo/espanso` | `espanso-wayland` |
| himalaya | `atim/himalaya` | `himalaya` |
| spotifyd | `mbooth/spotifyd` | `spotifyd` |
| sbctl | `chenxiaolong/sbctl` | `sbctl` |
| yabridge + yabridgectl | `patrickl/yabridge-stable` | `yabridge`, `yabridgectl` |
| sc3-plugins | `ycollet/linuxmao` | `supercollider-sc3-plugins` |
| brutefir | `ycollet/linuxmao` | `brutefir` |
| patchmatrix | `ycollet/linuxmao` | `patchmatrix` |

**Note**: `ycollet/linuxmao` (Audinux) covers brutefir, patchmatrix, sc3-plugins —
one COPR enable, three installs.

**Pattern** (from existing code):
```yaml
copr_<name>:
  cmd.run:
    - name: dnf copr enable -y <repo>
    - unless: test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:<owner>:<repo>.repo

install_<name>:
  cmd.run:
    - name: rpm-ostree install -y <packages>
    - require:
      - cmd: copr_<name>
    - unless: rpm-ostree status | grep -q <package>
```

---

## Phase 3: Flatpak (3 packages)

Add to the Flatpak section in `system_description.sls`, following existing pattern.

| Package | Flatpak ID |
|---------|------------|
| jamesdsp | `me.timschneeberger.jdsp4linux` |
| protonplus | `com.vysp3r.ProtonPlus` |
| opensoundmeter | N/A — use AppImage instead (see Phase 5) |

**Pattern**:
```yaml
install_flatpak_<name>:
  cmd.run:
    - name: flatpak install -y flathub <flatpak-id>
    - runas: neg
    - unless: flatpak info <flatpak-id> &>/dev/null
```

---

## Phase 4: GitHub Binary Downloads (10 packages)

Add to the binary install section in `system_description.sls`, following the
existing `install_sops`/`install_xdg_ninja` pattern.

| Package | URL Pattern | Binary Name |
|---------|-------------|-------------|
| xray | `https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip` | `xray` (extract from zip) |
| sing-box | `https://github.com/SagerNet/sing-box/releases/download/v1.12.17/sing-box-1.12.17-linux-amd64.tar.gz` | `sing-box` (extract from tar.gz) |
| tdl | `https://github.com/iyear/tdl/releases/latest/download/tdl_Linux_64bit.tar.gz` | `tdl` (extract from tar.gz) |
| throne | `https://github.com/nicedayzhu/sing-box-geoip/...` | Check actual releases |
| camilladsp | `https://github.com/HEnquist/camilladsp/releases/latest/download/camilladsp-linux-amd64.tar.gz` | `camilladsp` |
| opencode | `https://github.com/opencode-ai/opencode/releases/latest/download/opencode_linux_amd64.tar.gz` | `opencode` |
| adguardian | `https://github.com/Lissy93/AdGuardian-Term/releases/latest/download/adguardian-linux` | `adguardian` |
| realesrgan-ncnn-vulkan | `https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan/releases/.../realesrgan-ncnn-vulkan-...-ubuntu.zip` | `realesrgan-ncnn-vulkan` |
| essentia-extractor | `https://github.com/MTG/essentia/releases` | `essentia_streaming_extractor_music` |
| roomeqwizard | `https://www.roomeqwizard.com/` (Java installer) | Special: needs JRE |

**Pattern** (simple curl):
```yaml
install_<name>:
  cmd.run:
    - name: curl -sL <url> -o ~/.local/bin/<name> && chmod +x ~/.local/bin/<name>
    - runas: neg
    - creates: /var/home/neg/.local/bin/<name>
```

**Pattern** (tar.gz extraction):
```yaml
install_<name>:
  cmd.run:
    - name: >
        cd /tmp &&
        curl -sL <url> -o <name>.tar.gz &&
        tar xzf <name>.tar.gz &&
        cp <name>/<binary> ~/.local/bin/<name> &&
        chmod +x ~/.local/bin/<name> &&
        rm -rf /tmp/<name>*
    - runas: neg
    - creates: /var/home/neg/.local/bin/<name>
```

**Note**: For xray (zip), use `unzip` instead of `tar`. For versioned URLs,
pin exact versions (check latest at install time).

---

## Phase 5: pip install --user (4 packages)

Add pip installs to `system_description.sls` following the `install_httpstat` pattern.

| Package | pip Package | Binary Name |
|---------|-------------|-------------|
| scdl | `scdl` | `scdl` |
| dr14_tmeter | `DR14-T.meter` | `dr14_tmeter` |
| pzip | `pzip` | `pzip` |
| essentia (Python bindings) | `essentia` | N/A (library, not CLI) |

**Pattern**:
```yaml
install_<name>:
  cmd.run:
    - name: pip install --user <package>
    - runas: neg
    - creates: /var/home/neg/.local/bin/<binary>
```

**Note**: `essentia` Python bindings are a library, not a CLI tool. The CLI
extractor is covered in Phase 4 (static binary). Skip `essentia` pip install
unless the Python API is actually needed.

---

## Phase 6: cargo install (3 packages)

Add cargo installs to `system_description.sls`.

| Package | Crate | Binary Name |
|---------|-------|-------------|
| handlr-regex | `handlr-regex` | `handlr` |
| asciinema-agg | `agg` (from git) | `agg` |
| tailray | `tailray` | `tailray` |

**Pattern**:
```yaml
install_<name>:
  cmd.run:
    - name: cargo install <crate>
    - runas: neg
    - creates: /var/home/neg/.cargo/bin/<binary>
```

**Note**: Requires `cargo` to be available. For `agg`, use
`cargo install --git https://github.com/asciinema/agg` since it may not be on
crates.io.

---

## Phase 7: Direct Script / File Installs (6 packages)

Simple copy/download of scripts or files.

| Package | Method | Target |
|---------|--------|--------|
| mpvc | Clone + copy shell script | `~/.local/bin/mpvc` |
| rofi-systemd | Clone + copy shell script | `~/.local/bin/rofi-systemd` |
| dool | Clone + `make install` (or copy) | `~/.local/bin/dool` |
| qmk-udev-rules | Download udev rules file | `/etc/udev/rules.d/50-qmk.rules` |
| oldschool-pc-font-pack | Download + extract to fonts dir | `~/.local/share/fonts/oldschool-pc/` |
| matugen-themes | Clone template files | `~/.config/matugen/templates/` |

**Pattern** (shell script):
```yaml
install_<name>:
  cmd.run:
    - name: curl -sL https://raw.githubusercontent.com/<owner>/<repo>/master/<script> -o ~/.local/bin/<name> && chmod +x ~/.local/bin/<name>
    - runas: neg
    - creates: /var/home/neg/.local/bin/<name>
```

**Pattern** (udev rules — requires root):
```yaml
install_qmk_udev_rules:
  cmd.run:
    - name: curl -sL https://raw.githubusercontent.com/qmk/qmk_firmware/master/util/udev/50-qmk.rules -o /etc/udev/rules.d/50-qmk.rules && udevadm control --reload-rules
    - creates: /etc/udev/rules.d/50-qmk.rules
```

**Pattern** (fonts):
```yaml
install_oldschool_pc_fonts:
  cmd.run:
    - name: >
        mkdir -p ~/.local/share/fonts/oldschool-pc &&
        cd /tmp &&
        curl -sL https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip -o fonts.zip &&
        unzip -o fonts.zip -d oldschool-fonts &&
        cp oldschool-fonts/**/*.ttf ~/.local/share/fonts/oldschool-pc/ &&
        fc-cache -f ~/.local/share/fonts/oldschool-pc/ &&
        rm -rf /tmp/fonts.zip /tmp/oldschool-fonts
    - runas: neg
    - creates: /var/home/neg/.local/share/fonts/oldschool-pc
```

---

## Phase 8: Special Cases (5 packages)

### hy3 — Hyprland Plugin
Install via `hyprpm` (Hyprland's plugin manager):
```yaml
install_hy3:
  cmd.run:
    - name: hyprpm add https://github.com/outfoxxed/hy3 && hyprpm enable hy3
    - runas: neg
    - unless: hyprpm list | grep -q hy3
```
**Note**: Must match exact Hyprland version. May break on updates.

### winapps — Windows Apps in KVM
Complex setup requiring a Windows VM + FreeRDP. Not suitable for automated Salt state.
**Action**: Document in `nix-only-utilities.md` as "manual setup required" and skip
automated installation. User sets up manually when needed.

### droidcam — Phone as Webcam
Requires kernel module (DKMS) which is problematic on Fedora Atomic.
**Action**: Skip automated install. Note in inventory that `v4l2loopback` from
RPMFusion + scrcpy may be a better alternative on Atomic.

### newsraft — RSS Reader
Build from source (C + ncurses). Good candidate for custom RPM build.
**Action**: Create `build/specs/newsraft.spec` and add to `build/build-rpm.sh`
and `states/build_rpms.sls`.

### roomeqwizard — Acoustic Measurement
Java application with proprietary installer.
**Action**: Download jar/installer to `~/.local/opt/` and create wrapper script
in `~/.local/bin/`.

---

## Phase 9: Inventory Cleanup

After all phases complete:
1. Remove all newly-installed items from `nixos-packages-inventory.md`
2. Update `nix-only-utilities.md` to reflect final status
3. Commit all changes

---

## Execution Order

1. **Phase 0** — Remove skipped items from inventory (quick edit)
2. **Phase 1** — Fedora RPMs (add 3 packages to system_description.sls)
3. **Phase 2** — COPR repos (add 4 COPR enables + 8 package installs)
4. **Phase 3** — Flatpak (add 2 Flatpak installs)
5. **Phase 4** — GitHub binaries (add 8-10 binary download states)
6. **Phase 5** — pip installs (add 3 pip install states)
7. **Phase 6** — cargo installs (add 3 cargo install states)
8. **Phase 7** — Scripts/files (add 6 direct install states)
9. **Phase 8** — Special cases (hy3 via hyprpm, newsraft RPM, roomeqwizard)
10. **Phase 9** — Final inventory cleanup + commit

**Estimated commits**: 1 per phase (9-10 commits total)

---

## Version Pins (to verify at execution time)

| Package | Version to Check |
|---------|-----------------|
| xray | v26.x (latest from GitHub) |
| sing-box | v1.12.x (latest stable) |
| tdl | v0.20.x |
| camilladsp | v3.x |
| opencode | v0.0.55+ |
| adguardian | v1.6.0 |
| realesrgan-ncnn-vulkan | v0.2.0 |
| espanso | v2.2.x (COPR version) |
| himalaya | latest COPR version |
| newsraft | latest from Codeberg |

---

## Files Modified

| File | Changes |
|------|---------|
| `states/system_description.sls` | Add RPM packages, COPR states, Flatpak installs, binary installs, pip/cargo installs, script installs |
| `docs/nixos-packages-inventory.md` | Remove completed items |
| `docs/nix-only-utilities.md` | Update statuses |
| `build/specs/newsraft.spec` | New spec file (Phase 8) |
| `build/build-rpm.sh` | Add newsraft build section (Phase 8) |
| `states/build_rpms.sls` | Add newsraft entry (Phase 8) |
