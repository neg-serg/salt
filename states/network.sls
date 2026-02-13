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
    - contents: |
        [Match]
        Name=br0

        [Link]
        RequiredForOnline=no

        [Network]
        Address=192.168.122.1/24
        DHCPServer=yes

        [DHCPServer]
        PoolOffset=50
        PoolSize=101
        EmitDNS=yes
        DNS=192.168.122.1
        EmitRouter=yes
        DefaultLeaseTimeSec=43200
        MaxLeaseTimeSec=86400

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
    - contents: |
        [Unit]
        Description=Xray VLESS/Reality proxy
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        ExecStart=/var/home/neg/.local/bin/xray run -config /etc/xray/config.json
        Restart=on-failure
        RestartSec=5
        LimitNOFILE=65535

        [Install]
        WantedBy=multi-user.target

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
    - contents: |
        [Unit]
        Description=Sing-box VLESS Reality (TUN, manual start)
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        RuntimeDirectory=sing-box-tun
        ExecStartPre=/usr/bin/sh -c 'ip rule del pref 100 2>/dev/null; ip rule del pref 200 2>/dev/null; ip route show table 200 default > /run/sing-box-tun/prev-default-route 2>/dev/null; ip route del default table 200 2>/dev/null; true'
        ExecStart=/var/home/neg/.local/bin/sing-box run -c /run/user/1000/secrets/vless-reality-singbox-tun.json
        ExecStartPost=/usr/bin/sh -c 'ip rule add pref 100 to 204.152.223.171 lookup main'
        ExecStartPost=/usr/bin/sh -c 'ip route replace default dev sb0 table 200'
        ExecStartPost=/usr/bin/sh -c 'ip rule add pref 200 lookup 200'
        ExecStartPost=/usr/bin/ip route flush cache
        ExecStartPost=/usr/bin/resolvectl dns sb0 1.1.1.1 1.0.0.1
        ExecStartPost=/usr/bin/resolvectl domain sb0 "~."
        ExecStopPost=/usr/bin/sh -c 'ip rule del pref 200 2>/dev/null; ip route del default dev sb0 table 200 2>/dev/null; if test -s /run/sing-box-tun/prev-default-route; then ip route replace table 200 $(cat /run/sing-box-tun/prev-default-route); fi; ip rule del pref 100 2>/dev/null; ip route flush cache; true'
        ExecStopPost=/usr/bin/resolvectl revert sb0
        Restart=on-failure
        CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
        AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE
        NoNewPrivileges=false

        # No [Install] — manual start only: systemctl start sing-box-tun

{{ daemon_reload('singbox', ['file: singbox_service']) }}
{% endif %}
