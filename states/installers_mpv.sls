# MPV scripts and plugins (split from installers.sls)
{% from '_imports.jinja' import user, home, retry_attempts, retry_interval, ver_dir %}
{% from '_macros_service.jinja' import ensure_dir %}
{% from '_macros_install.jinja' import http_file %}
{% from '_macros_install.jinja' import github_release_to %}
{% import_yaml 'data/mpv_scripts.yaml' as mpv %}
{% import_yaml 'data/versions.yaml' as ver %}

{% set mpv_scripts_dir = home ~ '/.config/mpv/scripts' %}

{{ ensure_dir('mpv_scripts_dir', mpv_scripts_dir) }}

{% for filename, url in mpv.raw.items() %}
{{ http_file('mpv_script_' ~ (filename | replace('.', '_') | replace('-', '_')), url, mpv_scripts_dir ~ '/' ~ filename, user=user, require=['file: mpv_scripts_dir']) }}
{% endfor %}

# cutter.lua writes time_pairs.txt to scripts/ by default; mpv tries to load it as a script
cutter_lua_output_path:
  file.replace:
    - name: {{ mpv_scripts_dir }}/cutter.lua
    - pattern: "output_file='~/.config/mpv/scripts/time_pairs.txt'"
    - repl: "output_file='~/.config/mpv/time_pairs.txt'"
    - require:
      - cmd: mpv_script_cutter_lua

{% for filename, opts in mpv.github_release.items() %}
{% set mpv_tag = ver.get(opts.repo.split('/')[1] | replace('-', '_'), '') %}
{{ github_release_to('mpv_script_' ~ (filename | replace('.', '_') | replace('-', '_')), filename, opts.repo, opts.asset, mpv_scripts_dir, tag=mpv_tag if mpv_tag else None, version=mpv_tag if mpv_tag else None, require='mpv_scripts_dir') }}
{% endfor %}

# mpris.so: v1.2+ is source-only; build with make (v1.1 binary was libavformat.so.58, system has .so.62)
mpv_script_mpris_so:
  cmd.run:
    - name: |
        set -eo pipefail
        _td=$(mktemp -d)
        trap 'rm -rf "$_td"' EXIT
        git clone --depth 1 --branch {{ ver.mpv_mpris }} https://github.com/hoyon/mpv-mpris "$_td"
        cd "$_td"
        make
        install -m 0644 mpris.so {{ mpv_scripts_dir }}/mpris.so
        mkdir -p {{ ver_dir }} && rm -f '{{ ver_dir }}/mpris.so' {{ ver_dir }}/mpris.so@* && ln -sf '{{ mpv_scripts_dir }}/mpris.so' '{{ ver_dir }}/mpris.so@{{ ver.mpv_mpris }}'
    - runas: {{ user }}
    - shell: /bin/bash
    - creates: {{ ver_dir }}/mpris.so@{{ ver.mpv_mpris }}
    - parallel: True
    - require:
      - file: mpv_scripts_dir
    - retry:
        attempts: {{ retry_attempts }}
        interval: {{ retry_interval }}

{% for name, opts in mpv.github_release_zip.items() %}
{% set _v = ver.get(name, '') %}
{{ github_release_to('mpv_plugin_' ~ name, name, opts.repo, opts.asset, opts.dest, format='zip', tag=_v if _v else None, version=_v if _v else None, creates=mpv_scripts_dir ~ '/' ~ name, require='mpv_scripts_dir') }}
{% endfor %}
