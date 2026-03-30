{% from '_imports.jinja' import host, home %}
{% from '_macros_service.jinja' import ensure_dir, service_with_unit %}
{% from '_macros_pkg.jinja' import paru_install, simple_service %}
{% set net = host.features.network %}

# --- VM Bridge: br0 for KVM/libvirt VMs ---
{% if net.vm_bridge %}
vm_bridge_netdev:
  file.managed:
    - name: /etc/systemd/network/10-br0.netdev
    - makedirs: True
    - mode: '0644'
    - contents: |
        [NetDev]
        Name=br0
        Kind=bridge

vm_bridge_network:
  file.managed:
    - name: /etc/systemd/network/10-br0.network
    - makedirs: True
    - mode: '0644'
    - source: salt://configs/br0.network

vm_bridge_firewall:
  cmd.run:
    - name: |
        firewall-cmd --permanent --zone=trusted --add-interface=br0
        firewall-cmd --permanent --zone=trusted --add-service=dhcp
        firewall-cmd --reload
    - shell: /bin/bash
    - onlyif: command -v firewall-cmd
    - onchanges:
      - file: vm_bridge_netdev
{% endif %}

# --- Xray: VLESS/Reality proxy service ---
{% if net.xray %}
{{ paru_install('xray', 'xray') }}

# One-time cleanup: remove old manually-installed binary
xray_legacy_cleanup:
  file.absent:
    - name: {{ home }}/.local/bin/xray
    - onlyif: test -f {{ home }}/.local/bin/xray

{{ ensure_dir('xray_config_dir', '/etc/xray', mode='0750', user='root') }}

# Not enabled by default — needs config.json with secrets from gopass
{{ service_with_unit('xray', 'salt://units/xray.service', enabled=False, requires=['cmd: install_xray']) }}
{% endif %}

# --- Sing-box: TUN proxy (manual start) ---
# Binary already installed by system_description.sls (install_singbox)
{% if net.singbox %}
{{ service_with_unit('sing-box-tun', 'salt://units/sing-box-tun.service', template='jinja', context={'home': host.home, 'uid': host.uid}, enabled=None) }}
{% endif %}

# --- Outline: Shadowsocks-based VPN client (AppImage) ---
{% if host.features.outline %}
{{ paru_install('outline-client-appimage', 'outline-client-appimage') }}
{% endif %}

# --- Tailscale: mesh VPN (client only, --accept-dns=false) ---
{% if net.tailscale %}
{{ simple_service('tailscale', 'tailscale', service='tailscaled') }}

# Unbound stub zone: forward *.ts.net to Tailscale's MagicDNS resolver
tailscale_dns_stub:
  file.managed:
    - name: /etc/unbound/unbound.conf.d/tailscale.conf
    - mode: '0644'
    - contents: |
        # Tailscale MagicDNS — forward tailnet hostnames to Tailscale's resolver
        stub-zone:
            name: "ts.net"
            stub-addr: 100.100.100.100
    - require:
      - cmd: install_tailscale

tailscale_restart_unbound:
  cmd.run:
    - name: unbound-control reload 2>/dev/null || systemctl restart unbound 2>/dev/null || true
    - onchanges:
      - file: tailscale_dns_stub
{% endif %}
