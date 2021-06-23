{ sources ? import ./nix/sources.nix, pkgs ? import sources.nixpkgs { } }:
pkgs.mkShell rec {
  name = "oracle-shell";

  buildInputs = with pkgs; [ niv git git-crypt cachix ];

  shellHook = ''
    cachix use maker
    cachix use dapp
    cachix use niv
  '';
}
