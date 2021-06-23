{ oracle-suite }:
{ options, config, lib, pkgs, input, node, ... }: {
  require = [ ((import ./services/oracle-node.nix {name="spire";}) { inherit oracle-suite; }) ];
  services.spire = {
    enable = true;
    logLevel = "info";
    staticId = true;
    disableRpc = true;
    internal.logLevel = "error";
  };
}
