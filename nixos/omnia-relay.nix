{ omnia-module, oracle-suite }:
{ pkgs, config, input, node, lib, ... }:
let
  inherit (input) meta;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath ethAddr writeJSON feedEthAddrs ethToSsb genCaps genKeys peerId bootstrapAddrs peerSeed;
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
    network = "http://${input.nodes.eth_0.ip}:${toString input.nodes.eth_0.eth_rpc_port}";
  };
  spire-config = (lib.importJSON ./spire.json) // {
    ethereum = eth-config;
    feeds = feedEthAddrs input.nodes;
    p2p.bootstrapAddrs = [
      "/ip4/${input.nodes.boot_0.ip}/tcp/${toString input.nodes.boot_0.spire_port}/p2p/${peerId input.nodes.boot_0}"
    ];
    p2p.privKeySeed = "${peerSeed node}";
  };
in {
  require = [ omnia-module (import ./omnia-ssb.nix { inherit oracle-suite; }) ];

  networking.firewall.allowedTCPPorts = [ node.spire_port ];
  services.omnia = {
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
    pairs = builtins.listToAttrs (map (a: {
      name = a.wat;
      value = {
        oracle = a.address;
        oracleSpread = 0.5;
        oracleExpiration = 600;
        msgExpiration = 1800;
      };
    }) (lib.importJSON ./contracts.json));
  };
}
