{ omnia-module, oracle-suite }:
{ pkgs, config, node, lib, input, options, ... }:
let
  inherit (input) meta;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath ethAddr writeJSON feedEthAddrs genCaps genKeys peerSeed peerId;
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
  spire-config = (lib.importJSON ./spire.json) // {
    ethereum = eth-config;
    feeds = feedEthAddrs input.nodes;
    p2p.privKeySeed = "${peerSeed node}";
    p2p.listenAddrs = [ "/ip4/0.0.0.0/tcp/${toString node.spire_port}" ];
    p2p.directPeersAddrs =
      [ "/ip4/${input.nodes.bb_0.ip}/tcp/${toString input.nodes.bb_0.spire_port}/p2p/${peerId input.nodes.bb_0}" ];
    p2p.disableDiscovery = true;
  };
in {
  require = [ omnia-module (import ./omnia-ssb.nix { inherit oracle-suite; }) ];

  networking.firewall.allowedTCPPorts = [ node.spire_port ];
  services.omnia = {
    enable = true;
    mode = "feed";
    options = {
      debug = false;
      verbose = true;
      interval = 60;
      spireConfig = writeJSON "spire.json" spire-config;
    };
    ethereum = eth-config;
    sources = [ "gofer" ];
    transports = [ "transport-spire" ];
  };
}
