# Salt state for building custom RPMs
# Packages are built in parallel using ephemeral podman containers
# Concurrency is limited to max_parallel using a FIFO-based semaphore

{% import_yaml 'build/versions.yaml' as versions %}
{% set max_parallel = 4 %}
{% set rpms_dir = '/var/mnt/one/pkg/cache/rpms' %}
{% set build_dir = '/var/home/neg/src/salt/build' %}
{% set base_image = 'registry.fedoraproject.org/fedora-toolbox:43' %}

{% set rpms = [
    {'name': 'choose',            'version': versions['choose']},
    {'name': 'ctop',              'version': versions['ctop']},
    {'name': 'dive',              'version': versions['dive']},
    {'name': 'duf',               'version': versions['duf']},
    {'name': 'epr',               'version': versions['epr'],              'arch': 'noarch'},
    {'name': 'erdtree',           'version': versions['erdtree']},
    {'name': 'fclones',           'version': versions['fclones']},
    {'name': 'git-filter-repo',   'version': versions['git-filter-repo'],  'arch': 'noarch'},
    {'name': 'gist',              'version': versions['gist'],             'arch': 'noarch'},
    {'name': 'grex',              'version': versions['grex']},
    {'name': 'htmlq',             'version': versions['htmlq']},
    {'name': 'jujutsu',           'version': versions['jujutsu']},
    {'name': 'kmon',              'version': versions['kmon']},
    {'name': 'lutgen',            'version': versions['lutgen']},
    {'name': 'massren',           'version': versions['massren']},
    {'name': 'neg-pretty-printer','version': versions['neg-pretty-printer'], 'arch': 'noarch',
     'extra_volumes': '-v /var/home/neg/src/salt/build/pretty-printer:/build/pretty-printer:z'},
    {'name': 'nerdctl',           'version': versions['nerdctl']},
    {'name': 'ouch',              'version': versions['ouch']},
    {'name': 'pipemixer',         'version': versions['pipemixer']},
    {'name': 'pup',               'version': versions['pup']},
    {'name': 'raise',             'version': versions['raise']},
    {'name': 'rapidgzip',         'version': versions['rapidgzip']},
    {'name': 'richcolors',        'version': versions['richcolors'],       'arch': 'noarch'},
    {'name': 'scc',               'version': versions['scc']},
    {'name': 'scour',             'version': versions['scour'],            'arch': 'noarch'},
    {'name': 'taplo',             'version': versions['taplo']},
    {'name': 'viu',               'version': versions['viu']},
    {'name': 'xxh',               'version': versions['xxh'],              'arch': 'noarch'},
    {'name': 'zfxtop',            'version': versions['zfxtop']},
    {'name': 'zk',                'version': versions['zk']},
    {'name': 'bandwhich',         'version': versions['bandwhich']},
    {'name': 'bucklespring',      'version': versions['bucklespring']},
    {'name': 'taoup',             'version': versions['taoup'],            'arch': 'noarch'},
    {'name': 'xh',                'version': versions['xh']},
    {'name': 'curlie',            'version': versions['curlie']},
    {'name': 'doggo',             'version': versions['doggo']},
    {'name': 'wallust',           'version': versions['wallust']},
    {'name': 'wl-clip-persist',   'version': versions['wl-clip-persist']},
    {'name': 'quickshell',        'version': versions['quickshell']},
    {'name': 'swayosd',           'version': versions['swayosd']},
    {'name': 'xdg-desktop-portal-termfilechooser', 'version': versions['xdg-desktop-portal-termfilechooser']},
    {'name': 'newsraft',          'version': versions['newsraft']},
    {'name': 'unflac',            'version': versions['unflac']},
    {'name': 'albumdetails',      'version': versions['albumdetails']},
    {'name': 'cmake-language-server', 'version': versions['cmake-language-server'], 'arch': 'noarch'},
    {'name': 'nginx-language-server', 'version': versions['nginx-language-server']},
    {'name': 'systemd-language-server', 'version': versions['systemd-language-server']},
    {'name': 'croc',              'version': versions['croc']},
    {'name': 'faker',             'version': versions['faker'],            'arch': 'noarch'},
    {'name': 'speedtest-go',      'version': versions['speedtest-go']},
    {'name': 'greetd',            'version': versions['greetd'],
     'extra_volumes': '-v /var/home/neg/src/salt/build/greetd-files:/build/salt/greetd-files:z'},
    {'name': 'rustnet',           'version': versions['rustnet']},
    {'name': 'carapace',          'version': versions['carapace']},
] %}

{% set iosevka = {
    'name': 'iosevka',
    'rpm_name': 'iosevka-neg-fonts',
    'version': versions['iosevka'],
    'release': '2',
    'arch': 'noarch',
    'timeout': 7200,
    'extra_volumes': '-v /var/home/neg/src/salt/build/iosevka-neg.toml:/build/iosevka-neg.toml:z'
} %}

{# Compute RPM filename from package dict (avoids repeating the formula) #}
{%- macro rpm_filename(pkg) -%}
{{ pkg.get('rpm_name', pkg.name) }}-{{ pkg.version }}-{{ pkg.get('release', '1') }}.fc43.{{ pkg.get('arch', 'x86_64') }}.rpm
{%- endmacro -%}

# Render the parallel build script (Jinja expands package list at render time)
# This avoids Salt dumping the entire rendered script in the Name: field
build_rpms_script:
  file.managed:
    - name: /tmp/salt-build-rpms-parallel.sh
    - user: neg
    - group: neg
    - mode: '0755'
    - contents: |
        #!/bin/bash
        set -uo pipefail

        MAX_JOBS={{ max_parallel }}
        RPMS_DIR="{{ rpms_dir }}"
        BUILD_DIR="{{ build_dir }}"
        IMG="{{ base_image }}"

        # FIFO semaphore: limits concurrent podman containers to MAX_JOBS
        SEM=$(mktemp -u)
        mkfifo "$SEM"
        exec 3<>"$SEM"
        rm -f "$SEM"
        for ((i=0; i<MAX_JOBS; i++)); do echo >&3; done

        PIDS=()
        NAMES=()
        LAUNCHED=0
        SKIPPED=0

        # Iosevka: start in background outside semaphore (2h build, independent)
        IOSEVKA_RPM="{{ rpms_dir }}/{{ rpm_filename(iosevka) }}"
        if [ ! -f "$IOSEVKA_RPM" ]; then
            (
                echo "[BUILD] iosevka (background, no semaphore slot)"
                RC=0
                podman run --rm \
                    -v "${BUILD_DIR}:/build/salt:z" \
                    -v "${RPMS_DIR}:/build/rpms:z" \
                    {{ iosevka.extra_volumes }} \
                    "$IMG" bash /build/salt/build-rpm.sh {{ iosevka.name }} || RC=$?
                [ $RC -eq 0 ] && echo "[  OK ] iosevka" || echo "[ FAIL] iosevka" >&2
                exit $RC
            ) &
            PIDS+=($!)
            NAMES+=("iosevka")
            LAUNCHED=$((LAUNCHED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
        {%- for pkg in rpms %}
        {%- set extra_vol = pkg.get('extra_volumes', '') %}
        if [ ! -f "${RPMS_DIR}/{{ rpm_filename(pkg) }}" ]; then
            read -u 3
            (
                echo "[BUILD] {{ pkg.name }}"
                RC=0
                podman run --rm \
                    -v "${BUILD_DIR}:/build/salt:z" \
                    -v "${RPMS_DIR}:/build/rpms:z" \
                    {{ extra_vol }} \
                    "$IMG" bash /build/salt/build-rpm.sh "{{ pkg.name }}" || RC=$?
                echo >&3
                [ $RC -eq 0 ] && echo "[  OK ] {{ pkg.name }}" || echo "[ FAIL] {{ pkg.name }}" >&2
                exit $RC
            ) &
            PIDS+=($!)
            NAMES+=("{{ pkg.name }}")
            LAUNCHED=$((LAUNCHED + 1))
        else
            SKIPPED=$((SKIPPED + 1))
        fi
        {%- endfor %}

        # Collect results from all background jobs
        FAILURES=0
        for i in "${!PIDS[@]}"; do
            if ! wait "${PIDS[$i]}"; then
                echo "FAILED: ${NAMES[$i]}" >&2
                FAILURES=$((FAILURES + 1))
            fi
        done

        exec 3>&-
        echo "=== Parallel build: ${LAUNCHED} built, ${SKIPPED} skipped, ${FAILURES} failed ==="
        [ "$FAILURES" -eq 0 ]
    - require:
      - cmd: pkg_cache_selinux

# Execute the rendered build script
build_rpms_parallel:
  cmd.run:
    - name: /tmp/salt-build-rpms-parallel.sh
    - shell: /bin/bash
    - runas: neg
    - timeout: 7200
    - unless: |
        for f in \
          "{{ rpms_dir }}/{{ rpm_filename(iosevka) }}" \
        {%- for pkg in rpms %}
          "{{ rpms_dir }}/{{ rpm_filename(pkg) }}" \
        {%- endfor %}
        ; do [ -f "$f" ] || exit 1; done
    - require:
      - file: build_rpms_script
      - cmd: pkg_cache_selinux
