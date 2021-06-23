{ oracle-suite }:
{ pkgs, config, input, node, lib, ... }:
let
  inherit (lib) importJSON;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath envSecretPath genCaps genSsb;

  sec = p: {
    path = nodeSecretPath node p;
    user = "omnia";
    group = "omnia";
  };

  caps = genCaps node;
  ssb = genSsb node;
in {
  services.omnia.ssbConfig = {
    caps = importJSON "${caps}";
    connections.incoming.net = [{
      scope = [ "public" "local" ];
      transform = "shs";
      port = node.ssb_port;
      external = node.ip;
    }];
    connections.incoming.ws = [{
      scope = [ "public" "local" ];
      transform = "shs";
      port = 8988;
      external = node.ip;
    }];
  };
  services.omnia.ssbInitSecret = "${ssb}";
}
