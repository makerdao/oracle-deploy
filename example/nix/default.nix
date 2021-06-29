let
  oracle-deploy = ../../oracle-deploy;
  super = import "${oracle-deploy}/nix";
  sources = import ./sources.nix;
  oracles-v2 = import sources.oracles-v2 { };
in super // rec {
  inherit oracle-deploy;
  inherit (super) pkgs shell nixiform;
  inherit (oracles-v2) ssb-server;
  oracle-suite = import sources.oracle-suite { buildGoModule = super.nixmaster.buildGo116Module; };
  omnia-module = (import "${sources.oracles-v2}/nixos") { inherit oracle-suite; };
  oracle-bins = super.oracle-bins.override { inherit ssb-server; };
  monitor-bins = super.monitor-bins.override { inherit ssb-server oracle-suite; };
}
