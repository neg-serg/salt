{% from '_imports.jinja' import host, user, home %}
{% from '_macros_service.jinja' import service_with_unit %}
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
        firewall-cmd --permanent --zone=trusted --add-interface=br0 2>/dev/null || true
        firewall-cmd --permanent --zone=trusted --add-service=dhcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    - onchanges:
      - file: vm_bridge_netdev
{% endif %}

# --- Xray: VLESS/Reality proxy service ---
# Binary already installed by system_description.sls (install_xray)
# This adds a systemd service for running xray as a daemon
{% if net.xray %}
xray_config_dir:
  file.directory:
    - name: /etc/xray
    - mode: '0750'
    - makedirs: True

# Not enabled by default — needs config.json with secrets from gopass
{{ service_with_unit('xray', 'salt://units/xray.service', template='jinja', context={'home': host.home}, enabled=False) }}
{% endif %}

# --- Sing-box: TUN proxy (manual start) ---
# Binary already installed by system_description.sls (install_singbox)
{% if net.singbox %}
{{ service_with_unit('sing-box-tun', 'salt://units/sing-box-tun.service', template='jinja', context={'home': host.home, 'uid': host.uid}, enabled=None) }}
{% endif %}
