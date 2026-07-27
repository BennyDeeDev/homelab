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

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Replace with your own username and SSH public key
  users.users.myuser = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA...your-public-key... you@example.com"
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

  # Needed for `nixos-rebuild switch --target-host` to accept unsigned closures from your build box
  nix.settings.trusted-users = [ "myuser" ];

  # TODO: swap for proper secret management
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
