{ omnia-module, oracle-suite, omniaOverride ? { } }:
{ pkgs, config, node, lib, input, options, ... }:
let
  inherit (input) meta;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath ethAddr writeJSON feedEthAddrs genCaps genKeys peerSeed peerId bootMultiAddrs recursiveMerge;
  sec = p: {
    path = nodeSecretPath node p;
    user = "omnia";
    group = "omnia";
  };
  keys = genKeys node;
  caps = genCaps node;
  eth-config = {
    from = "0x${ethAddr node}";
    keystore = "${keys}/keystore";
    password = "${keys}/password";
  };
  default-config = lib.importJSON "${oracle-suite}/config.json";
  spire-config = {
    inherit (default-config) spire ethereum feeds transport;
  } // {
    ethereum = eth-config;
    feeds = feedEthAddrs input.nodes;
    transport.p2p.privKeySeed = "${peerSeed node}";
    transport.p2p.listenAddrs = [ "/ip4/0.0.0.0/tcp/${toString node.spire_port}" ];
    transport.p2p.bootstrapAddrs = bootMultiAddrs input.nodes;
  };
  gofer-config = {
    gofer = {
      rpc = default-config.gofer.rpc;
      priceModels = default-config.gofer.priceModels;
      origins = lib.importJSON (/. + input.meta.rootPath + "/secret/origins.json");
    };
  };
in {
  require = [ omnia-module (import ./omnia-ssb.nix { inherit oracle-suite; }) ];

  networking.firewall.allowedTCPPorts = [ node.spire_port ];
  services.omnia = recursiveMerge [
    {
      enable = true;
      mode = "feed";
      pairs = [ ];
      options = {
        debug = false;
        verbose = true;
        interval = 60;
        spireConfig = writeJSON "spire.json" spire-config;
        goferConfig = writeJSON "gofer.json" gofer-config;
      };
      ethereum = eth-config;
      sources = [ "gofer" "setzer" ];
      transports = [ "transport-spire" ];
    }
    omniaOverride
  ];
}
