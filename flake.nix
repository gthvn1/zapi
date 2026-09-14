{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zig }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.${system}.default = pkgs.mkShell {
          packages = [
            zig.packages.${system}."0.16.0"
            pkgs.zls_0_16
          ];
        };
      };
}
