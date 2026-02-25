# Yubikey Reset Guide

Full reset of all Yubikey applications. Use when:
- Transferring GPG keys to a new Yubikey
- Performing a complete key reinitialization
- Recovering from a locked PIN

## Procedure

1. Reboot the machine (to disconnect all gpg-agent sessions)
2. Insert the Yubikey
3. Run the reset:

```bash
# Verify the YubiKey is detected
ykman info

# Reset OpenPGP (GPG keys)
ykman openpgp reset

# Reset FIDO2 (WebAuthn/U2F registrations)
ykman fido reset

# Reset PIV (certificates)
ykman piv reset

# Reset OATH (TOTP/HOTP tokens)
ykman oath reset

# Reset OTP slots (if used)
ykman otp delete 1
ykman otp delete 2

# Verify everything is clean
ykman info
```

Each command will prompt for confirmation (y/N).

## After reset

Transfer the GPG key to the Yubikey:

```bash
gpg --edit-key <KEY-ID>
> keytocard
> save

# Verify
gpg --card-status
```

Then re-provision gopass secrets — see `gopass-setup.md`.
