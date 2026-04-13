# Windows 11 VM definition — NVMe disk bus (Windows has built-in drivers)
{% from '_imports.jinja' import user, home %}

# Deploy the libvirt XML template
win11_xml:
  file.managed:
    - name: /tmp/win11.xml
    - source: salt://configs/win11.xml
    - mode: '0644'

# Define (or redefine) the VM from the XML.
# virsh define is idempotent — updates an existing domain with the same name.
win11_defined:
  cmd.run:
    - name: virsh -c qemu:///system define /tmp/win11.xml
    - onchanges:
      - file: win11_xml
