# NixOS on Raspberry Pi 5

Template for building a custom NixOS SD image for the Raspberry Pi 5, then deploying host configurations remotely via `nixos-rebuild`. Fork it, put your SSH key in `modules/pi5-common.nix`, build the image, flash, SSH in, deploy.

## What this repo gives you

- `images.pi5-bootstrap` — a minimal SD image with SSH access. Flash once, boot, SSH in. No keyboard or HDMI needed after first flash.
- `nixosConfigurations.pi5-host-1` and `nixosConfigurations.pi5-host-2` — example host configs. Rename and extend.
- `modules/pi5-common.nix` — shared base config (SSH, user, kernel, filesystem, packages).

## Prerequisites

### Build box

You need a NixOS machine (x86_64 is fine) with aarch64 emulation registered:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

Rebuild the build box after adding this line.

### nixpkgs channel

**Pi 5 requires `nixos-unstable`, not `nixos-26.05` (stable).** The stable branch lacks Pi 5-family boot files in its SD image module. The generic aarch64 unstable image has supported Pi 5 since [nixpkgs PR #537862](https://github.com/NixOS/nixpkgs/pull/537862) landed.

## Build the bootstrap image

```bash
nix build .#images.pi5-bootstrap
zstd -d result/sd-image/*.img.zst -o pi5-bootstrap.img
sudo dd if=pi5-bootstrap.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Uses the mainline Linux kernel — cached on `cache.nixos.org`, fast build. No `nixos-hardware` needed for the bootstrap image because the generic unstable aarch64 SD image already ships Pi 5 device trees, a unified U-Boot binary, and the `[pi5] config.txt` section.

Flash to microSD, not a USB SSD or NVMe. U-Boot on the Pi 5 can't read the boot files back from USB or NVMe yet — only the SD card slot works. Reference: [NixOS Wiki — Pi 5 Storage](https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_5).

## First boot

```bash
ssh myuser@<pi-ip>
```

Find the IP via your router's DHCP lease table. If you reflash and see a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning:

```bash
ssh-keygen -R <pi-ip>
```

Your SSH key is the only way in (password auth disabled, root login disabled).

## Deploy a host config

```bash
nixos-rebuild switch --flake .#pi5-host-1 --target-host myuser@<pi-ip> --sudo
```

After the first `nixos-rebuild switch`, the Pi runs your host config. All future changes go through `nixos-rebuild switch` over SSH. Reboot once to apply the new hostname.

`pi5-common.nix` sets `security.sudo.wheelNeedsPassword = false` for bootstrap convenience. After your Pi is stable, set up agenix or sops-nix for secret management.

## Why mainline kernel, not the nixos-hardware vendor kernel

The deployed hosts import `nixos-hardware.nixosModules.raspberry-pi-5` for board-specific boot setup. But the profile also pins Raspberry Pi's downstream `linux-rpi` kernel, which is **not built by Hydra and not on `cache.nixos.org`** — see [nixos-hardware issue #854](https://github.com/NixOS/nixos-hardware/issues/854). Importing the profile as-is triggers a full kernel build from source: hours under emulation, long even on the Pi itself.

To avoid that, `modules/pi5-common.nix` overrides the kernel:

```nix
boot.kernelPackages = pkgs.linuxPackages;
```

### What you get from nixos-hardware

- Pi 5 boot setup (no GRUB; extlinux-based generations and rollback)
- BCM2712 device-tree filtering (only Pi 5 device trees land in your system)
- Pi 5 initrd drivers (NVMe, PCIe, RP1 — so your boot drive comes up)
- The right driver module names for whichever kernel you pick — the profile adapts automatically

### What you don't get

- The Raspberry Pi downstream `linux-rpi` kernel and its vendor-specific patches
- Automatic FAT partition refresh on `nixos-rebuild switch` (opt-in only — see below)

### Practical consequences

- Mainline boots Pi 5 fine for headless use: network, USB, NVMe root, framebuffer.
- You may lose vendor-validated edge cases: RP1 GPIO quirks, VC4 KMS graphics paths, HAT overlays, vendor NVMe timing.
- To switch to the vendor kernel, comment out the override in `modules/pi5-common.nix`. Expect a long uncached build the first time.

### Firmware partition refresh

The bootstrap image's FAT partition (U-Boot, GPU firmware, `config.txt`, device trees) is written once at image build time. `nixos-rebuild switch` does **not** refresh it — only the ext4 partition (kernel, initrd, `extlinux.conf`) updates on each rebuild. For a headless mainline box this is invisible. If a future nixpkgs bumps U-Boot or you need declarative `config.txt`, either reflash the bootstrap or enable the nixos-hardware firmware module. Mount `/boot/firmware` and add:

```nix
fileSystems."/boot/firmware" = {
  device = "/dev/disk/by-label/FIRMWARE";
  fsType = "vfat";
};

hardware.raspberry-pi.firmware = {
  enable = true;
  uboot.enable = true;
};
```

This works with either kernel. The activation script prunes stale `*.dtb` files and overlays it didn't copy, so don't keep manual changes on the FAT partition.
