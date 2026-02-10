# NixOS Package Inventory — Remaining Items

Packages from `~/src/nixos-config/` **not yet migrated** to the Fedora Atomic workstation.
Already-migrated items have been removed. See [nix-only-utilities.md](nix-only-utilities.md)
for reference on items that required special effort.

---

## Still Pending

| Package | Category | Status |
|---------|----------|--------|
| throne (opt) | VPN proxy | URL unclear; deferred |
| overskride (opt) | Bluetooth | Needs Flatpak or COPR; deferred |
| droidcam | Hardware | Skip on Atomic (v4l2loopback DKMS problematic); use scrcpy + v4l2loopback from RPMFusion |
| opensoundmeter (opt) | Audio | AppImage available; not yet automated |
| unflac | Audio | Go project; needs custom RPM or binary build |
| matugen-themes | Theming | Check if templates are bundled with matugen binary |

## Not Applicable on Fedora

| Package | Reason |
|---------|--------|
| sk (two_percent) | Custom NixOS tool; not available |
| neg.tws (opt) | Interactive Brokers TWS; NixOS-specific packaging |
| winapps | Windows apps in KVM; manual setup required |

---

_Last bulk update: all 9 phases of `remaining-packages-plan.md` executed._
_~40 packages added to `states/system_description.sls` across Fedora RPM, COPR, Flatpak,_
_GitHub binary, pip, cargo, script install, and custom RPM categories._
