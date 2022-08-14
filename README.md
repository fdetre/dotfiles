# Arch Linux installation with encryption

We're going to install an Arch Linux system with a full disk encryption except for the
boot partition.

We will use the [LVM on LUKS method](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS)

Global steps :

- 2 partitions :
  - 1 for the boot
  - 1 for the LVM that will be encrypted and contain the swap root and home partitions
- Encrypt the second partition
- LVM on the second partition
- Create the partitions on the LVM
- Mount the partitions
- Install the system
- Software post installation

In the tutorial we will name the boot partition as nvme0n1p1 and the LVM as nvme0n1p2

## Create the two partitions

nvme0n1 is the drive that will contain the two partitions (boot and LVM)

Execute the following command to pop the disk partitions utility for the specified disk

```bash
cgdisk /dev/nvme0n1
```

Create 2 partitions :

- 1 EFI system partition 512M (code EF00) (/dev/nvme0n1p1)
- 1 Linux filesystem with the left disk space (default code 8300) (/dev/nvme0n1p2)

## LVM on LUKS

### LUKS

Create the LUKS encrypted container at the "system" partition.

```bash
cryptsetup luksFormat /dev/nvme0n1p2
```

Open the container:

```bash
cryptsetup open /dev/nvme0n1p2 cryptlvm
```

### LVM

Create a physical volume on top of the opened LUKS container:

```bash
pvcreate /dev/mapper/cryptlvm
```

Create a volume group (in this example named MyVolGroup, but it can be whatever you want) and add the previously created physical volume to it:

```bash
vgcreate MyVolGroup /dev/mapper/cryptlvm
```

Create all your logical volumes on the volume group:

```bash
lvcreate -L 8G MyVolGroup -n swap
lvcreate -L 32G MyVolGroup -n root
lvcreate -l 100%FREE MyVolGroup -n home
```

Format your filesystems on each logical volume:

```bash
mkfs.ext4 /dev/MyVolGroup/root
mkfs.ext4 /dev/MyVolGroup/home
mkswap /dev/MyVolGroup/swap
```

Format the partition allocated for the boot:

```bash
mkfs.fat -F32 /dev/nvme0n1p1
```

Mount your filesystems:

```bash
mount /dev/MyVolGroup/root /mnt
mount --mkdir /dev/MyVolGroup/home /mnt/home
swapon /dev/MyVolGroup/swap
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

## Installation

Install essential packages:

```bash
pacstrap /mnt base base-devel linux linux-firmware
```

Install the packages needed for lvm, encrypt, boot and system configuration:

```bash
pacstrap /mnt lvm2 grub os-prober efibootmgr neovim bash-completion
```

## Configure the system

Generate an fstab file:

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

Change root into the new system:

```bash
arch-chroot /mnt
```

Set the time zone:

```bash
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
```

Run hwclock (if dual boot do nothing):

```bash
hwclock --systohc
```

Localization:

Edit /etc/locale.gen and uncomment en_US.UTF-8 UTF-8 and other needed locales. Generate the locales by running:

```bash
locale-gen
```

Create the locale.conf file, and set the LANG variable accordingly:

```bash
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

Create the hostname file:

```bash
echo "your_hostname" > /etc/hostname
```

### Initramfs

Configuring mkinitcpio:

Edit /etc/mkinitcpio.conf:

```bash
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
```

Recreate the initramfs image:

```bash
mkinitcpio -P
```

### bootloader

Install grub:

```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck
```

In order to unlock the encrypted root partition at boot, the following kernel parameter needs to be set by the boot loader in /etc/default/grub:

```bash
GRUB_CMDLINE_LINUX="cryptdevice=UUID=device-UUID:cryptlvm root=/dev/MyVolGroup/root"
```

In neovim to get the device-UUID just type:

```bash
!!blkid /dev/nvme0n1p2
```

The line containing the UUID will be placed in your file. Then just copy the UUID instead of the device-UUID in the kernel parameter.

For example:

```bash
GRUB_CMDLINE_LINUX="cryptdevice=UUID=be919c05-f93f-4b0e-bb7a-45618c7835d1:cryptlvm root=/dev/MyVolGroup/root"
```

Generate the grub config file:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

Set the root password:

```bash
passwd
```

### Network

Install the following package:

```bash
pacman -Syy networkmanager
```

Enable the service to be launched at start:

```bash
systemctl enable NetworkManager
```

### Reboot

Exit the chroot, unmount all partitions and reboot:

```bash
exit
umount -R /mnt
reboot
```
