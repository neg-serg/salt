  После перезагрузки вставьте YubiKey и выполните полный сброс всех приложений:

  # 1. Проверить что YubiKey виден
  ykman info

  # 2. Сброс OpenPGP (GPG ключи)
  ykman openpgp reset

  # 3. Сброс FIDO2 (WebAuthn/U2F регистрации)
  ykman fido reset

  # 4. Сброс PIV (сертификаты)
  ykman piv reset

  # 5. Сброс OATH (TOTP/HOTP токены)
  ykman oath reset

  # 6. Сброс OTP слотов (если использовались)
  ykman otp delete 1
  ykman otp delete 2

  # 7. Проверить что всё чисто
  ykman info

  Каждая команда попросит подтверждение (y/N). Хотите перезагрузиться сейчас?
