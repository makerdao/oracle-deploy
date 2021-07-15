{ ssb-server }:
{ pkgs, config, lib, ... }:
let
  cfg = config.services.ssb-server;

  incomingPorts = (if (cfg.config ? connections) then
    (if (cfg.config.connections ? incoming && cfg.config.connections.incoming ? net) then
      map (x: if (x ? port) then x.port else 8008) cfg.config.connections.incoming.net
    else
      [ 8008 ])
  else
    (if (cfg.config ? port) then [ cfg.config.port ] else [ 8008 ]));

  writeJSON = name: attrs: pkgs.writeText name (builtins.toJSON attrs);
  ssb-config = writeJSON "ssb-config" cfg.config;
in with lib;
with types; {
  options.services.ssb-server = {
    enable = mkEnableOption "SSB Server";

    user = mkOption {
      type = str;
      default = "ssb-server";
    };
    group = mkOption {
      type = str;
      default = cfg.user;
    };
    home = mkOption {
      type = path;
      default = "/var/lib/${cfg.user}";
    };

    config = mkOption {
      type = attrs;
      description = ''
        Scuttlebot config
      '';
    };

    secret = mkOption {
      type = nullOr path;
      description = ''
        Scuttlebot secret, if null will generate one
      '';
      default = null;
    };

    gossip = mkOption {
      type = nullOr path;
      description = ''
        gossip.json file to init scuttlebot with
      '';
      default = null;
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ ssb-server ];
    networking.firewall.allowedTCPPorts = incomingPorts;
    systemd.services.ssb-server = {
      enable = true;

      description = "Scuttlebot Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.home;
        PermissionsStartOnly = true;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${ssb-server}/bin/ssb-server start";
      };

      preStart = ''
        installSsbFile() {
          local from="$1"
          local target="${cfg.home}/.ssb/$2"
          if [[ ! -e "$target" ]]; then
            echo >&2 "SSB Service Setup: $target not found! Initiallizing with $from -> $target"
            cp -f "$from" "$target"
          else
            echo >&2 "SSB Service Setup: $target exists! Not overwriting"
          fi
        }

        mkdir -p "${cfg.home}/.ssb"
      '' + (optionalString (cfg.secret != null) ''
        installSsbFile "${cfg.secret}" "secret"
      '') + (optionalString (cfg.gossip != null) ''
        installSsbFile "${cfg.gossip}" "gossip.json"
      '') + ''
        ln -sf "${ssb-config}" "${cfg.home}/.ssb/config"
        chown -R ${cfg.user}:${cfg.group} "${cfg.home}/.ssb"
        chmod -R ug+w "${cfg.home}/.ssb"
      '';
    };
  };
}
