{ pkgs, lib, deploy-median, makerpkgs }:

with lib;
with builtins;
let
  shellEscape = s: (replaceStrings [ "\\" ] [ "\\\\" ] s);

  feeds = concatStringsSep " " [
    "32fe61f9b1820e95de38fb75a7709f2c8a35a01b"
    "b4fde1e4e7f5fd38658c8456bb3e1f51f6c6c994"
    "b0b54abeebb69c9d778e0f78b46469230839974e"
  ];

  symbols = concatStringsSep " " [ "BTCUSD" "ETHUSD" ];

  cfg = {
    chainId = 99;
    dataDir = ".testnet";
    rpcPort = 8787;
    rpcAddr = "0.0.0.0";
    account = "dea2026d01a2aa50a80407dc90c620ca3d11b881";
    accountBalances = mapAttrs (k: v: { balance = v; }) {
      "0x${cfg.account}" = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
      "0x3d9d36f036a070e7ee8f13c13ba7f34afce185e4" = "0xffffffffffffffffffffffffffffffff";
      "0xf2772cbb92f520b6846ad05e02fc24ffc06955df" = "0xffffffffffffffffffffffffffffffff";
    };
    keystoreDir = ../../../secret/eth_0/eth/keystore;
    passwordFile = pkgs.writeText "keystore-password" "";
    initScript = ''
      ${deploy-median}/bin/deploy-median ${feeds} ${symbols}
    '';
  };
  cfg.initOutput = "${cfg.dataDir}/median.json";

  inherit (makerpkgs) seth;
  genesis = pkgs.writeText "genesis.json" (toJSON {
    alloc = cfg.accountBalances;
    config = {
      byzantiumBlock = 0;
      chainId = cfg.chainId;
      clique = {
        epoch = 3000;
        period = 0;
      };
      constantinopleBlock = 0;
      eip150Block = 0;
      eip155Block = 0;
      eip158Block = 0;
      eip160Block = 0;
      homesteadBlock = 0;
      istanbulBlock = 0;
      petersburgBlock = 0;
    };
    difficulty = "0x1";
    extraData =
      "0x3132333400000000000000000000000000000000000000000000000000000000${cfg.account}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    gaslimit = "0xffffffffffffffff";
  });

  script = pkgs.writeShellScriptBin "run-geth-testnet" ''
    set -u -e -o pipefail

    mkdir -p "${cfg.dataDir}"

    ln -sfT "${cfg.keystoreDir}" "${cfg.dataDir}"/keystore

    if [[ "$(realpath "${cfg.dataDir}"/genesis.json)" != "${genesis}" ]]; then
      ln -sfT "${genesis}" "${cfg.dataDir}"/genesis.json
      ${pkgs.go-ethereum}/bin/geth \
        --datadir "${cfg.dataDir}" init "${cfg.dataDir}"/genesis.json
    fi

    ${pkgs.go-ethereum}/bin/geth \
      --datadir "${cfg.dataDir}" --networkid "${toString cfg.chainId}" \
      --port="${toString (cfg.rpcPort + 30000)}" \
      --mine --miner.threads=1 --allow-insecure-unlock \
      --rpc --rpcapi "web3,eth,net,debug,personal" \
      --rpccorsdomain '*' --nodiscover \
      --rpcaddr="${cfg.rpcAddr}" --rpcport="${toString cfg.rpcPort}" \
      --unlock="0x${cfg.account}" \
      --password="${cfg.passwordFile}"

    if [[ ! -f "${cfg.initOutput}" ]]; then
      export ETH_GAS=7000000
      export ETH_RPC_URL=http://127.0.0.1:${toString cfg.rpcPort}

      until ${seth}/bin/seth balance 0x${cfg.account}; do sleep 5; done

      export ETH_KEYSTORE="${cfg.dataDir}/keystore"
      export ETH_FROM="0x${cfg.account}"
      export ETH_PASSWORD="${cfg.passwordFile}"

      if initOut=$(${cfg.initScript}); then
        printf %s "$initOut" > "${cfg.initOutput}"
      fi
    fi
  '';
in script
