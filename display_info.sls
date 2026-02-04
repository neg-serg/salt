# ~/src/salt/display_info.sls
# A simple Salt state to demonstrate accessing system grains.

display_system_info:
  test.show_notification:
    - name: |
        System Information:
          OS: {{ grains.os }} {{ grains.osrelease }} ({{ grains.osfullname }})
          Kernel: {{ grains.kernelrelease }}
          CPU: {{ grains.cpu_model }} ({{ grains.num_cpus }} CPUs)
          Memory: {{ (grains.mem_total / 1024) | round(1) }} GB
          IP: {% if grains.ip4_interfaces.eno1 %}{{ grains.ip4_interfaces.eno1[0] }}{% else %}N/A{% endif %}
    - require:
        - sls: system_description # This state would typically be included to ensure grains are available
