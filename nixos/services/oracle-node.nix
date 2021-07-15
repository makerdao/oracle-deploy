{ name, app ? name }:
{ oracle-suite, monitor-bins }:
{ options, config, lib, pkgs, input, node, ... }:
let
  util = pkgs.callPackages ../util.nix {
    inherit oracle-suite;
    inherit input;
  };
  cfg = config.services.${name};
  settingsFormat = pkgs.formats.json { };
  UCWordName =
    "${lib.strings.toUpper (builtins.substring 0 1 name)}${builtins.substring 1 ((builtins.stringLength name) - 1) name}";
  secretOriginsJSON = /. + input.meta.rootPath + "/secret/origins.json";
in {
  options.services.${name} = {
    enable = lib.mkEnableOption "${UCWordName} Service";
    name = lib.mkOption {
      type = lib.types.str;
      default = name;
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = cfg.name;
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
    };
    ip4Addr = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
    tcpPort = lib.mkOption {
      type = lib.types.port;
      default = 44008;
    };
    staticId = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "info";
    };
    logFormat = lib.mkOption {
      type = lib.types.str;
      default = "json";
    };
    internal.logLevel = lib.mkOption {
      type = lib.types.str;
      default = "error";
    };
    internal.logFormat = lib.mkOption {
      type = lib.types.str;
      default = "nocolor";
    };
    disableDiscovery = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    disableRpc = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    rpcAddr = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    rpcPort = lib.mkOption {
      type = lib.types.port;
      default = 9000;
    };
    bootstrapAddrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    feeds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = util.feedEthAddrs input.nodes;
    };
    symbols = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = map (a: a.wat) (lib.importJSON ../contracts.json);
    };
    directPeersAddrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    ethereumRpc = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    monitorSettings = lib.mkOption {
      type = settingsFormat.type;
      default = {
        graphiteUrl = "https://graphite-us-central1.grafana.net/metrics";
        graphiteApiKeyFile = config.nixiform.filesOut.graphiteApiKeyFile;
        intervalSeconds = 60;
        env = node.env;
        node = node.name;
      };
    };
    # https://nixos.org/manual/nixos/stable/#sec-settings-nix-representable
    settings = lib.mkOption {
      type = settingsFormat.type;
      default = lib.importJSON "${oracle-suite}/config.json" // {
        ethereum = {
          from = "0x${util.ethAddr node}";
          keystore = "${util.genKeys node}/keystore";
          password = "${util.genKeys node}/password";
          rpc = lib.mkIf (cfg.ethereumRpc != "") cfg.ethereumRpc;
        };
        feeds = cfg.feeds;
        spire = {
          rpc = {
            address = lib.mkIf (!cfg.disableRpc) "${cfg.rpcAddr}:${toString cfg.rpcPort}";
            disable = cfg.disableRpc;
          };
          pairs = cfg.symbols;
        };
        ghost = {
          rpc = {
            address = lib.mkIf (!cfg.disableRpc) "${cfg.rpcAddr}:${toString cfg.rpcPort}";
            disable = cfg.disableRpc;
          };
          pairs = cfg.symbols;
        };
        transport = {
          p2p = {
            listenAddrs = [ "/ip4/${cfg.ip4Addr}/tcp/${toString cfg.tcpPort}" ];
            privKeySeed = lib.mkIf cfg.staticId "${util.peerSeed node}";
            disableDiscovery = cfg.disableDiscovery;
            bootstrapAddrs = cfg.bootstrapAddrs;
            directPeersAddrs = cfg.directPeersAddrs;
          };
        };
        gofer.origins.openexchangerates = {
          name = "openexchangerates";
          type = "openexchangerates";
          params = (lib.importJSON secretOriginsJSON).openexchangerates;
        };
        spectre.medianizers = builtins.listToAttrs (map (a: {
          name = a.wat;
          value = {
            oracle = a.address;
            oracleSpread = 0.5;
            oracleExpiration = 600;
            msgExpiration = 1800;
          };
        }) (lib.importJSON ../contracts.json));
      };
    };
  };

  config = lib.mkIf cfg.enable rec {
    networking.firewall.allowedTCPPorts = [ cfg.tcpPort ];

    environment.etc."${node.name}-${cfg.name}.json" = {
      source = settingsFormat.generate "${node.name}-${cfg.name}.json" cfg.settings; # insecure
      mode = "0400";
      user = cfg.user;
      group = cfg.group;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg.group} = { };

    systemd.services.${cfg.name} = {
      enable = true;
      description = "${UCWordName} Agent";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${
            pkgs.writeShellScriptBin "start" ''
              set -euo pipefail
              ${oracle-suite}/bin/${app} \
                --config /etc/${node.name}-${cfg.name}.json \
                --log.verbosity ${cfg.logLevel} \
                --log.format ${cfg.logFormat} \
                agent 2>&1 | tee >(cat >&2) | ${monitor-bins}/bin/consume-spire-log /etc/${node.name}-${cfg.name}-monitoring.json
            ''
          }/bin/start";
      };
      environment = {
        GOLOG_LOG_LEVEL = cfg.internal.logLevel;
        GOLOG_LOG_FMT = cfg.internal.logFormat;
      };
    };

    nixiform.filesIn.graphiteApiKeyFile = {
      path = toString /. + input.meta.rootPath + "/secret/graphite_api_key";
      user = cfg.user;
      group = cfg.group;
    };
    environment.etc."${node.name}-${cfg.name}-monitoring.json" = {
      source = settingsFormat.generate "${node.name}-${cfg.name}-monitoring.json" cfg.monitorSettings; # insecure
      mode = "0400";
      user = cfg.user;
      group = cfg.group;
    };
  };
}
