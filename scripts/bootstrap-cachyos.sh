#!/usr/bin/env bash
# Bootstrap CachyOS (Zen4/5 optimized) rootfs via Podman + Arch container.
# Produces a rootfs with Limine bootloader and Btrfs snapshot support.
#
# Usage:
#   sudo ./scripts/bootstrap-cachyos.sh [TARGET_DIR]
#
# Default target: /var/mnt/one/cachyos-root
#
# After bootstrap, deploy to a Btrfs partition with the expected subvolume
# layout (see deploy-cachyos.sh or the "Next steps" output).
#
# Btrfs subvolume layout:
#   @           → /
#   @home       → /home
#   @cache      → /var/cache
#   @log        → /var/log
#   @snapshots  → /.snapshots

set -euo pipefail

TARGET="${1:-/var/mnt/one/cachyos-root}"
ARCH_IMAGE="docker.io/archlinux/archlinux:latest"

# CachyOS GPG key
CACHYOS_KEY="F3B607488DB35A47"

# Packages to install into the rootfs
PACKAGES=(
    # Base system
    base
    base-devel
    linux-cachyos-lts
    linux-cachyos-lts-headers
    linux-firmware

    # CachyOS infra
    cachyos-settings
    cachyos-keyring
    cachyos-mirrorlist
    cachyos-v3-mirrorlist

    # Bootloader (Limine + UEFI)
    limine
    efibootmgr

    # Btrfs + snapshots
    btrfs-progs
    snapper
    snap-pac

    # LVM (for /dev/main/sys)
    lvm2

    # XFS support (for /var/mnt/zero, /var/mnt/one)
    xfsprogs

    # Network
    networkmanager
    iwd
    dhcpcd
    openssh

    # AUR helper (available in CachyOS repos)
    paru

    # Core tools
    sudo
    vim
    git
    zsh
    curl
    wget
    htop
    man-db
    man-pages
    less
    which
    tree
    unzip
)

# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "error: must run as root (need mount inside container)" >&2
    exit 1
fi

if ! command -v podman &>/dev/null; then
    echo "error: podman not found" >&2
    exit 1
fi

if [[ -d "$TARGET/usr/bin" ]]; then
    echo "error: $TARGET/usr/bin already exists — looks like a previous bootstrap"
    echo "  remove it first:  sudo rm -rf $TARGET"
    exit 1
fi

mkdir -p "$TARGET"
echo "==> Target: $TARGET"

# -------------------------------------------------------------------
# Build the inner script that runs inside the Arch container
# -------------------------------------------------------------------

INNER_SCRIPT=$(cat <<'INNER'
#!/usr/bin/env bash
set -euo pipefail

TARGET=/mnt/target

echo "==> [container] Updating pacman DB and installing arch-install-scripts..."
pacman -Sy --noconfirm arch-install-scripts

# --- CachyOS repository setup (inside container's pacman) ---

echo "==> [container] Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinux

echo "==> [container] Importing CachyOS GPG key..."
pacman-key --recv-keys __CACHYOS_KEY__ --keyserver keyserver.ubuntu.com
pacman-key --lsign-key __CACHYOS_KEY__

echo "==> [container] Configuring CachyOS znver4 repositories..."

# Allow x86_64_v4 package architecture (znver4 packages are built as x86_64_v4)
sed -i 's/^Architecture.*=.*/Architecture = x86_64 x86_64_v4/' /etc/pacman.conf

# Mirrorlist files
cat > /etc/pacman.d/cachyos-v4-mirrorlist <<'EOF'
Server = https://cdn77.cachyos.org/repo/$arch_v4/$repo
Server = https://cdn.cachyos.org/repo/$arch_v4/$repo
Server = https://mirror.cachyos.org/repo/$arch_v4/$repo
Server = https://at.cachyos.org/repo/$arch_v4/$repo
Server = https://us.cachyos.org/repo/$arch_v4/$repo
EOF

cat > /etc/pacman.d/cachyos-mirrorlist <<'EOF'
Server = https://cdn77.cachyos.org/repo/$arch/$repo
Server = https://cdn.cachyos.org/repo/$arch/$repo
Server = https://mirror.cachyos.org/repo/$arch/$repo
Server = https://at.cachyos.org/repo/$arch/$repo
Server = https://us.cachyos.org/repo/$arch/$repo
EOF

# Insert CachyOS repos before [core] in pacman.conf
sed -i '/^\[core\]/i \
[cachyos-znver4]\
Include = /etc/pacman.d/cachyos-v4-mirrorlist\
SigLevel = Never\
\
[cachyos-core-znver4]\
Include = /etc/pacman.d/cachyos-v4-mirrorlist\
SigLevel = Never\
\
[cachyos-extra-znver4]\
Include = /etc/pacman.d/cachyos-v4-mirrorlist\
SigLevel = Never\
\
[cachyos]\
Include = /etc/pacman.d/cachyos-mirrorlist\
SigLevel = Never\
' /etc/pacman.conf

pacman -Sy

# --- Pacstrap ---

echo "==> [container] Running pacstrap..."
pacstrap "$TARGET" __PACKAGES__

# --- Copy mirrorlists and generate pacman.conf for target ---

echo "==> [container] Copying mirrorlists to target..."
cp /etc/pacman.d/cachyos-v4-mirrorlist "$TARGET/etc/pacman.d/"
cp /etc/pacman.d/cachyos-mirrorlist "$TARGET/etc/pacman.d/"

echo "==> [container] Generating target pacman.conf..."
# Generate from scratch — cachyos-settings may remove/replace the default pacman.conf
cat > "$TARGET/etc/pacman.conf" <<'PACCONF'
[options]
HoldPkg     = pacman glibc
Architecture = x86_64 x86_64_v4
Color
CheckSpace
VerbosePkgLists
ParallelDownloads = 5
SigLevel    = Required DatabaseOptional
LocalFileSigLevel = Optional

# CachyOS znver4 repositories
[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

# Arch repositories
[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
PACCONF

# --- Chroot configuration ---

echo "==> [container] Configuring target via arch-chroot..."
arch-chroot "$TARGET" bash -c '
set -euo pipefail

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc 2>/dev/null || true

# Locale — enable en_US; only add ru_RU if source files exist
if [[ -f /etc/locale.gen ]]; then
    sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
    if [[ -f /usr/share/i18n/locales/ru_RU ]]; then
        sed -i "s/^#ru_RU.UTF-8/ru_RU.UTF-8/" /etc/locale.gen
    fi
else
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    if [[ -f /usr/share/i18n/locales/ru_RU ]]; then
        echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
    fi
fi
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "cachyos" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   cachyos.localdomain cachyos
HOSTS

# Root password (change on first login)
echo "root:changeme" | chpasswd

# User
useradd -m -G wheel -s /bin/zsh neg
echo "neg:changeme" | chpasswd
# Uncomment existing wheel rule (must stay BEFORE @includedir so NOPASSWD drop-in wins)
sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

# Initialize pacman keyring properly inside target
pacman-key --init
pacman-key --populate archlinux
pacman-key --populate cachyos 2>/dev/null || {
    pacman-key --recv-keys __CACHYOS_KEY__ --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key __CACHYOS_KEY__
}

# vconsole.conf (silences mkinitcpio warning)
echo "KEYMAP=us" > /etc/vconsole.conf

# --- mkinitcpio: LVM hook + zstd compression ---
if [[ -f /etc/mkinitcpio.conf ]]; then
    # Add lvm2 hook before filesystems (required for LVM root)
    sed -i "s/block filesystems/block lvm2 filesystems/" /etc/mkinitcpio.conf
    sed -i "s/^#\?COMPRESSION=.*/COMPRESSION=\"zstd\"/" /etc/mkinitcpio.conf
    sed -i "s/^#\?COMPRESSION_OPTIONS=.*/COMPRESSION_OPTIONS=(-19 -T0)/" /etc/mkinitcpio.conf
else
    cat > /etc/mkinitcpio.conf <<MKINIT
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block lvm2 filesystems fsck)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-19 -T0)
MKINIT
fi

# Initramfs
mkinitcpio -P

# --- Limine bootloader config ---
mkdir -p /boot/EFI/BOOT
cat > /boot/limine.conf <<LIMINE
timeout: 5
default_entry: 1
interface_branding: CachyOS

/CachyOS
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=/dev/mapper/main-sys rootflags=subvol=@ rw quiet splash
    module_path: boot():/initramfs-linux-cachyos-lts.img

/CachyOS (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos-lts
    kernel_cmdline: root=/dev/mapper/main-sys rootflags=subvol=@ rw
    module_path: boot():/initramfs-linux-cachyos-lts-fallback.img
LIMINE

# Copy Limine EFI binary
if [[ -f /usr/share/limine/BOOTX64.EFI ]]; then
    cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
fi

# --- Snapper configuration for root subvolume ---
# Create snapper config for root (expects /.snapshots on @snapshots subvolume)
cat > /etc/snapper/configs/root <<SNAPPER_CFG
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""

# snapshot limits
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="3"
TIMELINE_LIMIT_YEARLY="0"

# cleanup
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="20"
NUMBER_LIMIT_IMPORTANT="10"

TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"

# snap-pac: pre/post snapshots on pacman transactions
NUMBER_CLEANUP="yes"
SNAPPER_CFG

# Register root config with snapper
if [[ -f /etc/conf.d/snapper ]]; then
    sed -i "s/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS=\"root\"/" /etc/conf.d/snapper
else
    mkdir -p /etc/conf.d
    echo "SNAPPER_CONFIGS=\"root\"" > /etc/conf.d/snapper
fi

# --- Btrfs mount options for fstab (template — adjust UUIDs during deploy) ---
mkdir -p /etc/deploy-notes
cat > /etc/deploy-notes/fstab-template <<FSTAB_TMPL
# Btrfs subvolume layout for CachyOS
# Replace LABEL=cachyos with UUID=<your-uuid> during deployment
#
# <device>        <mount>        <type>  <options>                                              <dump> <pass>
# /dev/main/sys   /              btrfs   subvol=@,compress=zstd:1,noatime          0  0
# /dev/main/sys   /home          btrfs   subvol=@home,compress=zstd:1,noatime      0  0
# /dev/main/sys   /.snapshots    btrfs   subvol=@snapshots,compress=zstd:1,noatime 0  0
# /dev/main/sys   /var/cache     btrfs   subvol=@cache,compress=zstd:1,noatime     0  0
# /dev/main/sys   /var/log       btrfs   subvol=@log,compress=zstd:1,noatime       0  0
# /dev/nvme0n1p1  /boot          vfat    umask=0077                                0  1
FSTAB_TMPL

# --- Networking ---
# Fallback resolv.conf until NetworkManager/DHCP populates it
cat > /etc/resolv.conf <<RESOLV
nameserver 1.1.1.1
nameserver 8.8.8.8
RESOLV

# Tell NetworkManager to use iwd as Wi-Fi backend (iwd installed in packages)
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-iwd.conf <<NMCONF
[device]
wifi.backend=iwd
NMCONF

# Services
systemctl enable NetworkManager
systemctl enable iwd
systemctl enable sshd
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# --- Passwordless sudo for neg (paru needs it for AUR builds) ---
echo "neg ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-neg-nopasswd
chmod 440 /etc/sudoers.d/99-neg-nopasswd
'

# --- Full package installation (separate chroot pass) ---
if [[ -f /mnt/packages/cachyos-packages.sh ]]; then
    echo "==> [container] Copying package script into target..."
    cp /mnt/packages/cachyos-packages.sh "$TARGET/root/cachyos-packages.sh"
    chmod +x "$TARGET/root/cachyos-packages.sh"

    echo "==> [container] Running full package installation in chroot..."
    arch-chroot "$TARGET" bash /root/cachyos-packages.sh

    rm -f "$TARGET/root/cachyos-packages.sh"
else
    echo "==> WARNING: cachyos-packages.sh not found at /mnt/packages/, skipping full install"
fi

echo "==> [container] Bootstrap complete."
INNER
)

# Substitute variables into inner script
INNER_SCRIPT="${INNER_SCRIPT//__CACHYOS_KEY__/$CACHYOS_KEY}"
INNER_SCRIPT="${INNER_SCRIPT//__PACKAGES__/${PACKAGES[*]}}"

# -------------------------------------------------------------------
# Run in Podman
# -------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Launching Arch container for bootstrap..."
podman run --rm -it --privileged \
    --name cachyos-bootstrap \
    -v "$TARGET:/mnt/target" \
    -v "$SCRIPT_DIR:/mnt/packages:ro" \
    "$ARCH_IMAGE" \
    bash -c "$INNER_SCRIPT"

# -------------------------------------------------------------------
# Post-bootstrap verification
# -------------------------------------------------------------------

echo ""
echo "==> Verification:"

checks=(
    "usr/bin/pacman:pacman binary"
    "usr/share/limine/BOOTX64.EFI:Limine EFI binary"
    "etc/snapper/configs/root:snapper root config"
    "etc/hostname:hostname config"
    "etc/locale.conf:locale config"
    "home/neg:user home directory"
)

ok=true
for check in "${checks[@]}"; do
    path="${check%%:*}"
    label="${check#*:}"
    if [[ -e "$TARGET/$path" ]]; then
        echo "  OK  $label"
    else
        echo "  FAIL  $label ($TARGET/$path missing)"
        ok=false
    fi
done

if $ok; then
    TARGET_DIR="$(dirname "$TARGET")"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

    # Copy salt repo alongside rootfs (needed after NVMe is reformatted)
    echo ""
    echo "==> Copying salt repo to $TARGET_DIR/salt/ ..."
    rsync -a --delete \
        --exclude='rpms/' \
        --exclude='.venv/' \
        --exclude='logs/' \
        --exclude='.salt_runtime/' \
        --exclude='.claude/' \
        --exclude='__pycache__/' \
        --exclude='.password' \
        --exclude='tt' \
        "$REPO_ROOT/" "$TARGET_DIR/salt/"
    chmod +x "$TARGET_DIR/salt/scripts/deploy-cachyos.sh"
    echo "  OK  salt repo copied to $TARGET_DIR/salt/"

    echo ""
    echo "==> Rootfs ready at: $TARGET"
    echo ""
    echo "Deploy from this host:"
    echo "  sudo $SCRIPT_DIR/deploy-cachyos.sh /dev/nvme0n1 $TARGET"
    echo ""
    echo "Deploy from a live USB:"
    echo "  vgchange -ay xenon"
    echo "  mount /dev/mapper/xenon-one /mnt/one"
    echo "  bash /mnt/one/salt/scripts/deploy-cachyos.sh /dev/nvme0n1 /mnt/one/cachyos-root"
else
    echo ""
    echo "==> Bootstrap may have failed — check output above"
    exit 1
fi
