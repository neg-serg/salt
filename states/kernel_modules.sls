{% from 'host_config.jinja' import host %}
# Kernel module loading and blacklisting migrated from NixOS
# (modules/system/kernel/params.nix, hosts/telfir/hardware.nix)
#
# modules-load.d: loaded at boot by systemd-modules-load.service
# modprobe.d: prevents module autoloading (security hardening)

kernel_modules_load:
  file.managed:
    - name: /etc/modules-load.d/custom.conf
    - contents: |
        # KVM virtualization ({{ host.cpu_vendor }})
        {{ host.kvm_module }}
        # BBR TCP congestion control
        tcp_bbr
        # NT synchronization primitives (Wine/Proton)
        ntsync
{% for mod in host.extra_modules %}
        # Host-specific: {{ mod }}
        {{ mod }}
{% endfor %}

kernel_modules_blacklist:
  file.managed:
    - name: /etc/modprobe.d/blacklist-custom.conf
    - contents: |
{% if host.cpu_vendor == 'amd' %}
        # Watchdog (sp5100_tco causes spurious resets on AMD)
        blacklist sp5100_tco
{% endif %}

        # TPM (unused on this host, avoids tpmrm device wait)
        blacklist tpm
        blacklist tpm_crb
        blacklist tpm_tis
        blacklist tpm_tis_core

        # Legacy serial (no physical serial ports)
        blacklist 8250
        blacklist serial8250

        # Obscure/unused network protocols (attack surface reduction)
        blacklist ax25
        blacklist netrom
        blacklist rose
        blacklist dccp
        blacklist sctp
        blacklist rds
        blacklist tipc
        blacklist n-hdlc
        blacklist x25
        blacklist decnet
        blacklist econet
        blacklist af_802154
        blacklist ipx
        blacklist appletalk
        blacklist psnap
        blacklist p8023
        blacklist p8022
        blacklist can
        blacklist atm

        # Old/rarely-audited filesystems (attack surface reduction)
        blacklist adfs
        blacklist affs
        blacklist befs
        blacklist bfs
        blacklist cramfs
        blacklist efs
        blacklist erofs
        blacklist exofs
        blacklist freevxfs
        blacklist gfs2
        blacklist hfs
        blacklist hfsplus
        blacklist hpfs
        blacklist jffs2
        blacklist jfs
        blacklist ksmbd
        blacklist minix
        blacklist nilfs2
        blacklist omfs
        blacklist qnx4
        blacklist qnx6
        blacklist squashfs
        blacklist sysv
        blacklist ufs
        blacklist vivid
        blacklist udf

# Load modules that aren't already loaded (no reboot needed for most)
{% for mod in [host.kvm_module, 'tcp_bbr'] %}
load_{{ mod | replace('-', '_') }}:
  cmd.run:
    - name: modprobe {{ mod }}
    - unless: lsmod | grep -q '^{{ mod | replace('-', '_') }}'
    - require:
      - file: kernel_modules_load
{% endfor %}
