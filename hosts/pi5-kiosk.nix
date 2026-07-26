{ ... }:

{
  imports = [ ../modules/pi5-common.nix ];

  networking.hostName = "pi5-kiosk";

  # TODO: kiosk display / browser config
}
