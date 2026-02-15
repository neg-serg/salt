# Salt state for building custom RPMs
# Packages are built in parallel using ephemeral podman containers
# Concurrency is limited to max_parallel using a FIFO-based semaphore

{% import_yaml 'build/versions.yaml' as versions %}
{% set max_parallel = 4 %}
{% set rpms_dir = '/mnt/one/pkg/cache/rpms' %}
{% set build_dir = '/home/neg/src/salt/build' %}
{% set base_image = 'registry.fedoraproject.org/fedora-toolbox:43' %}

{# Package names — version auto-derived from versions.yaml via versions[name] #}
{% set rpm_names = [
    'albumdetails', 'bandwhich', 'bucklespring', 'carapace', 'choose',
    'cmake-language-server', 'croc', 'ctop', 'curlie', 'dive', 'doggo',
    'duf', 'epr', 'erdtree', 'faker', 'fclones', 'gist',
    'git-filter-repo', 'greetd', 'grex', 'htmlq', 'jujutsu', 'kmon',
    'lutgen', 'massren', 'neg-pretty-printer', 'nerdctl', 'newsraft',
    'nginx-language-server', 'ouch', 'pipemixer', 'pup', 'quickshell',
    'raise', 'rapidgzip', 'richcolors', 'rustnet', 'scc', 'scour',
    'speedtest-go', 'swayosd', 'systemd-language-server', 'taplo',
    'taoup', 'unflac', 'viu', 'wallust', 'wl-clip-persist',
    'xdg-desktop-portal-termfilechooser', 'xh', 'xxh', 'zfxtop', 'zk',
] %}

{% set noarch = (
    'cmake-language-server', 'epr', 'faker', 'gist', 'git-filter-repo',
    'neg-pretty-printer', 'richcolors', 'scour', 'taoup', 'xxh',
) %}

{% set extra_vol = {
    'neg-pretty-printer': '-v /home/neg/src/salt/build/pretty-printer:/build/pretty-printer:z',
    'greetd': '-v /home/neg/src/salt/build/greetd-files:/build/salt/greetd-files:z',
} %}

{# Build package dicts from names + overrides #}
{% set rpms = [] %}
{% for name in rpm_names %}
{%   set pkg = {'name': name, 'version': versions[name]} %}
{%   if name in noarch %}{% do pkg.update({'arch': 'noarch'}) %}{% endif %}
{%   if name in extra_vol %}{% do pkg.update({'extra_volumes': extra_vol[name]}) %}{% endif %}
{%   do rpms.append(pkg) %}
{% endfor %}

{% set iosevka = {
    'name': 'iosevka',
    'rpm_name': 'iosevka-neg-fonts',
    'version': versions['iosevka'],
    'release': '2',
    'arch': 'noarch',
    'timeout': 7200,
    'extra_volumes': '-v /home/neg/src/salt/build/iosevka-neg.toml:/build/iosevka-neg.toml:z'
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

        # FIFO semaphore: limits concurrent podman containers to MAX_JOBS.
        # Alternative to GNU parallel/xargs for Bash-only implementation.
        #
        # Problem: Building 50+ packages in parallel OOMs the system (50 containers × ~2GB each).
        # Solution: Create a FIFO queue with MAX_JOBS "tokens". Each background job acquires
        #           a token before starting (read from FIFO), releases after completion (write back).
        #
        # How it works:
        # 1. mkfifo "$SEM" creates a named pipe (FIFO)
        # 2. exec 3<>"$SEM" opens it for both read/write on fd 3
        # 3. rm -f "$SEM" deletes the file (no cleanup needed, fd 3 keeps it alive)
        # 4. Loop fills the FIFO with MAX_JOBS dummy tokens (newlines)
        # 5. Each parallel job reads one token with: read -u 3 <token>  (blocks if empty)
        # 6. After completion, each job writes back: echo >&3         (unblocks waiting jobs)
        #
        # Result: Only MAX_JOBS containers run concurrently. Others wait for tokens.
        # This avoids OOM while keeping all cores busy.
        #
        # Exception: iosevka (2h build, special-cased below) starts outside the semaphore
        # on its own (third) container slot, separate from the main job pool.
        SEM=$(mktemp -u)
        mkfifo "$SEM"
        exec 3<>"$SEM"
        rm -f "$SEM"
        for ((i=0; i<MAX_JOBS; i++)); do echo >&3; done

        PIDS=()
        NAMES=()
        LAUNCHED=0
        SKIPPED=0

        # Iosevka: special-case 2h font build running on its own dedicated slot.
        # Reason: Takes ~2h, blocks a semaphore token the entire time, preventing other
        #         jobs from running. Instead, launch it immediately without acquiring a token.
        #         This uses a 3rd concurrent container (MAX_JOBS=2 for RPMs, +1 for iosevka).
        # Benefit: Iosevka and 2 RPM builds run in parallel, finishing in ~2h instead of ~4h.
        IOSEVKA_RPM="{{ rpms_dir }}/{{ rpm_filename(iosevka) }}"
        if [ ! -f "$IOSEVKA_RPM" ]; then
            (
                echo "[BUILD] iosevka (dedicated slot, parallel with other builds)"
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
            read -u 3  # Acquire token from semaphore (blocks if all MAX_JOBS tokens in use)
            (
                echo "[BUILD] {{ pkg.name }}"
                RC=0
                podman run --rm \
                    -v "${BUILD_DIR}:/build/salt:z" \
                    -v "${RPMS_DIR}:/build/rpms:z" \
                    {{ extra_vol }} \
                    "$IMG" bash /build/salt/build-rpm.sh "{{ pkg.name }}" || RC=$?
                echo >&3  # Release token back to semaphore (unblocks waiting jobs)
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
