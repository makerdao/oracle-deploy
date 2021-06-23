{ oracle-suite }:
{ options, config, lib, pkgs, input, node, ... }:
let
  util = pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  };
in {
  require = [ ((import ./services/oracle-node.nix { name = "spire"; }) { inherit oracle-suite; }) ];
  services.spire = {
    enable = true;
    logLevel = "info";
    staticId = true;
    disableRpc = true;
    internal.logLevel = "error";
    bootstrapAddrs = [
      "/ip4/${input.nodes.boot_0.ip}/tcp/${toString input.nodes.boot_0.spire_port}/p2p/${
        util.peerId input.nodes.boot_0
      }"
    ];
    directPeersAddrs = [
      "/ip4/${input.nodes.feed_lb_0.ip}/tcp/${toString input.nodes.feed_lb_0.spire_port}/p2p/${
        util.peerId input.nodes.feed_lb_0
      }"
    ];
  };
}
