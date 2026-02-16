{% from 'host_config.jinja' import host %}
{% from '_macros.jinja' import daemon_reload %}
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

xray_service:
  file.managed:
    - name: /etc/systemd/system/xray.service
    - mode: '0644'
    - source: salt://units/xray.service
    - template: jinja
    - context:
        home: {{ host.home }}

{{ daemon_reload('xray', ['file: xray_service']) }}

# Not enabled by default — needs config.json with secrets from gopass
xray_not_enabled:
  service.disabled:
    - name: xray
    - require:
      - file: xray_service
{% endif %}

# --- Sing-box: TUN proxy (manual start) ---
# Binary already installed by system_description.sls (install_singbox)
{% if net.singbox %}
singbox_service:
  file.managed:
    - name: /etc/systemd/system/sing-box-tun.service
    - mode: '0644'
    - source: salt://units/sing-box-tun.service
    - template: jinja
    - context:
        home: {{ host.home }}
        uid: {{ host.uid }}

{{ daemon_reload('singbox', ['file: singbox_service']) }}
{% endif %}
