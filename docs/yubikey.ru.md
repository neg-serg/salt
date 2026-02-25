# Руководство по сбросу Yubikey

Полный сброс всех приложений Yubikey. Используется при:
- Переносе GPG ключей на новый Yubikey
- Полной переинициализации ключа
- Устранении проблем с заблокированным PIN

## Порядок действий

1. Перезагрузить машину (чтобы отсоединить все сессии gpg-agent)
2. Вставить Yubikey
3. Выполнить сброс:

```bash
# Проверить что YubiKey виден
ykman info

# Сброс OpenPGP (GPG ключи)
ykman openpgp reset

# Сброс FIDO2 (WebAuthn/U2F регистрации)
ykman fido reset

# Сброс PIV (сертификаты)
ykman piv reset

# Сброс OATH (TOTP/HOTP токены)
ykman oath reset

# Сброс OTP слотов (если использовались)
ykman otp delete 1
ykman otp delete 2

# Проверить что всё чисто
ykman info
```

Каждая команда попросит подтверждение (y/N).

## После сброса

Перенести GPG ключ на Yubikey:

```bash
gpg --edit-key <KEY-ID>
> keytocard
> save

# Проверить
gpg --card-status
```

Затем пересоздать секреты gopass — см. `gopass-setup.ru.md`.
