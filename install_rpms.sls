# Salt state for custom RPM installation

install_duf_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/duf-*.rpm
    - unless: "rpm-ostree status | grep 'duf-'"
    - runas: root

install_massren_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/massren-*.rpm
    - unless: "rpm-ostree status | grep 'massren-'"
    - runas: root

install_raise_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/raise-*.rpm
    - unless: "rpm-ostree status | grep 'raise-'"
    - runas: root

install_pipemixer_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/pipemixer-*.rpm
    - unless: "rpm-ostree status | grep 'pipemixer-'"
    - runas: root

install_richcolors_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/richcolors-*.rpm
    - unless: "rpm-ostree status | grep 'richcolors-'"
    - runas: root

install_neg_pretty_printer_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/neg-pretty-printer-*.rpm
    - unless: "rpm-ostree status | grep 'neg-pretty-printer-'"
    - runas: root

install_choose_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/choose-*.rpm
    - unless: "rpm-ostree status | grep 'choose-'"
    - runas: root

install_ouch_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/ouch-*.rpm
    - unless: "rpm-ostree status | grep 'ouch-'"
    - runas: root

install_htmlq_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/htmlq-*.rpm
    - unless: "rpm-ostree status | grep 'htmlq-'"
    - runas: root

install_erdtree_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/erdtree-*.rpm
    - unless: "rpm-ostree status | grep 'erdtree-'"
    - runas: root

install_viu_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/viu-*.rpm
    - unless: "rpm-ostree status | grep 'viu-'"
    - runas: root

install_fclones_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/fclones-*.rpm
    - unless: "rpm-ostree status | grep 'fclones-'"
    - runas: root

install_grex_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/grex-*.rpm
    - unless: "rpm-ostree status | grep 'grex-'"
    - runas: root

install_kmon_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/kmon-*.rpm
    - unless: "rpm-ostree status | grep 'kmon-'"
    - runas: root

install_jujutsu_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/jujutsu-*.rpm
    - unless: "rpm-ostree status | grep 'jujutsu-'"
    - runas: root

install_zfxtop_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/zfxtop-*.rpm
    - unless: "rpm-ostree status | grep 'zfxtop-'"
    - runas: root

install_pup_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/pup-*.rpm
    - unless: "rpm-ostree status | grep 'pup-'"
    - runas: root

install_scc_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/scc-*.rpm
    - unless: "rpm-ostree status | grep 'scc-'"
    - runas: root

install_ctop_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/ctop-*.rpm
    - unless: "rpm-ostree status | grep 'ctop-'"
    - runas: root

install_dive_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/dive-*.rpm
    - unless: "rpm-ostree status | grep 'dive-'"
    - runas: root

install_zk_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/zk-*.rpm
    - unless: "rpm-ostree status | grep 'zk-'"
    - runas: root

install_git_filter_repo_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/git-filter-repo-*.rpm
    - unless: "rpm-ostree status | grep 'git-filter-repo-'"
    - runas: root

install_epr_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/epr-*.rpm
    - unless: "rpm-ostree status | grep 'epr-'"
    - runas: root

install_lutgen_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/lutgen-*.rpm
    - unless: "rpm-ostree status | grep 'lutgen-'"
    - runas: root

install_taplo_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/taplo-*.rpm
    - unless: "rpm-ostree status | grep 'taplo-'"
    - runas: root

install_gist_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/gist-*.rpm
    - unless: "rpm-ostree status | grep 'gist-'"
    - runas: root

install_xxh_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/xxh-*.rpm
    - unless: "rpm-ostree status | grep 'xxh-'"
    - runas: root

install_nerdctl_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/nerdctl-*.rpm
    - unless: "rpm-ostree status | grep 'nerdctl-'"
    - runas: root

install_rapidgzip_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/rapidgzip-*.rpm
    - unless: "rpm-ostree status | grep 'rapidgzip-'"
    - runas: root

install_scour_rpm:
  cmd.run:
    - name: rpm-ostree install /var/home/neg/src/salt/rpms/scour-*.rpm
    - unless: "rpm-ostree status | grep 'scour-'"
    - runas: root
