# Disk mounts (/mnt/zero, /mnt/one) and btrfs compression
/mnt/zero:
  file.directory:
    - makedirs: True

mount_zero:
  mount.mounted:
    - name: /mnt/zero
    - device: /dev/mapper/argon-zero
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True
    - failhard: True

/mnt/one:
  file.directory:
    - makedirs: True

mount_one:
  mount.mounted:
    - name: /mnt/one
    - device: /dev/mapper/xenon-one
    - fstype: xfs
    - mkmnt: True
    - opts: noatime
    - persist: True
    - failhard: True

# btrfs compression: set as filesystem property (complements fstab compress= option).
btrfs_compress_home:
  cmd.run:
    - name: btrfs property set /home compression zstd:-1
    - unless: btrfs property get /home compression 2>/dev/null | rg -q 'zstd:-1'

btrfs_compress_var:
  cmd.run:
    - name: btrfs property set /var compression zstd:-1
    - unless: btrfs property get /var compression 2>/dev/null | rg -q 'zstd:-1'
