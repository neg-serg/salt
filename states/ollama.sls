# Ollama LLM server: systemd service, SELinux policies, model pulls
{% from '_macros.jinja' import selinux_policy %}

ollama_service_unit:
  file.managed:
    - name: /etc/systemd/system/ollama.service
    - contents: |
        [Unit]
        Description=Ollama LLM Server
        After=network-online.target

        [Service]
        ExecStart=/usr/bin/ollama serve
        User=neg
        Group=neg
        Restart=always
        RestartSec=3
        WorkingDirectory=/var/home/neg
        Environment="HOME=/var/home/neg"
        Environment="OLLAMA_HOST=127.0.0.1:11434"
        Environment="OLLAMA_MODELS=/var/mnt/one/ollama/models"

        [Install]
        WantedBy=default.target
    - user: root
    - group: root
    - mode: '0644'

ollama_models_dir:
  file.directory:
    - name: /var/mnt/one/ollama/models
    - user: neg
    - group: neg
    - makedirs: True
    - require:
      - mount: mount_one

ollama_selinux_context:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/mnt/one/ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/mnt/one/ollama(/.*)?"
        restorecon -Rv /var/mnt/one/ollama
    - unless: matchpathcon -V /var/mnt/one/ollama/models 2>&1 | grep -q verified
    - require:
      - file: ollama_models_dir

# ollama server (init_t) needs to read its key from ~/.ollama/ (user_home_t → var_lib_t)
# uses /var/home path per equivalency rule '/home /var/home'
ollama_selinux_homedir:
  cmd.run:
    - name: |
        semanage fcontext -a -t var_lib_t "/var/home/neg/\.ollama(/.*)?" 2>/dev/null || \
        semanage fcontext -m -t var_lib_t "/var/home/neg/\.ollama(/.*)?"
        restorecon -Rv /var/home/neg/.ollama
    - unless: ls -Z /var/home/neg/.ollama/id_ed25519 | grep -q var_lib_t

# ollama runs as init_t (no custom SELinux type) and needs outbound HTTPS for model pulls
{% call selinux_policy('ollama_selinux_network', 'ollama-network') %}
module ollama-network 1.0;
require {
    type init_t;
    type http_port_t;
    class tcp_socket name_connect;
}
allow init_t http_port_t:tcp_socket name_connect;
{% endcall %}

ollama_enable:
  cmd.run:
    - name: systemctl daemon-reload && systemctl enable ollama
    - onchanges:
      - file: ollama_service_unit
    - onlyif: command -v ollama
    - require:
      - cmd: ollama_selinux_context

ollama_start:
  cmd.run:
    - name: |
        systemctl daemon-reload
        systemctl restart ollama
        for i in $(seq 1 30); do
          curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && exit 0
          sleep 1
        done
        echo "ollama failed to start within 30s" >&2
        exit 1
    - unless: curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1
    - require:
      - cmd: ollama_enable
      - cmd: ollama_selinux_homedir

{% for model in ['deepseek-r1:8b', 'llama3.2:3b', 'qwen2.5-coder:7b'] %}
pull_{{ model | replace('.', '_') | replace(':', '_') | replace('-', '_') }}:
  cmd.run:
    - name: >-
        curl -sf --max-time 600
        -X POST http://127.0.0.1:11434/api/pull
        -d '{"name": "{{ model }}", "stream": false}'
    - unless: >-
        curl -sf http://127.0.0.1:11434/api/tags |
        grep -q '"{{ model }}"'
    - timeout: 600
    - require:
      - cmd: ollama_start
      - cmd: ollama_selinux_network
{% endfor %}

# --- openclaw (local AI assistant agent) ---
install_openclaw:
  cmd.run:
    - name: npm install -g openclaw
    - runas: neg
    - creates: /var/home/neg/.npm-global/bin/openclaw
