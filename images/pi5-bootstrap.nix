{ modulesPath, ... }:

{
  imports = [
    ../modules/pi5-common.nix
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  networking.hostName = "pi5";
}
