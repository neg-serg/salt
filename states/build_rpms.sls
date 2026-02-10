# Salt state for building custom RPMs
# Each package is built in an ephemeral podman container

{% set rpms = [
    {'name': 'choose',            'version': '1.3.7'},
    {'name': 'ctop',              'version': '0.7.7'},
    {'name': 'dive',              'version': '0.13.1'},
    {'name': 'duf',               'version': '0.9.1'},
    {'name': 'epr',               'version': '2.4.15',  'arch': 'noarch'},
    {'name': 'erdtree',           'version': '3.1.2'},
    {'name': 'fclones',           'version': '0.35.0'},
    {'name': 'git-filter-repo',   'version': '2.47.0',  'arch': 'noarch'},
    {'name': 'gist',              'version': '6.0.0',   'arch': 'noarch'},
    {'name': 'grex',              'version': '1.4.6'},
    {'name': 'htmlq',             'version': '0.4.0'},
    {'name': 'jujutsu',           'version': '0.38.0',  'timeout': 3600},
    {'name': 'kmon',              'version': '1.7.1'},
    {'name': 'lutgen',            'version': '0.12.1'},
    {'name': 'massren',           'version': '1.5.6'},
    {'name': 'neg-pretty-printer','version': '0.1.0',   'arch': 'noarch',
     'extra_volumes': '-v /var/home/neg/src/nixos-config/packages/pretty-printer:/build/pretty-printer:z'},
    {'name': 'nerdctl',           'version': '2.2.1'},
    {'name': 'ouch',              'version': '0.6.1'},
    {'name': 'pipemixer',         'version': '0.4.0'},
    {'name': 'pup',               'version': '0.4.0'},
    {'name': 'raise',             'version': '0.1.0'},
    {'name': 'rapidgzip',         'version': '0.16.0'},
    {'name': 'richcolors',        'version': '0.1.0',   'arch': 'noarch'},
    {'name': 'scc',               'version': '3.6.0'},
    {'name': 'scour',             'version': '0.38.2',  'arch': 'noarch'},
    {'name': 'taplo',             'version': '0.10.0'},
    {'name': 'viu',               'version': '1.6.1'},
    {'name': 'xxh',               'version': '0.8.14',  'arch': 'noarch'},
    {'name': 'zfxtop',            'version': '0.3.2'},
    {'name': 'zk',                'version': '0.15.2'},
    {'name': 'bandwhich',         'version': '0.23.1'},
    {'name': 'bucklespring',     'version': '1.5.1'},
    {'name': 'taoup',            'version': '1.1.23', 'arch': 'noarch'},
    {'name': 'xh',                'version': '0.25.3'},
    {'name': 'curlie',            'version': '1.8.2'},
    {'name': 'doggo',             'version': '1.1.2'},
    {'name': 'wallust',           'version': '3.3.0'},
    {'name': 'wl-clip-persist',   'version': '0.5.0'},
    {'name': 'quickshell',        'version': '0.2.1',  'timeout': 3600},
    {'name': 'swayosd',          'version': '0.3.0'},
    {'name': 'xdg-desktop-portal-termfilechooser', 'version': '0.4.0'}
] %}

{% set iosevka = {
    'name': 'iosevka',
    'rpm_name': 'iosevka-neg-fonts',
    'version': '34.1.0',
    'release': '2',
    'arch': 'noarch',
    'timeout': 7200,
    'extra_volumes': '-v /var/home/neg/src/salt/build/iosevka-neg.toml:/build/iosevka-neg.toml:z'
} %}

/var/home/neg/src/salt/rpms:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

{% for pkg in rpms %}
{% set arch = pkg.get('arch', 'x86_64') %}
{% set release = pkg.get('release', '1') %}
{% set extra_vol = pkg.get('extra_volumes', '') %}
{% set rpm_file = pkg.name ~ '-' ~ pkg.version ~ '-' ~ release ~ '.fc43.' ~ arch ~ '.rpm' %}
build_{{ pkg.name | replace('-', '_') }}_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/build:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z {{ extra_vol }} registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh {{ pkg.name }}
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/{{ rpm_file }}
{% if pkg.get('timeout') %}
    - timeout: {{ pkg.timeout }}
{% endif %}
    - require:
      - file: /var/home/neg/src/salt/rpms

{% endfor %}

# Iosevka font build (special: different RPM name, extra volume, long timeout)
build_iosevka_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/build:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z {{ iosevka.extra_volumes }} registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh {{ iosevka.name }}
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/{{ iosevka.rpm_name }}-{{ iosevka.version }}-{{ iosevka.release }}.fc43.{{ iosevka.arch }}.rpm
    - timeout: {{ iosevka.timeout }}
    - output_loglevel: info
    - require:
      - file: /var/home/neg/src/salt/rpms
