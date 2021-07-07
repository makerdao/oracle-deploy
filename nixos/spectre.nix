{ oracle-suite, monitor-bins }:
{ options, config, lib, pkgs, input, node, ... }:
let
  util = pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  };
in {
  require = [ ((import ./services/oracle-node.nix { name = "spectre"; }) { inherit oracle-suite monitor-bins; }) ];
  services.spectre = {
    enable = true;
    logLevel = "info";
    internal.logLevel = "error";
    staticId = true;
    bootstrapAddrs = [
      "/ip4/${input.nodes.boot_0.ip}/tcp/${toString input.nodes.boot_0.spire_port}/p2p/${
        util.peerId input.nodes.boot_0
      }"
    ];
    ethereumRpc = "http://${input.nodes.eth_0.ip}:${toString input.nodes.eth_0.eth_rpc_port}";
  };
}
