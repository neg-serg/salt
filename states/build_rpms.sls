# Salt state for building custom RPMs
# Packages are built in parallel using ephemeral podman containers
# Concurrency is limited to max_parallel using a FIFO-based semaphore

{% set max_parallel = 4 %}
{% set rpms_dir = '/var/home/neg/src/salt/rpms' %}
{% set build_dir = '/var/home/neg/src/salt/build' %}
{% set base_image = 'registry.fedoraproject.org/fedora-toolbox:43' %}

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
    {'name': 'jujutsu',           'version': '0.38.0'},
    {'name': 'kmon',              'version': '1.7.1'},
    {'name': 'lutgen',            'version': '0.12.1'},
    {'name': 'massren',           'version': '1.5.6'},
    {'name': 'neg-pretty-printer','version': '0.1.0',   'arch': 'noarch',
     'extra_volumes': '-v /var/home/neg/src/salt/build/pretty-printer:/build/pretty-printer:z'},
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
    {'name': 'bucklespring',      'version': '1.5.1'},
    {'name': 'taoup',             'version': '1.1.23',  'arch': 'noarch'},
    {'name': 'xh',                'version': '0.25.3'},
    {'name': 'curlie',            'version': '1.8.2'},
    {'name': 'doggo',             'version': '1.1.2'},
    {'name': 'wallust',           'version': '3.3.0'},
    {'name': 'wl-clip-persist',   'version': '0.5.0'},
    {'name': 'quickshell',        'version': '0.2.1'},
    {'name': 'swayosd',           'version': '0.3.0'},
    {'name': 'xdg-desktop-portal-termfilechooser', 'version': '0.4.0'},
    {'name': 'newsraft',          'version': '0.26'},
    {'name': 'unflac',            'version': '1.4'},
    {'name': 'albumdetails',      'version': '0.1'},
    {'name': 'cmake-language-server', 'version': '0.1.11', 'arch': 'noarch'},
    {'name': 'nginx-language-server', 'version': '0.9.0'},
    {'name': 'systemd-language-server', 'version': '0.3.5'},
    {'name': 'croc',                  'version': '10.3.1'},
    {'name': 'faker',                 'version': '40.4.0',  'arch': 'noarch'},
    {'name': 'speedtest-go',            'version': '1.7.10'},
    {'name': 'greetd',                   'version': '0.10.3',
     'extra_volumes': '-v /var/home/neg/src/salt/build/greetd-files:/build/salt/greetd-files:z'},
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

{{ rpms_dir }}:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

# Build all standard packages in parallel (up to max_parallel concurrent containers)
build_rpms_parallel:
  cmd.run:
    - name: |
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
        IOSEVKA_RPM="{{ rpms_dir }}/{{ iosevka.rpm_name }}-{{ iosevka.version }}-{{ iosevka.release }}.fc43.{{ iosevka.arch }}.rpm"
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
        {%- set arch = pkg.get('arch', 'x86_64') %}
        {%- set release = pkg.get('release', '1') %}
        {%- set extra_vol = pkg.get('extra_volumes', '') %}
        {%- set rpm_file = pkg.name ~ '-' ~ pkg.version ~ '-' ~ release ~ '.fc43.' ~ arch ~ '.rpm' %}
        if [ ! -f "${RPMS_DIR}/{{ rpm_file }}" ]; then
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
    - shell: /bin/bash
    - runas: neg
    - timeout: 7200
    - unless: |
        for f in \
          "{{ rpms_dir }}/{{ iosevka.rpm_name }}-{{ iosevka.version }}-{{ iosevka.release }}.fc43.{{ iosevka.arch }}.rpm" \
        {%- for pkg in rpms %}
        {%- set arch = pkg.get('arch', 'x86_64') %}
        {%- set release = pkg.get('release', '1') %}
        {%- set rpm_file = pkg.name ~ '-' ~ pkg.version ~ '-' ~ release ~ '.fc43.' ~ arch ~ '.rpm' %}
          "{{ rpms_dir }}/{{ rpm_file }}" \
        {%- endfor %}
        ; do [ -f "$f" ] || exit 1; done
    - require:
      - file: {{ rpms_dir }}
