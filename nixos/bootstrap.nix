{ oracle-suite, monitor-bins }:
{ options, config, lib, pkgs, input, node, ... }: {
  require = [ ((import ./services/oracle-node.nix { name = "spire"; }) { inherit oracle-suite monitor-bins; }) ];
  services.spire = {
    enable = true;
    logLevel = "info";
    staticId = true;
    disableRpc = true;
    internal.logLevel = "error";
  };
}
