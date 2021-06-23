{ sources ? import ./sources.nix, pkgs ? import sources.nixpkgs { }, makerpkgs ? import sources.makerpkgs { } }: rec {
  inherit makerpkgs;
  deploy-median = import ./median { inherit makerpkgs; };
  geth-testnet = pkgs.callPackage ./geth { inherit makerpkgs deploy-median; };
}
