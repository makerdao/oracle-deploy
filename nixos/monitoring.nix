{ oracle-suite, monitor-bins }:
{ options, config, lib, pkgs, input, node, ... }: {
  require = [ ((import ./services/oracle-suite.nix { name = "spire"; }) { inherit oracle-suite monitor-bins; }) ];
  services.spire = {
    enable = true;
    logLevel = "debug";
    internal.logLevel = "debug";
  };
}
