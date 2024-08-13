{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.rustup
    pkgs.rust-analyzer
    pkgs.openssl
    pkgs.git
  ];

  shellHook = ''
    rustup default stable
  '';
}
