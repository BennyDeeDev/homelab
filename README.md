# homelab

NixOS configurations for two Raspberry Pi 5s:

- `pi5-server` — home assistant, pihole, etc.
- `pi5-kiosk` — homelab display kiosk

Both boot from a shared `pi5-bootstrap` image.

## Build the bootstrap image

Build box needs aarch64 emulation registered:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

Then:

```bash
# Builds the Pi 5 bootstrap SD image (.img.zst in result/sd-image/)
nix build .#images.pi5-bootstrap
zstd -d result/sd-image/*.img.zst -o pi5-bootstrap.img
sudo dd if=pi5-bootstrap.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Flash the same image onto both Pis. Uses the mainline Linux kernel (cached on cache.nixos.org), so the build substitutes in under a minute. No nixos-hardware on the bootstrap config because the generic unstable aarch64 SD image already supports Pi 5 (per upstream PR #537862 and the NixOS wiki).

## First boot

```bash
ssh benjamin@pi5.local
```

## Deploy roles

```bash
nixos-rebuild switch --flake .#pi5-server --target-host benjamin@pi5-server.local --use-remote-sudo
nixos-rebuild switch --flake .#pi5-kiosk  --target-host benjamin@pi5-kiosk.local  --use-remote-sudo
```

## Technical notes

### Why pi5-common.nix sets boot loader and root filesystem

Three settings in `pi5-common.nix` exist so `pi5-server` and `pi5-kiosk` can deploy via `nixos-rebuild switch` against a running Pi. `pi5-bootstrap.nix` imports `sd-image-aarch64.nix` from nixpkgs, which sets these already because building a bootable SD image requires them. `pi5-server.nix` and `pi5-kiosk.nix` don't import that module — they're deployed systems, not images — so without these set explicitly they'd fail `nix flake check` on grub/filesystems assertions.

**`boot.loader.grub.enable = false`** — disables GRUB entirely. GRUB assumes a BIOS/UEFI-style firmware handoff to install itself into; the Pi's stock boot chain (VideoCore firmware → `start.elf` → U-Boot → extlinux) has no such layer for it to occupy, regardless of CPU architecture. NixOS defaults `grub.enable = true` (the common case is x86 desktops with real BIOS/UEFI), so on a Pi it must be explicitly turned off, or the grub module's own assertion will demand `grub.devices` be set — a target disk to install GRUB onto, which is meaningless here.

**`boot.loader.generic-extlinux-compatible.enable = true`** — turns on the extlinux bootloader path, which is what actually boots the Pi. During `nixos-rebuild switch`, NixOS regenerates `/boot/extlinux/extlinux.conf` (naming the kernel, initrd, and kernel params for the new generation) **on the ext4 root partition** — not the small FAT firmware partition, which only holds `bootcode.bin`/`start*.elf`/`config.txt`/the U-Boot binary/device trees. U-Boot has its own ext4 driver and reads `extlinux.conf` directly off that root partition (labeled `NIXOS_SD`) once it's running. Without this option enabled, no `extlinux.conf` gets regenerated, so on next reboot U-Boot has no updated menu to read — the Pi boots back into the previous generation.

So the sequence after `nixos-rebuild switch` is: new system closure activated (services started, users updated) → `extlinux.conf` on root regenerated to point at the new kernel + initrd → U-Boot reads the updated menu on next reboot → Pi boots the new generation.

**`fileSystems."/"`** (label `NIXOS_SD`, ext4) — tells NixOS where root lives. Two jobs:

1. **Mount ordering at activation** — NixOS needs to know the right disk is mounted at `/` before writing new store paths or activating a new closure. Without an explicit entry, activation has no root context.
2. **Label-based lookup** — the bootstrap image's ext4 root partition is created with filesystem label `NIXOS_SD` (nixpkgs' `sd-image.nix`, `sdImage.rootVolumeLabel` option, defaults to exactly this string). Referencing it by label instead of raw device name (`/dev/mmcblk0p2`, `/dev/sda2`) means the config works whether you boot from the SD slot or a USB SSD — device names shift with enumeration order, labels are written into the filesystem itself and don't.

### Why no nixos-hardware

The `nixos-hardware` `raspberry-pi-5` profile swaps in the downstream vendor `linux-rpi` kernel. That kernel package lives in the `nixos-hardware` repo, not in nixpkgs proper (nixpkgs explicitly removed its old in-tree Pi kernel packages and redirected users to `nixos-hardware` instead), so it's outside Hydra's build matrix and isn't sitting pre-built on `cache.nixos.org` or any other public cache with a matching derivation hash. Building it means compiling the vendor kernel from source — one documented real-world account had this take **over 5 hours under QEMU emulation without finishing**, versus **~90 minutes building natively on the Pi itself** over SSH. Exact time will vary by hardware and kernel version, but the QEMU-emulation path is the slow one by a wide, confirmed margin, not a minor inconvenience.

For a headless bootstrap image and a headless server, the mainline kernel already boots Pi 5 fine — the vendor profile was dead weight at the cost of that compile time. Add `nixos-hardware` back to a specific role config only if you hit something the mainline kernel genuinely doesn't support yet (RP1-connected display, Bluetooth, camera/`libcamera` — gaps confirmed earlier in this conversation) — and if you do, build it natively on the Pi via `--build-host`, not under emulation.