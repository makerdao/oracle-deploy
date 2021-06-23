let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs { };
  nix = import ./nix { inherit sources; };
in pkgs.mkShell {
  name = "docker-shell";
  buildInputs = with pkgs; [ niv cachix nix.deploy-median nix.geth-testnet ];
  shellHook = ''
    cachix use maker
    cachix use dapp
    cachix use niv
  '';
}
