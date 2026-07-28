{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }: {
    # Example deployed hosts — fork, rename, extend
    nixosConfigurations.pi5-host-1 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-5
        ./hosts/pi5-host-1.nix
      ];
    };

    nixosConfigurations.pi5-host-2 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-5
        ./hosts/pi5-host-2.nix
      ];
    };

    # One-time flashable bootstrap image with SSH access — no nixos-hardware, fast mainline build
    images.pi5-bootstrap =
      (nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./images/pi5-bootstrap.nix ];
      }).config.system.build.sdImage;
  };
}
