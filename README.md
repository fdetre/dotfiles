# Arch Linux installation with encryption + Wayland configuration

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
pacstrap /mnt lvm2 grub os-prober efibootmgr neovim bash-completion iwd
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

## Post-installation

### Utility packages

```bash
pacman -S zip unzip p7zip ntp cronie exfat-utils zsh git wget curl intel-ucode man
```

Enable services:

```bash
systemctl enable cronie
systemctl enable ntpd
```

### Create a new user

Use the following command (can use bash instead of zsh):

```bash
useradd -m -g wheel -c 'User Name' -s /bin/zsh username
```

Create a password for the new user:

```bash
passwd username
```

Edit /etc/sudoers and uncomment the line to allow members of group wheel to execute any command as follow:

```bash
## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL
```

**From now everything is executed as the new user created above**

### Oh My Zsh

Oh My Zsh is a framework for managing zsh configuration.

```bash
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Prompt

```bash
sudo pacman -S starship
echo "eval \"\$(starship init zsh)\"" >> $HOME/.zshrc
```

### SSH

Package:

```bash
sudo pacman -S openssh
```

Enable and start the service (start if you need before next boot):

```bash
sudo systemctl enable sshd
sudo systemctl start sshd
```

### Graphics

```bash
sudo pacman -S mesa vulkan-intel
```

### Audio

PipeWire is a low-level multimedia framework.

```bash
sudo pacman -S pipewire pipewire-pulse wireplumber pavucontrol
```

It will need a reboot to work correctly

### User directories

The following is to create the "classic" user directories (Documents, Pictures, Videos, Music...):

```bash
sudo pacman -S xdg-user-dirs
xdg-user-dirs-update
```

### Yay

Yay is an AUR helper that lets you download and install packages from the Arch User Repository.

```bash
# Install necessary dependency and patch resolvconf (otherwise it will fail fetching some sources)
pacman -S go
systemctl start systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# Install yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
```

### Fonts

Use NerdFonts for a large set of icons and fonts needed for foot terminal, sway and waybar.

```bash
# Shallow clone : Make sure to use --depth 1 otherwise you will clone hundreds of unnecessary GigaBytes
git clone --depth 1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
./install.sh
```

### Terminal

Foot is a fast, lightweight, and minimalistic Wayland terminal emulator.

```bash
sudo pacman -S foot
```

### Sway

Sway is a tiling Wayland compositor and a drop-in replacement for the i3 window manager for X11.

```bash
sudo pacman -S sway swaylock swayidle swaybg
```

It will also need a package to access to hardware devices such as keyboard, mouse, and graphics card.

```bash
sudo pacman -S polkit polkit-gnome
echo "exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" >> $HOME/.config/sway/config
```

### Rofi

Rofi is a window switcher, run dialog, ssh-launcher and dmenu replacement. Install the wayland fork only available in the AUR:

```bash
yay -S rofi-lbonn-wayland 
```

### Waybar

Waybar is a customizable Wayland bar for Sway and Wlroots based compositors

```bash
sudo pacman -S waybar
```

### ACPI

It will be used in the custom waybar script called pipewire to check if the jack is plugged or not.

```bash
sudo pacman -S acpid
sudo systemctl enable acpid
sudo systemctl start acpid
```

### Screen capture

Grim is a screenshot utility for Wayland. Slurp is used for selecting aerea and for multiple displays. Install imagemagick to have the convert command for the blur effect on screenlock

```bash
yay -S grimshot
sudo pacman -S grim slurp imagemagick
```

### Screen sharing

To be able to have screen sharing on google meet:

```bash
yay -S xdg-desktop-portal xdg-desktop-portal-wlr
```

**Dont't forget to put this line in your sway config file otherwise all the graphic part of the system will be very slow:**

```bash
echo "exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway" >> $HOME/.config/sway/config
```

Configuration:

```bash
mkdir ~/.config/xdg-desktop-portal-wlr
echo "chooser_type = simple\nchooser_cmd = slurp -f %o -ro" > $HOME/.config/xdg-desktop-portal-wlr/config
```

### Configuring displays

wdisplays is a graphical application for configuring displays in Wayland compositors.

```bash
yay -S wdisplays
```

### WireGuard

WireGuard is a fast, modern and secure VPN tunnel.

```bash
sudo pacman -S wireguard-tools systemd-resolvconf
sudo systemctl enable systemd-resolved.service
```

### DVD Rip

Use the handbrake software.

```bash
sudo pacman -S libdvdread libdvdcss libdvdnav handbrake
```
