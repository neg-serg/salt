%define debug_package %{nil}
%define username greetd

Name:           greetd
Version:        0.10.3
Release:        1%{?dist}
Summary:        Minimal and flexible login manager daemon
License:        GPL-3.0-only
URL:            https://git.sr.ht/~kennylevinsen/greetd
Source0:        %{name}-%{version}.tar.gz
Source1:        greetd.pam
Source2:        greetd-greeter.pam
Source3:        greetd.sysusers
Source4:        greetd.tmpfiles
Source5:        greetd.fc

BuildRequires:  rust, cargo, git, scdoc, pam-devel
BuildRequires:  selinux-policy-devel
BuildRequires:  systemd, systemd-devel, systemd-rpm-macros

%description
greetd is a minimal and flexible login manager daemon that makes no assumptions
about what you want to launch.

%package selinux
Summary:        SELinux policy for greetd
BuildArch:      noarch
Requires:       selinux-policy-targeted
Requires:       %{name} = %{version}-%{release}
%{?selinux_requires}

%description selinux
SELinux policy module for greetd login manager daemon.

%prep
%setup -q -n greetd-%{version}

%build
cargo build --release -p greetd -p agreety

# Man pages
for f in man/*.scd; do
    scdoc < "$f" > "${f%.scd}"
done

# SELinux policy
mkdir selinux
cp %{SOURCE5} selinux/greetd.fc
cat > selinux/greetd.te <<'EOF'
policy_module(greetd,1.0)
EOF
make -C selinux -f /usr/share/selinux/devel/Makefile greetd.pp
bzip2 selinux/greetd.pp

%install
# Binaries
mkdir -p %{buildroot}%{_bindir}
install -m 0755 target/release/greetd %{buildroot}%{_bindir}/greetd
install -m 0755 target/release/agreety %{buildroot}%{_bindir}/agreety

# Systemd service
mkdir -p %{buildroot}%{_unitdir}
install -m 0644 greetd.service %{buildroot}%{_unitdir}/greetd.service

# PAM configs
mkdir -p %{buildroot}%{_sysconfdir}/pam.d
install -m 0644 %{SOURCE1} %{buildroot}%{_sysconfdir}/pam.d/greetd
install -m 0644 %{SOURCE2} %{buildroot}%{_sysconfdir}/pam.d/greetd-greeter

# Default config
mkdir -p %{buildroot}%{_sysconfdir}/greetd
cat > %{buildroot}%{_sysconfdir}/greetd/config.toml <<'CONF'
[terminal]
vt = 1

[default_session]
command = "agreety --cmd /bin/sh"
user = "greetd"
CONF
chmod 0644 %{buildroot}%{_sysconfdir}/greetd/config.toml

# sysusers and tmpfiles
mkdir -p %{buildroot}%{_sysusersdir}
install -m 0644 %{SOURCE3} %{buildroot}%{_sysusersdir}/greetd.conf
mkdir -p %{buildroot}%{_tmpfilesdir}
install -m 0644 %{SOURCE4} %{buildroot}%{_tmpfilesdir}/greetd.conf

# Man pages
mkdir -p %{buildroot}%{_mandir}/man1
mkdir -p %{buildroot}%{_mandir}/man5
mkdir -p %{buildroot}%{_mandir}/man7
install -m 0644 man/agreety-1 %{buildroot}%{_mandir}/man1/agreety.1
install -m 0644 man/greetd-1 %{buildroot}%{_mandir}/man1/greetd.1
install -m 0644 man/greetd-5 %{buildroot}%{_mandir}/man5/greetd.5
install -m 0644 man/greetd-ipc-7 %{buildroot}%{_mandir}/man7/greetd-ipc.7

# Home directory for greetd user
mkdir -p %{buildroot}%{_sharedstatedir}/greetd

# SELinux policy
mkdir -p %{buildroot}%{_datadir}/selinux/packages
install -m 0644 selinux/greetd.pp.bz2 %{buildroot}%{_datadir}/selinux/packages/greetd.pp.bz2

%pre
%sysusers_create_compat %{SOURCE3}

%post
%systemd_post greetd.service

%preun
%systemd_preun greetd.service

%postun
%systemd_postun_with_restart greetd.service

%post selinux
%selinux_modules_install %{_datadir}/selinux/packages/greetd.pp.bz2
%selinux_relabel_post

%postun selinux
if [ $1 -eq 0 ]; then
    %selinux_modules_uninstall greetd
    %selinux_relabel_post
fi

%files
%{_bindir}/greetd
%{_bindir}/agreety
%{_unitdir}/greetd.service
%config(noreplace) %{_sysconfdir}/pam.d/greetd
%config(noreplace) %{_sysconfdir}/pam.d/greetd-greeter
%dir %{_sysconfdir}/greetd
%config(noreplace) %{_sysconfdir}/greetd/config.toml
%{_sysusersdir}/greetd.conf
%{_tmpfilesdir}/greetd.conf
%{_mandir}/man1/agreety.1*
%{_mandir}/man1/greetd.1*
%{_mandir}/man5/greetd.5*
%{_mandir}/man7/greetd-ipc.7*
%dir %attr(0750,%{username},%{username}) %{_sharedstatedir}/greetd

%files selinux
%{_datadir}/selinux/packages/greetd.pp.bz2

%changelog
* Thu Feb 13 2025 Negative Serg <negative@serg.ru> - 0.10.3-1
- Initial package build
