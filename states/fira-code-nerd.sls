# Salt state to install Fira Code Nerd Font
{% set user = 'neg' %}
{% set home = '/var/home/' ~ user %}
{% set version = '3.3.0' %}

/var/home/neg/.local/share/fonts/FiraCodeNerd:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True

download_fira_code_nerd:
  cmd.run:
    - name: |
        curl -L -o /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v{{ version }}/FiraCode.zip
        unzip -o /tmp/FiraCode.zip -d {{ home }}/.local/share/fonts/FiraCodeNerd
        rm /tmp/FiraCode.zip
        fc-cache -f
    - user: {{ user }}
    - unless: "ls {{ home }}/.local/share/fonts/FiraCodeNerd/FiraCodeNerdFontMono-Regular.ttf"
    - require:
      - file: /var/home/neg/.local/share/fonts/FiraCodeNerd
