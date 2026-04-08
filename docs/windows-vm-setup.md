# Windows VM Setup (QEMU/KVM + Looking Glass)

Hardware: AMD Ryzen 9 9950X3D, RX 9070 XT (discrete), Granite Ridge iGPU, 64 GB RAM.

## Prerequisites

Salt states install everything needed:

```bash
sudo salt-call state.apply   # installs swtpm, looking-glass, edk2-ovmf, etc.
```

Packages managed by Salt:
- `qemu-desktop` — QEMU with desktop-oriented defaults
- `libvirt` — VM management daemon (socket-activated)
- `virt-manager` — GUI frontend
- `swtpm` — software TPM (Windows 11 requirement)
- `edk2-ovmf` — UEFI firmware for VMs
- `looking-glass` (AUR) — low-latency IVSHMEM display client
- `freerdp` — RDP client (for WinApps or remote access)

User `neg` is in groups: `libvirt`, `kvm`.

## 1. Create Windows 11 VM

### Via virt-manager (recommended for first setup)

1. Download Windows 11 ISO and [virtio-win drivers ISO](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable1/virtio-win.iso)
2. Open `virt-manager` → Create a new virtual machine
3. Choose "Local install media" → select Windows 11 ISO
4. Memory: **16384 MB** (16 GB), CPUs: **8** (4 cores x 2 threads)
5. Storage: **80 GB**, VirtIO disk (faster than default SATA)
6. Before "Finish" → check **"Customize configuration before install"**

### Customize VM configuration

#### Overview
- Firmware: **UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd**
  (Secure Boot variant — needed for Windows 11)

#### CPUs
- Topology: manually set — Sockets: 1, Cores: 4, Threads: 2
- CPU model: **host-passthrough** (exposes real CPU features)

#### Memory
- 16384 MB (adjust to your needs; you have 64 GB total)

#### Storage
- Bus type: **VirtIO** (install virtio-win drivers during Windows setup)
- Cache mode: **writeback** (better performance, safe with host journaling)

#### Add Hardware: TPM
- Model: **TIS**
- Backend: **Emulated** (uses swtpm automatically)
- Version: **2.0**

#### Add Hardware: CDROM
- Add second CDROM and attach `virtio-win.iso`
  (Windows installer can't see VirtIO disk without the driver)

#### Network
- Device model: **virtio**

### Windows installation notes

During install, when "Where do you want to install Windows?" shows no drives:
1. Click "Load driver"
2. Browse to virtio-win CD → `viostor/w11/amd64`
3. Select the driver → drives appear
4. Also load `NetKVM/w11/amd64` (network) for internet during OOBE

After install, run `virtio-win-gt-x64.msi` from the virtio-win CD inside Windows
to install all remaining VirtIO drivers (balloon, serial, QEMU agent, etc.).

## 2. USB Passthrough

### Method A: Per-device passthrough (simple, hot-pluggable)

In `virt-manager` → VM details → Add Hardware → USB Host Device → select device.

Or via CLI (hot-plug while VM runs):

```bash
# Find vendor:product ID
lsusb
# Example: Bus 003 Device 006: ID 0951:16ae Kingston Technology DT microDuo 3C

# Attach to running VM
virsh attach-device win11 --live <(cat <<'XML'
<hostdev mode='subsystem' type='usb' managed='yes'>
  <source>
    <vendor id='0x0951'/>
    <product id='0x16ae'/>
  </source>
</hostdev>
XML
)
```

### Method B: Whole USB controller passthrough (all ports on that controller)

Better for devices that need full USB stack access (DRM dongles, FPGA programmers, etc.).

IOMMU groups with USB controllers on this system:
- **Group 33** `7c:00.3` — AMD Raphael USB 3.1 xHCI
- **Group 34** `7c:00.4` — AMD Raphael USB 3.1 xHCI
- **Group 35** `7d:00.0` — AMD Raphael USB 2.0 xHCI
- **Group 23** `12:00.0` — AMD 600 Chipset USB 3.x xHCI
- **Group 28** `7a:00.0` — ASMedia ASM4242 USB 3.2 xHCI
- **Group 29** `7b:00.0` — ASMedia ASM4242 USB4/TB3

Identify which physical ports map to which controller:

```bash
# Plug a device into a port, then check which controller it appears under:
lsusb -t
# Or:
udevadm info -a /dev/bus/usb/003/006 | grep -i pci
```

Passthrough via virt-manager: Add Hardware → PCI Host Device → select controller.

Or via libvirt XML:

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x7a' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

## 3. GPU Passthrough + Looking Glass

### IOMMU groups (verified clean separation)

| Group | BDF      | Device                    |
|-------|----------|---------------------------|
| 16    | 03:00.0  | RX 9070 XT (VGA)          |
| 17    | 03:00.1  | RX 9070 XT (HDMI Audio)   |
| 30    | 7c:00.0  | Granite Ridge iGPU        |

Strategy: host uses iGPU (group 30), discrete RX 9070 XT (groups 16+17) goes to VM.

### Step 1: Bind RX 9070 XT to vfio-pci at boot

Add kernel parameters (in limine.conf or via Salt `kernel_params_limine.sls`):

```
iommu=pt vfio-pci.ids=1002:7550,1002:ab40
```

- `iommu=pt` — passthrough mode, reduces IOMMU overhead for host devices
- `vfio-pci.ids` — grabs these PCI IDs before amdgpu loads

Create modprobe config (`/etc/modprobe.d/vfio.conf`):

```
softdep amdgpu pre: vfio-pci
```

Rebuild initramfs:

```bash
sudo mkinitcpio -P
```

### Step 2: Add GPU to VM

In libvirt XML (or virt-manager → Add Hardware → PCI Host Device):

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
  </source>
</hostdev>
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x03' slot='0x00' function='0x1'/>
  </source>
</hostdev>
```

### Step 3: Add IVSHMEM device for Looking Glass

Add to VM XML (via `virsh edit win11`):

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>
```

Size formula: `width * height * 4 * 2` rounded up to power of 2.
For 4K (3840x2160): 3840*2160*4*2 = ~63 MB → 128 MB is sufficient.

Salt creates `/dev/shm/looking-glass` via tmpfiles.d (owned by `neg:kvm`, mode 0660).

### Step 4: Install Looking Glass Host in Windows VM

1. Download the Looking Glass Host application from the [releases page](https://looking-glass.io/downloads)
   (match version to the client installed via AUR, currently B7)
2. Install in Windows — it runs as a system service
3. The host captures frames and writes them to IVSHMEM

### Step 5: Run Looking Glass client on host

```bash
looking-glass-client -f /dev/shm/looking-glass
```

Useful flags:
- `-F` — start in fullscreen
- `-m 97` — map Super+F12 to grab/release keyboard
- `-p 0` — zero-copy if supported
- `-s` — use SPICE for input (clipboard sharing, etc.)

### Video output for VM

With GPU passthrough + Looking Glass, remove the virtual display:
- In `virsh edit win11`, remove the `<video>` and `<graphics>` sections
  (or set video model to `none`). Looking Glass replaces them.

## 4. Networking

Default NAT (`virbr0`) works for most cases. For full network access:

- **Bridge mode**: create a bridge (`br0`) and attach the VM to it
- Already have `/etc/systemd/network/br0.network` in Salt configs

## 5. Performance Tuning

### CPU pinning (recommended for 9950X3D)

The 9950X3D has one CCD with 3D V-Cache. Pin VM to the non-3D-cache CCD
if the VM workload doesn't benefit from cache (most Windows apps don't):

```xml
<vcpu placement='static'>8</vcpu>
<cputune>
  <vcpupin vcpu='0' cpuset='16'/>
  <vcpupin vcpu='1' cpuset='17'/>
  <vcpupin vcpu='2' cpuset='18'/>
  <vcpupin vcpu='3' cpuset='19'/>
  <vcpupin vcpu='4' cpuset='20'/>
  <vcpupin vcpu='5' cpuset='21'/>
  <vcpupin vcpu='6' cpuset='22'/>
  <vcpupin vcpu='7' cpuset='23'/>
</cputune>
```

Check which CCD has V-Cache:

```bash
# 3D V-Cache CCD typically has larger L3:
lstopo-no-graphics | grep -i l3
# Or:
lscpu --all --extended | head -20
```

### Hugepages (optional)

For 16 GB VM with 2 MB hugepages:

```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

Pre-allocate: `echo 8192 > /proc/sys/vm/nr_hugepages`

## Troubleshooting

- **VM won't start with TPM**: check `swtpm` is installed, `swtpm_setup --help` works
- **USB device disappears on host**: expected — the device is now owned by the VM
- **Looking Glass black screen**: ensure host app is running in Windows, IVSHMEM size matches
- **GPU reset bug**: AMD GPUs may not reset cleanly. If VM fails to restart, try `vendor-reset` (AUR: `vendor-reset-dkms-git`) or reboot host
- **RX 9070 XT specific**: RDNA 4 is new — check Arch Wiki and Looking Glass Discord for latest compatibility notes
