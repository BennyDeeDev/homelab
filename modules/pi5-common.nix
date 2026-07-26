{ pkgs, lib, ... }:

{
  # pi5-bootstrap gets these from sd-image-aarch64.nix; pi5-server/pi5-kiosk need them
  # here because they don't import the sd-image module (they're deployed systems, not images).
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.useDHCP = lib.mkDefault true;

  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.workstation = true;
    nssmdns4 = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.benjamin = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHW2qr7cup1ALuIpnhUoJP8dLjv/yhGfuh/1Vni2lSbd"
    ];
  };

  programs.zsh.enable = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
