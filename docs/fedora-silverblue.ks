# Fedora Silverblue Kickstart Template
# Generated based on existing system configuration in /root/anaconda-ks.cfg

# --- System Settings ---
text
keyboard --vckeymap=ru --xlayouts='us','ru' --switch='grp:alt_shift_toggle'
lang ru_RU.UTF-8
timezone Europe/Moscow --utc
firewall --use-system-defaults
firstboot --enable

# --- OSTree Setup (Silverblue Specific) ---
# Update the ref if installing a different version
ostreesetup --osname="fedora" --remote="fedora" --url="file:///ostree/repo" --ref="fedora/43/x86_64/silverblue" --nogpg

# --- Partitioning ---
# To use Ext4/XFS instead of Btrfs, replace 'autopart' with manual 'part' definitions
ignoredisk --only-use=nvme1n1
autopart
# Example manual partitioning for Ext4 (comment out 'autopart' to use this):
# clearpart --all --initlabel
# part /boot/efi --fstype="efi" --size=600
# part /boot --fstype="ext4" --size=1024
# part pv.01 --grow --size=1
# volgroup fedora pv.01
# logvol / --fstype="ext4" --name=root --vgname=fedora --size=40000
# logvol /var --fstype="ext4" --name=var --vgname=fedora --grow --size=1

# --- User Configuration ---
rootpw --lock
# Replace 'YOUR_PASSWORD_HASH' with a real hash (generate with: openssl passwd -6)
user --name=neg --groups=wheel --uid=1000 --gid=1000 --password=$y$j9T$4Its.5R.HvywmvnhQWoTB1$iJTgDvK2cRyrjmeFV9V428edGyAy9Tl7WuOpx81m6/B --iscrypted

# --- Post-installation Script ---
%post --log=/mnt/sysimage/root/ks-post.log
# Ensure we can run sudo without password during bootstrap
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Optional: Auto-clone this repository and run salt
# cd /var/home/neg
# sudo -u neg git clone https://github.com/youruser/salt.git src/salt
# cd src/salt
# sudo -u neg ./apply_config.sh
%end

reboot
