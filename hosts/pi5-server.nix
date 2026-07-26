{ ... }:

{
  imports = [ ../modules/pi5-common.nix ];

  networking.hostName = "pi5-server";

  # TODO: home-assistant, pihole, etc.
}
