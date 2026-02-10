# NixOS Package Inventory — Remaining Items

Packages from `~/src/nixos-config/` **not yet migrated** to the Fedora Atomic workstation.
See [nix-only-utilities.md](nix-only-utilities.md) for the full resolution log.

---

## Still Pending

| Package | Category | Status |
|---------|----------|--------|
| droidcam | Hardware | Skip on Atomic (v4l2loopback DKMS problematic); use scrcpy instead |

## Not Applicable on Fedora

| Package | Reason |
|---------|--------|
| sk (two_percent) | Custom NixOS tool; not available |
| neg.tws (opt) | Interactive Brokers TWS; NixOS-specific packaging |
| winapps | Windows apps in KVM; manual setup required |

---

_All other items resolved. ~46 packages added to Salt states._
_Only droidcam remains blocked (kernel module on Atomic)._
