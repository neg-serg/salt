{% from '_imports.jinja' import host %}
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
