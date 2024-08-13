{
  description = "Rimap";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # DevShell for your project
      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.rustup
          pkgs.rust-analyzer
          pkgs.openssl
          pkgs.git
        ];
        shellHook = ''
          rustup default stable
        '';
      };

    });
}
