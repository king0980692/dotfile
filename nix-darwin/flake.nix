{
  description = "Leon's nix-darwin configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nix-darwin, nixpkgs }:
  let
    mkSystem = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [ ./configuration.nix ];
    };
  in {
    darwinConfigurations."Leon-mb-air"   = mkSystem;
    darwinConfigurations."Leon-mb-airm4" = mkSystem;
  };
}
