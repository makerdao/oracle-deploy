{ config, pkgs, lib, ... }:
let
  inherit (import ../nix) bins makerpkgs;
  inherit (makerpkgs) seth;

  inherit (builtins) toJSON;
  inherit (lib) mkEnableOption mkIf mkOption types optionalString
    concatStringsSep makeBinPath mapAttrs;

  cfg = config.services.geth-testnet;

  chainId = 99;

  accounts = mapAttrs (k: v: { balance = v; }) cfg.accountBalances;

  genesis = pkgs.writeText "genesis.json" (toJSON {
    alloc = {
      "0x${cfg.account}" = {
        balance = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
      };
    } // accounts;
    config = {
      byzantiumBlock = 0;
      chainId = chainId;
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
    extraData = "0x3132333400000000000000000000000000000000000000000000000000000000${cfg.account}0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    gaslimit = "0xffffffffffffffff";
  });

in {
  options = {
    services.geth-testnet = {
      enable = mkEnableOption "Dapp testnet using geth";

      user = mkOption {
        type = types.str;
        default = "testnet";
        description = "The user as which to run quorum.";
      };

      group = mkOption {
        type = types.str;
        default = cfg.user;
        description = "The group as which to run quorum.";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/testnet";
        description = "Data dir for geth.";
      };

      rpcPort = mkOption {
        type = types.int;
        default = 22003;
        description = "RPC port to listen on.";
      };

      rpcAddr = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "RPC address to listen on.";
      };

      account = mkOption {
        type = types.str;
        description = "Init account address.";
      };

      accountBalances = mkOption {
        type = types.attrs;
        default = {};
        description = "Account to balance map.";
      };

      keystore = mkOption {
        type = types.path;
        description = "Keystore.";
      };

      passwordFile = mkOption {
        type = types.path;
        description = "Password file to unlock keystore with.";
      };

      initScript = mkOption {
        type = types.str;
        default = "";
        description = "Script to run after new blockchain.";
      };

      initOutput = mkOption {
        type = types.path;
        default = "${cfg.dataDir}/.init";
        description = "File that determins if init script should be run again.";
      };
    };
  };

  config = mkIf cfg.enable {
    #environment.systemPackages = deps;
    #systemd.tmpfiles.rules = [
    #  "d '${cfg.dataDir}' 0770 '${cfg.user}' '${cfg.group}' - -"
    #];

    systemd.services.geth-testnet = {
      description = "Dapp testnet (geth)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        set -ex

        mkdir -p "${cfg.dataDir}"
        ln -sfT "${cfg.keystore}" "${cfg.dataDir}"/keystore

        if [[ "$(realpath "${cfg.dataDir}"/genesis.json)" != "${genesis}" ]]; then
          ln -sfT "${genesis}" "${cfg.dataDir}"/genesis.json
          ${pkgs.go-ethereum}/bin/geth \
            --datadir "${cfg.dataDir}" init "${cfg.dataDir}"/genesis.json
        fi
      '';

      script = ''
        set -ex

        ${pkgs.go-ethereum}/bin/geth \
          --datadir "${cfg.dataDir}" --networkid "${toString chainId}" \
          --port="${toString (cfg.rpcPort + 30000)}" \
          --mine --minerthreads=1 --allow-insecure-unlock \
          --rpc --rpcapi "web3,eth,net,debug,personal" \
          --rpccorsdomain '*' --nodiscover \
          --rpcaddr="${cfg.rpcAddr}" --rpcport="${toString cfg.rpcPort}" \
          --unlock="0x${cfg.account}" \
          --password="${cfg.passwordFile}"
      '';

      postStart = optionalString (cfg.initScript != "") ''
        set -ex

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

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        #Environment = ''"PATH=${makeBinPath deps}"'';
        Restart = "on-failure";

        # Hardening measures
        #PrivateTmp = "true";
        #ProtectSystem = "full";
        #NoNewPrivileges = "true";
        #PrivateDevices = "true";
        #MemoryDenyWriteExecute = "true";
      };
    };
    users.users.${cfg.user} = {
      name = cfg.user;
      group = cfg.group;
      description = "Geth daemon user";
      home = cfg.dataDir;
      isSystemUser = true;
      createHome = true;
    };
    users.groups.${cfg.group} = {};
  };
}
