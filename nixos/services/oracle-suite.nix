{ oracle-suite, monitor-bins, name, app ? name }:
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
    enable = lib.mkEnableOption "Oracle ${UCWordName} Service";
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
      default = util.bootMultiAddrs input.nodes;
    };
    feeds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = util.feedEthAddrs input.nodes;
    };
    contracts = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
    };
    directPeersAddrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    ethereumRpc = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
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
          pairs = map (a: a.wat) cfg.contracts;
        };
        ghost = {
          rpc = {
            address = lib.mkIf (!cfg.disableRpc) "${cfg.rpcAddr}:${toString cfg.rpcPort}";
            disable = cfg.disableRpc;
          };
          pairs = map (a: a.wat) cfg.contracts;
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
        gofer.origins = lib.importJSON secretOriginsJSON; # this clears price models
        spectre.medianizers = builtins.listToAttrs (map (a: {
          name = a.wat;
          value = {
            oracle = a.address;
            oracleSpread = 0.5;
            oracleExpiration = 600;
            msgExpiration = 1800;
          };
        }) cfg.contracts);
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
      description = "Oracle ${UCWordName} Agent";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 5;
        ExecStart = ''
          ${oracle-suite}/bin/${app} \
          --config /etc/${node.name}-${cfg.name}.json \
          --log.verbosity ${cfg.logLevel} \
          --log.format ${cfg.logFormat} \
          agent'';
      };
      environment = {
        GOLOG_LOG_LEVEL = cfg.internal.logLevel;
        GOLOG_LOG_FMT = cfg.internal.logFormat;
      };
    };
  };
}
