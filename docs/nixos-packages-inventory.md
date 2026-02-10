# NixOS Package Inventory — Migration Complete

All packages from `~/src/nixos-config/` have been migrated to the Fedora Atomic workstation.
See [nix-only-utilities.md](nix-only-utilities.md) for the full resolution log.

---

## Not Applicable on Fedora

| Package | Reason |
|---------|--------|
| sk (two_percent) | Custom NixOS tool; not available |
| neg.tws (opt) | Interactive Brokers TWS; NixOS-specific packaging |
| winapps | Windows apps in KVM; manual setup required |

---

_Migration complete. ~47 packages added to Salt states._
