# Настройка Windows VM (QEMU/KVM + Looking Glass)

Железо: AMD Ryzen 9 9950X3D, RX 9070 XT (дискретная), Granite Ridge iGPU, 64 ГБ RAM.

## Зависимости

Salt states устанавливают всё необходимое:

```bash
sudo salt-call state.apply   # ставит swtpm, looking-glass, edk2-ovmf и т.д.
```

Пакеты, управляемые Salt:
- `qemu-desktop` — QEMU с десктопными настройками
- `libvirt` — демон управления VM (активация через сокет)
- `virt-manager` — GUI-фронтенд
- `swtpm` — программный TPM (требование Windows 11)
- `edk2-ovmf` — UEFI-прошивка для VM
- `looking-glass` (AUR) — IVSHMEM-клиент с минимальной задержкой
- `freerdp` — RDP-клиент (для WinApps или удалённого доступа)

Пользователь `neg` в группах: `libvirt`, `kvm`.

## 1. Создание VM с Windows 11

### Через virt-manager (рекомендуется для первой настройки)

1. Скачать ISO Windows 11 и [ISO драйверов virtio-win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable1/virtio-win.iso)
2. Открыть `virt-manager` -> Создать новую VM
3. Выбрать "Local install media" -> указать ISO Windows 11
4. Память: **16384 МБ** (16 ГБ), CPU: **8** (4 ядра x 2 потока)
5. Диск: **80 ГБ**, VirtIO (быстрее стандартного SATA)
6. Перед "Finish" -> отметить **"Customize configuration before install"**

### Настройка конфигурации VM

#### Overview
- Firmware: **UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd**
  (вариант с Secure Boot — нужен для Windows 11)

#### CPU
- Топология: вручную — Sockets: 1, Cores: 4, Threads: 2
- Модель CPU: **host-passthrough** (проброс реальных возможностей CPU)

#### Память
- 16384 МБ (регулируйте по потребности; всего 64 ГБ)

#### Диск
- Тип шины: **VirtIO** (ставить virtio-win драйверы при установке Windows)
- Режим кэша: **writeback** (лучше производительность, безопасно с журналированием хоста)

#### Добавить: TPM
- Model: **TIS**
- Backend: **Emulated** (использует swtpm автоматически)
- Version: **2.0**

#### Добавить: CDROM
- Второй CDROM с `virtio-win.iso`
  (установщик Windows не видит VirtIO-диск без драйвера)

#### Сеть
- Модель устройства: **virtio**

### Установка Windows

Когда "Где установить Windows?" не показывает дисков:
1. Нажать "Загрузить драйвер"
2. Перейти на CD virtio-win -> `viostor/w11/amd64`
3. Выбрать драйвер -> диски появятся
4. Также загрузить `NetKVM/w11/amd64` (сеть) для интернета в OOBE

После установки запустить `virtio-win-gt-x64.msi` с virtio-win CD в Windows
для установки всех оставшихся VirtIO-драйверов (balloon, serial, QEMU agent и т.д.).

## 2. Проброс USB

### Метод A: Проброс отдельного устройства (просто, горячее подключение)

В `virt-manager` -> детали VM -> Add Hardware -> USB Host Device -> выбрать устройство.

Или через CLI (горячее подключение к запущенной VM):

```bash
# Найти vendor:product ID
lsusb
# Пример: Bus 003 Device 006: ID 0951:16ae Kingston Technology DT microDuo 3C

# Подключить к работающей VM
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

### Метод B: Проброс USB-контроллера целиком (все порты контроллера)

Лучше для устройств, требующих полный USB-стек (ключи защиты, FPGA-программаторы и т.д.).

IOMMU-группы с USB-контроллерами на этой системе:
- **Группа 33** `7c:00.3` — AMD Raphael USB 3.1 xHCI
- **Группа 34** `7c:00.4` — AMD Raphael USB 3.1 xHCI
- **Группа 35** `7d:00.0` — AMD Raphael USB 2.0 xHCI
- **Группа 23** `12:00.0` — AMD 600 Chipset USB 3.x xHCI
- **Группа 28** `7a:00.0` — ASMedia ASM4242 USB 3.2 xHCI
- **Группа 29** `7b:00.0` — ASMedia ASM4242 USB4/TB3

Определить, какие физические порты к какому контроллеру относятся:

```bash
# Воткнуть устройство в порт, потом проверить контроллер:
lsusb -t
# Или:
udevadm info -a /dev/bus/usb/003/006 | grep -i pci
```

Проброс через virt-manager: Add Hardware -> PCI Host Device -> выбрать контроллер.

Или через libvirt XML:

```xml
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address domain='0x0000' bus='0x7a' slot='0x00' function='0x0'/>
  </source>
</hostdev>
```

## 3. Проброс GPU + Looking Glass

### IOMMU-группы (проверено — чистое разделение)

| Группа | BDF      | Устройство                |
|--------|----------|---------------------------|
| 16     | 03:00.0  | RX 9070 XT (VGA)          |
| 17     | 03:00.1  | RX 9070 XT (HDMI Audio)   |
| 30     | 7c:00.0  | Granite Ridge iGPU        |

Стратегия: хост на iGPU (группа 30), дискретная RX 9070 XT (группы 16+17) -> в VM.

### Шаг 1: Привязать RX 9070 XT к vfio-pci при загрузке

Добавить параметры ядра (в limine.conf или через Salt `kernel_params_limine.sls`):

```
iommu=pt vfio-pci.ids=1002:7550,1002:ab40
```

- `iommu=pt` — режим passthrough, снижает накладные расходы IOMMU для хоста
- `vfio-pci.ids` — захватывает эти PCI ID до загрузки amdgpu

Создать конфиг modprobe (`/etc/modprobe.d/vfio.conf`):

```
softdep amdgpu pre: vfio-pci
```

Пересобрать initramfs:

```bash
sudo mkinitcpio -P
```

### Шаг 2: Добавить GPU в VM

В libvirt XML (или virt-manager -> Add Hardware -> PCI Host Device):

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

### Шаг 3: Добавить IVSHMEM-устройство для Looking Glass

Добавить в XML VM (через `virsh edit win11`):

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>
```

Формула размера: `width * height * 4 * 2`, округлить до степени 2.
Для 4K (3840x2160): 3840*2160*4*2 = ~63 МБ -> 128 МБ достаточно.

Salt создаёт `/dev/shm/looking-glass` через tmpfiles.d (владелец `neg:kvm`, права 0660).

### Шаг 4: Установить Looking Glass Host в Windows VM

1. Скачать Looking Glass Host с [releases](https://looking-glass.io/downloads)
   (версия должна совпадать с клиентом из AUR, сейчас B7)
2. Установить в Windows — работает как системная служба
3. Хост захватывает кадры и пишет их в IVSHMEM

### Шаг 5: Запустить Looking Glass клиент на хосте

```bash
looking-glass-client -f /dev/shm/looking-glass
```

Полезные флаги:
- `-F` — полноэкранный режим
- `-m 97` — Super+F12 для захвата/отпускания клавиатуры
- `-p 0` — zero-copy если поддерживается
- `-s` — использовать SPICE для ввода (обмен буфером обмена и т.д.)

### Видеовыход для VM

С GPU passthrough + Looking Glass убрать виртуальный дисплей:
- В `virsh edit win11` удалить секции `<video>` и `<graphics>`
  (или поставить модель video в `none`). Looking Glass их заменяет.

## 4. Сеть

NAT по умолчанию (`virbr0`) работает для большинства случаев. Для полного доступа:

- **Bridge mode**: создать бридж (`br0`) и подключить VM к нему
- Конфиг `/etc/systemd/network/br0.network` уже есть в Salt

## 5. Оптимизация производительности

### Привязка CPU (рекомендуется для 9950X3D)

У 9950X3D один CCD с 3D V-Cache. Привязать VM к CCD без V-Cache,
если нагрузка VM не выигрывает от кэша (большинство Windows-приложений):

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

Проверить, какой CCD имеет V-Cache:

```bash
# CCD с 3D V-Cache обычно имеет больший L3:
lstopo-no-graphics | grep -i l3
# Или:
lscpu --all --extended | head -20
```

### Hugepages (опционально)

Для 16 ГБ VM с 2 МБ hugepages:

```xml
<memoryBacking>
  <hugepages/>
</memoryBacking>
```

Предварительное выделение: `echo 8192 > /proc/sys/vm/nr_hugepages`

## Устранение проблем

- **VM не запускается с TPM**: проверить что `swtpm` установлен, `swtpm_setup --help` работает
- **USB-устройство пропало на хосте**: ожидаемо — устройство теперь принадлежит VM
- **Looking Glass чёрный экран**: убедиться что хост-приложение запущено в Windows, размер IVSHMEM совпадает
- **Баг сброса GPU**: AMD GPU могут не сбрасываться корректно. Если VM не перезапускается — попробовать `vendor-reset` (AUR: `vendor-reset-dkms-git`) или перезагрузить хост
- **RX 9070 XT**: RDNA 4 новая — проверяйте Arch Wiki и Looking Glass Discord на актуальные заметки по совместимости
