{ pkgs, ... }:

{
  # Mainline kernel — cached, builds fast. Overrides the nixos-hardware vendor pin.
  boot.kernelPackages = pkgs.linuxPackages;

  # Not set by the nixos-hardware profile; required for the extlinux boot flow.
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

  environment.systemPackages = with pkgs; [ git vim ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Needed for `nixos-rebuild switch --target-host` to accept unsigned closures
  nix.settings.trusted-users = [ "myuser" ];

  # TODO: swap for proper secret management post-bootstrap
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
