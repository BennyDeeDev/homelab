# NixOS on Raspberry Pi 5

A template for building a custom NixOS SD image for the Raspberry Pi 5 with SSH keys baked in, then deploying role-specific configurations remotely via `nixos-rebuild`.

## What this repo gives you

- `images/pi5-bootstrap` — a minimal SD image with SSH access. Flash once, boot, SSH in. No keyboard or HDMI needed after first flash.
- `nixosConfigurations.pi5-server` — example role config for a headless server.
- `nixosConfigurations.pi5-kiosk` — example role config for a display kiosk.
- `modules/pi5-common.nix` — shared base config (SSH, user, boot loader, filesystem).

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

Uses the mainline Linux kernel (cached on cache.nixos.org) — build finishes in under a minute. No `nixos-hardware` needed for the bootstrap image because the generic unstable aarch64 SD image already supports Pi 5.

## First boot

```bash
ssh myuser@<pi-ip>
```

Find the IP via your router's DHCP lease table. On the first SSH connection you may see a "REMOTE HOST IDENTIFICATION HAS CHANGED" warning — clear it with:

```bash
ssh-keygen -R <pi-ip>
```

Then retry SSH. Your key is the only way in (password auth is disabled, root login is disabled).

## Deploy role config

```bash
nixos-rebuild switch --flake .#pi5-server --target-host myuser@<pi-ip> --sudo
```

After the first `nixos-rebuild switch`, the Pi runs your role config. No more image reflashing — all future changes go through `nixos-rebuild switch` over SSH. Reboot once to apply the new hostname.

## Pitfalls

### USB SSD boot doesn't work

U-Boot v2026.07 (`rpi_arm64_defconfig`) cannot complete the extlinux boot flow from a USB SSD or NVMe on the Pi 5. The Pi EEPROM finds `u-boot.bin` and loads it, but U-Boot then can't read `extlinux.conf` back from the same device. Boot hangs at the U-Boot splash screen with no text output.

**Fix: boot from microSD.** The SD card slot is the only reliable boot path with the current U-Boot. Flash the image to a microSD card, not a USB SSD.

Reference: [NixOS Wiki — NixOS on ARM/Raspberry Pi 5](https://wiki.nixos.org/wiki/NixOS_on_ARM/Raspberry_Pi_5) (Storage section).

### nixos-hardware vendor kernel is not cached

The `nixos-hardware.nixosModules.raspberry-pi-5` profile swaps in the downstream vendor `linux-rpi` kernel (with `bcm2712_defconfig`, RP1 initrd modules, VC4 graphics config). That kernel package lives in the nixos-hardware repo, not in nixpkgs proper, and isn't built by Hydra's official CI. Building it means compiling the full vendor kernel from source — hours under QEMU emulation, ~30+ minutes natively on the Pi.

**For headless setups, skip nixos-hardware.** Mainline Linux 6.18+ boots Pi 5 fine (the generic unstable aarch64 SD image includes Pi 5 device trees and a unified U-Boot binary). Add `nixos-hardware` back only if you need RP1 GPIO edge cases, hardware-accelerated VC4 KMS (kiosk on HDMI), or vendor NVMe timing quirks.

### trusted-users needed for remote nixos-rebuild

`nixos-rebuild switch --target-host` uses `nix-copy-closure` to push the built closure from your build box to the Pi over SSH. The Pi's nix-daemon refuses unsigned store paths unless the pushing user is in `trusted-users`. Without it:

```
error: cannot add path '...' because it lacks a signature by a trusted key
```

**Fix:** set `nix.settings.trusted-users = [ "myuser" ]` in the config (already in `pi5-common.nix`). This trusts store pushes from the SSH-authenticated user.

### DHCP is the upstream default

`networking.useDHCP` defaults to `true` in nixpkgs. Don't set it explicitly unless you're overriding to `false` for a static IP config.

### Why split bootstrap from role configs

The bootstrap image is a one-time throwaway — flash once, SSH in, never reflash. Role configs are deployed remotely via `nixos-rebuild switch` forever after. Splitting them reflects the different deployment mechanisms: `images` output for flashing, `nixosConfigurations` for deploying.

### Why pi5-common.nix sets boot loader and root filesystem

`pi5-bootstrap.nix` imports `sd-image-aarch64.nix` which already sets `boot.loader.grub.enable = false`, `boot.loader.generic-extlinux-compatible.enable = true`, and `fileSystems."/"` (label `NIXOS_SD`, ext4) because building a bootable SD image requires them. `pi5-server.nix` and `pi5-kiosk.nix` don't import that module — they're deployed systems, not images — so without these set explicitly they'd fail `nix flake check` on grub/filesystems assertions.

The three settings are:
- `boot.loader.grub.enable = false` — GRUB is an x86 EFI bootloader; the Pi's boot chain (VideoCore → U-Boot → extlinux) has no use for it. NixOS defaults `grub.enable = true`, so it must be explicitly disabled.
- `boot.loader.generic-extlinux-compatible.enable = true` — generates `extlinux.conf` during `nixos-rebuild switch` so U-Boot can read the new kernel + initrd on next boot. Without it, rebuilds don't propagate across reboots.
- `fileSystems."/"` (label `NIXOS_SD`, ext4) — tells NixOS where root lives for mount ordering at activation. Label-based lookup works regardless of boot medium (SD card `mmcblk0`, USB `sda`, etc.).

### Why no nixos-hardware

The nixos-hardware `raspberry-pi-5` profile swaps in the downstream vendor `linux-rpi` kernel. That kernel isn't cached on cache.nixos.org or any Hydra jobset — building it requires compiling the full vendor kernel from source. For a headless bootstrap image and headless server, the mainline kernel already boots Pi 5 fine. Dead weight at the cost of hours of compile time. Add nixos-hardware back only for graphics/RP1 edge cases.

## Removing passwordless sudo (post-bootstrap)

`pi5-common.nix` has `security.sudo.wheelNeedsPassword = false` for bootstrap convenience. After your Pi is stable, set up agenix or sops-nix for secret management.