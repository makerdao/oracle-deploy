{ monitor-bins, name ? "monitoring" }:
{ options, config, lib, pkgs, input, node, ... }:
let
  cfg = config.services.${name};
  settingsFormat = pkgs.formats.json { };
  UCWordName =
    "${lib.strings.toUpper (builtins.substring 0 1 name)}${builtins.substring 1 ((builtins.stringLength name) - 1) name}";
in {
  options.services.${name} = {
    enable = lib.mkEnableOption "Oracle ${UCWordName} Service";
    name = lib.mkOption {
      type = lib.types.str;
      default = name;
    };
    executable = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = cfg.name;
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
    };
    graphiteUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    intervalSeconds = lib.mkOption {
      type = lib.types.int;
      default = 60;
    };
    home = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/${cfg.user}";
    };
    ethRpcUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    grepMessage = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    contracts = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
    };
    vars = lib.mkOption {
      type = lib.types.attrs;
      default = "";
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = {
        graphiteUrl = cfg.graphiteUrl;
        graphiteApiKey =
          lib.removeSuffix "\n" (builtins.readFile (toString /. + input.meta.rootPath + "/secret/graphite_api_key"));
        intervalSeconds = cfg.intervalSeconds;
        env = node.env;
        node = node.name;
        vars = cfg.vars;
        ethRpcUrl = cfg.ethRpcUrl;
        contracts = cfg.contracts;
        grepMessage = cfg.grepMessage;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      group = cfg.group;
      extraGroups = [ "systemd-journal" ];
      description = "Oracle ${UCWordName} User";
      isSystemUser = true;
      home = cfg.home;
      createHome = true;
    };
    users.groups.${cfg.group} = { };
    systemd.services.${name} = {
      enable = true;
      description = "Oracle ${UCWordName}";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${monitor-bins}/bin/${cfg.executable}";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.home;
      };
      environment = {
        CONFIG_FILE = settingsFormat.generate "${node.name}-${cfg.name}.json" cfg.settings;
        GOFER_CONFIG = "/etc/${node.name}-gofer.json";
        SPIRE_CONFIG = "/etc/${node.name}-spire.json";
      };
    };
    systemd.timers.${name} = {
      enable = true;
      description = "Oracle ${UCWordName} Timer";
      partOf = [ "${name}.service" ];
      wantedBy = [ "timers.target" ];
      after = [ "network.target" ];
      timerConfig = {
        OnBootSec = cfg.intervalSeconds;
        OnUnitActiveSec = cfg.intervalSeconds;
        AccuracySec = 1;
        Unit = "${name}.service";
      };
    };
  };
}
