# Salt state for building custom RPMs

/var/home/neg/src/salt/rpms:
  file.directory:
    - user: neg
    - group: neg
    - makedirs: True

build_duf_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh duf
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/duf-0.9.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_massren_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh massren
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/massren-1.5.6-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_raise_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh raise
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/raise-0.1.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_pipemixer_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh pipemixer
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/pipemixer-0.4.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_richcolors_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh richcolors
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/richcolors-0.1.0-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_neg_pretty_printer_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z -v /var/home/neg/src/salt/nixos-config/packages/pretty-printer:/build/pretty-printer:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh neg-pretty-printer
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/neg-pretty-printer-0.1.0-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_choose_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh choose
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/choose-1.3.7-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_ouch_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh ouch
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/ouch-0.6.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_htmlq_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh htmlq
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/htmlq-0.4.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_erdtree_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh erdtree
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/erdtree-3.1.2-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_viu_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh viu
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/viu-1.6.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_fclones_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh fclones
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/fclones-0.35.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_grex_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh grex
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/grex-1.4.6-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_kmon_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh kmon
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/kmon-1.7.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_jujutsu_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh jujutsu
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/jujutsu-0.38.0-1.fc43.x86_64.rpm
    - timeout: 3600
    - require:
      - file: /var/home/neg/src/salt/rpms

build_zfxtop_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh zfxtop
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/zfxtop-0.3.2-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_pup_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh pup
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/pup-0.4.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_scc_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh scc
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/scc-3.6.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_ctop_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh ctop
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/ctop-0.7.7-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_dive_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh dive
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/dive-0.13.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_zk_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh zk
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/zk-0.15.2-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_git_filter_repo_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh git-filter-repo
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/git-filter-repo-2.47.0-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_epr_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh epr
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/epr-2.4.15-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_lutgen_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh lutgen
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/lutgen-0.12.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_taplo_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh taplo
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/taplo-0.10.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_gist_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh gist
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/gist-6.0.0-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_xxh_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh xxh
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/xxh-0.8.14-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_nerdctl_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh nerdctl
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/nerdctl-2.2.1-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_rapidgzip_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh rapidgzip
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/rapidgzip-0.16.0-1.fc43.x86_64.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_scour_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh scour
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/scour-0.38.2-1.fc43.noarch.rpm
    - require:
      - file: /var/home/neg/src/salt/rpms

build_iosevka_rpm:
  cmd.run:
    - name: podman run --rm -v /var/home/neg/src/salt/salt:/build/salt:z -v /var/home/neg/src/salt/rpms:/build/rpms:z -v /var/home/neg/src/salt/iosevka-neg.toml:/build/iosevka-neg.toml:z registry.fedoraproject.org/fedora-toolbox:43 bash /build/salt/build-rpm.sh iosevka
    - runas: neg
    - creates: /var/home/neg/src/salt/rpms/iosevka-neg-fonts-34.1.0-2.fc43.noarch.rpm
    - timeout: 7200
    - output_loglevel: info
    - require:
      - file: /var/home/neg/src/salt/rpms
