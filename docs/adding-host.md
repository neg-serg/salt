# Adding a New Host

## Quick Start

1. Pick a hostname (we use [Morrowind city names](https://en.uesp.net/wiki/Morrowind:Places) by convention)
2. Add an entry to `hosts` dict in `states/host_config.jinja`
3. Only override what differs from `defaults` — everything else is inherited via recursive merge

## Minimal Example

A new desktop workstation with all defaults:

```jinja
'suran': {
    'display':        '2560x1440@144',
    'primary_output': 'DP-1',
    'hostname':       'suran',
},
```

This inherits: AMD CPU, no laptop mode, all default features (steam, mpd, ollama, etc.), standard mount paths, timezone, locale.

## Laptop Example

```jinja
'balmora': {
    'is_laptop':      True,
    'cpu_vendor':     'intel',
    'kvm_module':     'kvm_intel',
    'display':        '2560x1600@165',
    'primary_output': 'eDP-1',
    'hostname':       'balmora',
    'features': {
        'network': {
            'wifi': True,
        },
        'steam':    False,
        'ollama':   False,
    },
},
```

Key differences: Intel CPU changes `kvm_module`, WiFi enabled, heavy features disabled to save battery.

## Server Example

```jinja
'caldera': {
    'display':        '1920x1080@60',
    'primary_output': 'HDMI-A-1',
    'hostname':       'caldera',
    'features': {
        'monitoring': {
            'loki':     True,
            'promtail': True,
            'grafana':  True,
        },
        'dns': {
            'unbound':      True,
            'adguardhome':  True,
        },
        'services': {
            'samba':    True,
            'jellyfin': True,
            'duckdns':  True,
        },
        'steam':    False,
        'mpd':      False,
        'kanata':   False,
    },
},
```

Enables full monitoring stack, DNS, and media services. Disables desktop-oriented features.

## How the Merge Works

```
defaults  ←──  hosts['your_host']  ←──  derived fields
         recurse merge            post-merge update
```

- `salt['slsutil.merge'](defaults, host_config, strategy='recurse')` — deep-merges dicts, host values win
- Only keys you specify are overridden; nested dicts merge recursively (e.g. setting `'dns': {'unbound': True}` doesn't wipe `avahi`)
- After merge, derived fields are computed: `runtime_dir`, `pkg_list`, `project_dir`

## Hostname Aliases

If the machine starts with a different hostname (e.g. `cachyos` from a fresh install), add an alias:

```jinja
{% set aliases = {
    'cachyos': 'telfir',
    'archlinux': 'balmora',
} %}
```

The alias resolves before the merge, so the correct host config applies even before `hostname` is set by Salt.

## Available Feature Flags

| Path | Type | Default | Purpose |
|------|------|---------|---------|
| `features.monitoring.sysstat` | bool | True | System activity reports |
| `features.monitoring.vnstat` | bool | True | Network traffic monitoring |
| `features.monitoring.netdata` | bool | True | Real-time metrics dashboard |
| `features.monitoring.loki` | bool | False | Log aggregation |
| `features.monitoring.promtail` | bool | False | Log shipper for Loki |
| `features.monitoring.grafana` | bool | False | Metrics visualization |
| `features.fancontrol` | bool | False | Fan speed control |
| `features.kernel.variant` | str | 'lto' | Kernel variant |
| `features.dns.unbound` | bool | False | Local DNS resolver |
| `features.dns.adguardhome` | bool | False | DNS ad blocking |
| `features.dns.avahi` | bool | True | mDNS/DNS-SD |
| `features.services.samba` | bool | False | SMB file sharing |
| `features.services.jellyfin` | bool | False | Media server |
| `features.services.bitcoind` | bool | False | Bitcoin node |
| `features.services.duckdns` | bool | False | Dynamic DNS |
| `features.services.transmission` | bool | False | Torrent client |
| `features.network.vm_bridge` | bool | False | Libvirt bridge |
| `features.network.xray` | bool | False | Xray proxy |
| `features.network.singbox` | bool | False | sing-box proxy |
| `features.network.wifi` | bool | False | Wireless networking |
| `features.user_services.mail` | bool | True | Mail sync service |
| `features.user_services.vdirsyncer` | bool | True | CalDAV/CardDAV sync |
| `features.amnezia` | bool | True | AmneziaVPN |
| `features.steam` | bool | True | Steam + gaming stack |
| `features.mpd` | bool | True | Music Player Daemon |
| `features.ollama` | bool | True | Local LLM |
| `features.floorp` | bool | True | Floorp browser |
| `features.llama_embed` | bool | True | llama.cpp embedding server |
| `features.kanata` | bool | True | Keyboard remapping |

## Available Host Fields

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `user` | str | 'neg' | Primary user |
| `home` | str | `'/home/' + user` | Home directory |
| `uid` | int | 1000 | User ID |
| `mnt_zero` | str | '/mnt/zero' | First storage mount |
| `mnt_one` | str | '/mnt/one' | Second storage mount |
| `is_laptop` | bool | False | Laptop mode |
| `cursor_theme` | str | 'Alkano-aio' | Cursor theme name |
| `cursor_size` | int | 23 | Cursor size in px |
| `cpu_vendor` | str | 'amd' | CPU vendor (`amd` or `intel`) |
| `kvm_module` | str | 'kvm_amd' | KVM kernel module |
| `display` | str | '' | Resolution string (`WxH@Hz`) |
| `primary_output` | str | '' | Display output name |
| `greetd_vt` | int | 1 | Virtual terminal for greetd |
| `greetd_scale` | int | 1 | Login screen scale factor |
| `timezone` | str | 'Europe/Moscow' | System timezone |
| `locale` | str | 'en_US.UTF-8' | System locale |
| `floorp_profile` | str | '' | Floorp profile dir name |
| `hostname` | str | grains host | Desired hostname |
| `extra_kargs` | list | [] | Extra kernel boot args |
| `extra_modules` | list | [] | Extra kernel modules to load |

## Checklist

- [ ] Entry added to `hosts` dict in `host_config.jinja`
- [ ] `hostname` field matches the dict key
- [ ] `cpu_vendor` / `kvm_module` correct for hardware
- [ ] `display` and `primary_output` match actual display (check with `hyprctl monitors`)
- [ ] Feature flags reviewed — disable what you don't need
- [ ] Alias added if machine starts with different hostname
- [ ] Test with `salt-call --local state.show_top` on target machine
