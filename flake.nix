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
      devShell = pkgs.mkShell {
        buildInputs = [
          pkgs.rustup
          pkgs.openssl
          pkgs.git
        ];
        shellHook = ''
          rustup default stable
          rust-analyzer --version 2> /dev/null || rustup component add rust-analyzer
        '';
      };

      packages.default = pkgs.rustPlatform.buildRustPackage {
        pname = "rimap";
        version = "1.0.0";

        src = ./.;

        cargoLock = {
          lockFile = ./Cargo.lock;
        };

        cargoPatches = [];

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl ];

        meta = with pkgs.lib; {
          maintainers = [ maintainers.iruzo ];
          homepage = "https://github.com/iruzo/rimap";
          description = "IMAP downloader";
          license = licenses.mit;
          platforms = platforms.all;
        };
      };

    });
}
