# gopass age Recovery

Short runbook for moving an `age`-backed `gopass` store to another machine.

## What you need

- the private git URL of the `gopass` store;
- the `age` identity file from `~/.config/gopass/age/identities`;
- the password for that identity.

Without the identity file and its password, the cloned store is not usable.

## Copy the identity

Transfer `~/.config/gopass/age/identities` to the new machine using a secure channel.
Keep it separate from the store backup.

On the new machine:

```bash
mkdir -p ~/.config/gopass/age
chmod 700 ~/.config/gopass ~/.config/gopass/age
cp identities ~/.config/gopass/age/identities
chmod 600 ~/.config/gopass/age/identities
```

## Clone and unlock the store

```bash
export GPG_TTY="$(tty)"
gopass clone <store-url>
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
gopass show -o email/gmail/address
```

If the final `gopass show` returns the expected value, the decrypt path is working.

## Minimal backup set

Keep these outside the workstation:

- a copy of `~/.config/gopass/age/identities`;
- the password for that identity;
- the git URL of the store;
- this recovery procedure.

## Failure modes

- `gopass ls` works but `gopass show` fails: the identity is present, but not unlocked.
- `gopass clone` works but decrypt fails: wrong `identities` file or wrong password.
- no `~/.config/gopass/age/identities`: copy the backup first, then retry unlock.

`gopass ls` alone is not a sufficient verification step. Always validate with
`gopass show -o <known-key>`.
