# Recovery gopass age

Короткий runbook для переноса `age`-backed `gopass` store на другой компьютер.

## Что нужно

- приватный git URL `gopass` store;
- файл `age` identity из `~/.config/gopass/age/identities`;
- пароль от этой identity.

Без файла identity и её пароля клонированный store бесполезен.

## Перенос identity

Передайте `~/.config/gopass/age/identities` на новый компьютер безопасным каналом.
Храните его отдельно от backup самого store.

На новой машине:

```bash
mkdir -p ~/.config/gopass/age
chmod 700 ~/.config/gopass ~/.config/gopass/age
cp identities ~/.config/gopass/age/identities
chmod 600 ~/.config/gopass/age/identities
```

## Клонирование и разблокировка store

```bash
export GPG_TTY="$(tty)"
gopass clone <store-url>
gopass config age.agent-enabled true
gopass age agent start
gopass age agent unlock
gopass show -o email/gmail/address
```

Если последняя `gopass show` возвращает ожидаемое значение, decrypt path работает.

## Минимальный backup set

Храните вне рабочей машины:

- копию `~/.config/gopass/age/identities`;
- пароль от этой identity;
- git URL store;
- эту recovery-инструкцию.

## Типовые сбои

- `gopass ls` работает, а `gopass show` падает: identity на месте, но не разблокирована.
- `gopass clone` проходит, а decrypt не работает: неправильный файл `identities` или неправильный пароль.
- нет `~/.config/gopass/age/identities`: сначала восстановите backup identity, потом повторите unlock.

Сам по себе `gopass ls` не является достаточной проверкой. Всегда подтверждайте
рабочий decrypt path через `gopass show -o <known-key>`.
