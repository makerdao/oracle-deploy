{ oracle-suite, contracts ? { } }:
{ pkgs, config, input, node, lib, ... }:
let
  inherit (builtins) fromJSON listToAttrs;
  inherit (lib) concatStringsSep concatMapStringsSep importJSON;
  inherit (pkgs) jq;
  inherit (import ../nix) deploy-median makerpkgs;
  inherit (makerpkgs) seth;

  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath feedEthAddrs relayEthAddrs ethAddr genKeys;

  user = "testnet";
  sec = p: {
    path = nodeSecretPath node p;
    user = user;
    group = user;
  };

  addr = ethAddr node;
  keys = genKeys node;
  dataDir = "/var/lib/testnet";
  feeds = concatStringsSep " " (feedEthAddrs input.nodes);

  wats = concatMapStringsSep " " (x: x.wat) contracts;
in {
  require = [ ./geth-testnet.nix ];

  networking.firewall.allowedTCPPorts = [ node.eth_rpc_port ];

  services.geth-testnet = {
    enable = true;
    inherit user dataDir;
    rpcPort = node.eth_rpc_port;
    account = addr;
    accountBalances = listToAttrs (map (a: {
      name = a;
      value = "0xffffffffffffffffffffffffffffffff";
    }) (relayEthAddrs input.nodes));
    keystore = "${keys}/keystore";
    passwordFile = "${keys}/password";

    initScript = ''
      ${deploy-median}/bin/deploy-median ${feeds} ${wats}
    '';
    initOutput = "${dataDir}/median.json";
  };
}
