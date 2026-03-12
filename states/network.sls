{% from '_imports.jinja' import host, home %}
{% from '_macros_service.jinja' import service_with_unit, ensure_dir %}
{% from '_macros_pkg.jinja' import paru_install %}
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
{{ paru_install('xray', 'xray-bin') }}

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
