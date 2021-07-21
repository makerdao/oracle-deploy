{ omnia-module, oracle-suite, omniaOverride ? { } }:
{ pkgs, config, input, node, lib, ... }:
let
  inherit (input) meta;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    recursiveMerge nodeSecretPath ethAddr writeJSON feedEthAddrs ethToSsb genCaps genKeys peerId bootstrapAddrs bootMultiAddrs
    peerSeed;
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
    #    network = "http://${input.nodes.eth_0.ip}:${toString input.nodes.eth_0.eth_rpc_port}";
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
in {
  require = [ omnia-module (import ./omnia-ssb.nix { inherit oracle-suite; }) ];

  networking.firewall.allowedTCPPorts = [ node.spire_port ];
  services.omnia = recursiveMerge [
    {
      enable = true;
      mode = "relay";
      options = {
        debug = false;
        verbose = true;
        interval = 60;
        spireConfig = writeJSON "spire.json" spire-config;
      };
      ethereum = eth-config;
      feeds = feedEthAddrs input.nodes;
      transports = [ "transport-spire" ];
      services.scuttlebotIdMap = ethToSsb input.nodes;
      pairs = [ ];
    }
    omniaOverride
  ];
}
