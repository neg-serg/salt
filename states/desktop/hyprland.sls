{% from '_imports.jinja' import user %}
{% from '_macros_desktop.jinja' import hyprpm_add, hyprpm_enable, hyprpm_update %}
{% from '_macros_service.jinja' import ensure_dir %}

# wl: installed via custom_pkgs (PKGBUILD → /usr/bin/)

# --- Pacman hook: rebuild hyprpm headers after hyprland package upgrade ---
{{ ensure_dir('pacman_hooks_dir_hyprpm', '/etc/pacman.d/hooks', mode='0755', user='root') }}

hyprpm_update_pacman_hook:
  file.managed:
    - name: /etc/pacman.d/hooks/hyprpm-update.hook
    - source: salt://configs/hyprpm-update.hook.j2
    - template: jinja
    - mode: '0644'
    - require:
      - file: pacman_hooks_dir_hyprpm

# --- Hyprland plugins via hyprpm ---
# hyprpm needs HYPRLAND_INSTANCE_SIGNATURE (detect from socket dir) and
# headers must match the running Hyprland version (hyprpm update rebuilds them).
# hyprpm writes state to /var/cache/hyprpm/<user>/; ensure user ownership so
# hyprpm doesn't need sudo (which fails without a TTY in Salt context).
{% set hyprpm_cache = '/var/cache/hyprpm/' ~ user %}

hyprpm_cache_dir:
  file.directory:
    - name: {{ hyprpm_cache }}
    - user: {{ user }}
    - group: {{ user }}
    - makedirs: True
    - recurse:
      - user
      - group

# Pre-create repo cache dirs so hyprpm doesn't call sudo mkdir (which fails
# without a TTY in Salt context).
{%- set _hyprpm_repos = {
  'hyprland_plugins': 'hyprland-plugins',
  'hyprglass':        'HyprGlass',
  'hyprtasking':      'hyprtasking',
  'darkwindow':       'Hypr-DarkWindow',
} %}
{% for id_suffix, dir_name in _hyprpm_repos.items() %}
hyprpm_repo_cache_{{ id_suffix }}:
  file.directory:
    - name: {{ hyprpm_cache }}/{{ dir_name }}
    - user: {{ user }}
    - group: {{ user }}
    - require:
      - file: hyprpm_cache_dir
{% endfor %}

{{ hyprpm_update('hyprpm_headers_update',
    check_plugins=['xtra-dispatchers', 'HyprGlass', 'hyprtasking', 'Hypr-DarkWindow'],
    require=['cmd: install_hyprland_desktop', 'file: hyprpm_cache_dir']) }}

{{ hyprpm_add('hyprpm_add_hyprland_plugins',
    'https://github.com/hyprwm/hyprland-plugins',
    'Repository hyprland-plugins',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_hyprland_plugins']) }}

{{ hyprpm_enable('hyprpm_enable_xtra_dispatchers',
    'xtra-dispatchers',
    require=['cmd: hyprpm_add_hyprland_plugins']) }}

{{ hyprpm_add('hyprpm_add_hyprglass',
    'https://github.com/hyprnux/hyprglass',
    'Repository HyprGlass',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_hyprglass']) }}

{{ hyprpm_enable('hyprpm_enable_hyprglass',
    'hyprglass',
    require=['cmd: hyprpm_add_hyprglass']) }}

{{ hyprpm_add('hyprpm_add_hyprtasking',
    'https://github.com/raybbian/hyprtasking',
    'Repository hyprtasking',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_hyprtasking']) }}

{{ hyprpm_enable('hyprpm_enable_hyprtasking',
    'hyprtasking',
    require=['cmd: hyprpm_add_hyprtasking']) }}

{{ hyprpm_add('hyprpm_add_darkwindow',
    'https://github.com/micha4w/Hypr-DarkWindow',
    'Repository Hypr-DarkWindow',
    require=['cmd: install_hyprland_desktop', 'cmd: hyprpm_headers_update', 'file: hyprpm_repo_cache_darkwindow']) }}

{{ hyprpm_enable('hyprpm_enable_darkwindow',
    'Hypr-DarkWindow',
    require=['cmd: hyprpm_add_darkwindow']) }}
