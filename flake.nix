{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    # Systems you deploy via `nixos-rebuild switch --flake .#<name>`
    nixosConfigurations = {
      # Example role configs — rename/extend for your own hosts
      pi5-server = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./hosts/pi5-server.nix ];
      };

      pi5-kiosk = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./hosts/pi5-kiosk.nix ];
      };
    };

    # Images you `nix build` and flash — not deployed via nixos-rebuild
    images.pi5-bootstrap =
      (nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./images/pi5-bootstrap.nix ];
      }).config.system.build.sdImage;
  };
}
