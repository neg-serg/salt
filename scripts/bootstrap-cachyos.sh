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
    linux-cachyos
    linux-cachyos-headers
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

    # XFS support (for /var/mnt/zero, /var/mnt/one)
    xfsprogs

    # Network
    networkmanager
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
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Initialize pacman keyring properly inside target
pacman-key --init
pacman-key --populate archlinux
pacman-key --populate cachyos 2>/dev/null || {
    pacman-key --recv-keys __CACHYOS_KEY__ --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key __CACHYOS_KEY__
}

# vconsole.conf (silences mkinitcpio warning)
echo "KEYMAP=us" > /etc/vconsole.conf

# --- mkinitcpio: zstd compression (saves ESP space for Limine snapshots) ---
if [[ -f /etc/mkinitcpio.conf ]]; then
    sed -i "s/^#\?COMPRESSION=.*/COMPRESSION=\"zstd\"/" /etc/mkinitcpio.conf
    sed -i "s/^#\?COMPRESSION_OPTIONS=.*/COMPRESSION_OPTIONS=(-19 -T0)/" /etc/mkinitcpio.conf
else
    cat > /etc/mkinitcpio.conf <<MKINIT
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
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
    kernel_path: boot():/vmlinuz-linux-cachyos
    kernel_cmdline: root=LABEL=cachyos rootflags=subvol=@ rw quiet splash
    module_path: boot():/initramfs-linux-cachyos.img

/CachyOS (fallback)
    protocol: linux
    kernel_path: boot():/vmlinuz-linux-cachyos
    kernel_cmdline: root=LABEL=cachyos rootflags=subvol=@ rw
    module_path: boot():/initramfs-linux-cachyos-fallback.img
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
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"

# cleanup
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="5"

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
# LABEL=cachyos   /              btrfs   subvol=@,compress=zstd:1,noatime,ssd,space_cache=v2    0      0
# LABEL=cachyos   /home          btrfs   subvol=@home,compress=zstd:1,noatime,ssd,space_cache=v2 0     0
# LABEL=cachyos   /.snapshots    btrfs   subvol=@snapshots,compress=zstd:1,noatime,ssd,space_cache=v2 0 0
# LABEL=cachyos   /var/cache     btrfs   subvol=@cache,compress=zstd:1,noatime,ssd,space_cache=v2 0   0
# LABEL=cachyos   /var/log       btrfs   subvol=@log,compress=zstd:1,noatime,ssd,space_cache=v2 0     0
# LABEL=efi       /boot/efi      vfat    umask=0077                                              0     1
FSTAB_TMPL

# Services
systemctl enable NetworkManager
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
    echo ""
    echo "==> Rootfs ready at: $TARGET"
    echo ""
    echo "Deploy to Btrfs partition:"
    echo ""
    echo "  # 1. Create partitions (example for /dev/sdX):"
    echo "  parted /dev/sdX -- mklabel gpt"
    echo "  parted /dev/sdX -- mkpart ESP fat32 1MiB 4GiB"
    echo "  parted /dev/sdX -- set 1 esp on"
    echo "  parted /dev/sdX -- mkpart root btrfs 4GiB 100%"
    echo ""
    echo "  # 2. Format:"
    echo "  mkfs.fat -F32 -n efi /dev/sdX1"
    echo "  mkfs.btrfs -L cachyos /dev/sdX2"
    echo ""
    echo "  # 3. Create subvolumes:"
    echo "  mount /dev/sdX2 /mnt"
    echo "  btrfs subvolume create /mnt/@"
    echo "  btrfs subvolume create /mnt/@home"
    echo "  btrfs subvolume create /mnt/@cache"
    echo "  btrfs subvolume create /mnt/@log"
    echo "  btrfs subvolume create /mnt/@snapshots"
    echo "  umount /mnt"
    echo ""
    echo "  # 4. Mount subvolumes:"
    echo "  mount -o subvol=@,compress=zstd:1,noatime /dev/sdX2 /mnt"
    echo "  mkdir -p /mnt/{home,boot/efi,.snapshots,var/cache,var/log}"
    echo "  mount -o subvol=@home,compress=zstd:1,noatime /dev/sdX2 /mnt/home"
    echo "  mount -o subvol=@snapshots,compress=zstd:1,noatime /dev/sdX2 /mnt/.snapshots"
    echo "  mount -o subvol=@cache,compress=zstd:1,noatime /dev/sdX2 /mnt/var/cache"
    echo "  mount -o subvol=@log,compress=zstd:1,noatime /dev/sdX2 /mnt/var/log"
    echo "  mount /dev/sdX1 /mnt/boot/efi"
    echo ""
    echo "  # 5. Copy rootfs:"
    echo "  rsync -aAXH --info=progress2 $TARGET/ /mnt/"
    echo ""
    echo "  # 6. Generate fstab + install Limine:"
    echo "  genfstab -U /mnt >> /mnt/etc/fstab"
    echo "  arch-chroot /mnt limine bios-install /dev/sdX  # (BIOS)"
    echo "  # or copy BOOTX64.EFI to ESP for UEFI (already in /boot/EFI/BOOT/)"
    echo ""
    echo "  # 7. Change passwords:"
    echo "  arch-chroot /mnt passwd"
    echo "  arch-chroot /mnt passwd neg"
else
    echo ""
    echo "==> Bootstrap may have failed — check output above"
    exit 1
fi
