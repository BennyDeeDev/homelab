{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosConfigurations = {
        pi5-server = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./hosts/pi5-server.nix ];
        };

        pi5-kiosk = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./hosts/pi5-kiosk.nix ];
        };
      };

      images.pi5-bootstrap =
        (nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [ ./images/pi5-bootstrap.nix ];
        }).config.system.build.sdImage;
    };
}
