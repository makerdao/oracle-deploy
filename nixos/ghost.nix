{ oracle-suite, monitor-bins }:
{ options, config, lib, pkgs, input, node, ... }:
let
  util = pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  };
in {
  require = [ ((import ./services/oracle-suite.nix { name = "ghost"; }) { inherit oracle-suite monitor-bins; }) ];
  services.ghost = {
    enable = true;
    logLevel = "info";
    internal.logLevel = "error";
    staticId = true;
    bootstrapAddrs =
      [ "/ip4/${input.nodes.boot_0.ip}/tcp/${toString input.nodes.boot_0.spire_port}/p2p/${util.peerId input.nodes.boot_0}" ];
  };
}
