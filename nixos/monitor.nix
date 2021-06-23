{ monitor-bins, ssb-server, oracle-suite }:
{ pkgs, config, lib, node, input, ... }:
let
  inherit (input) meta;
  cfg = config.services.monitor;
  inherit (pkgs.callPackages ./util.nix {
    inherit oracle-suite;
    inherit input;
  })
    nodeSecretPath envSecretPath feedEthAddrs ethAddr writeJSON genCaps genKeys peerId genSsb feedIds bootstrapAddrs
    peerSeed;
  sec = p: {
    path = nodeSecretPath node p;
    user = cfg.user;
    group = cfg.group;
  };
  gofer-config = ./gofer.json;
  keys = genKeys node;
  caps = genCaps node;
  ssb = genSsb node;
  addr = "0x${ethAddr node}";
  spire-json = builtins.removeAttrs (lib.importJSON ./spire.json) [ "ethereum" ] // {
    ethereum = {
      from = addr;
      keystore = "${keys}/keystore";
      password = "${keys}/password";
    };
    feeds = feedEthAddrs input.nodes;
    p2p.bootstrapAddrs = [
      "/ip4/${input.nodes.boot_0.ip}/tcp/${toString input.nodes.boot_0.spire_port}/p2p/${peerId input.nodes.boot_0}"
    ];
    p2p.privKeySeed = "${peerSeed node}";
  };
  spire-config = writeJSON "spire.json" spire-json;
in with lib; {
  imports = [ (import ./ssb-server.nix { inherit ssb-server; }) ];

  options.services.monitor = {
    enable = mkEnableOption "Oracle Monitor";
    user = mkOption {
      type = types.str;
      default = "monitor";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
    };
    contracts = mkOption {
      type = types.listOf types.attrs;
      default = importJSON ./contracts.json;
    };
    feeds = mkOption {
      type = types.listOf types.attrs;
      default = feedIds input.nodes;
    };
    ethRpcUrl = mkOption { type = types.str; };
    graphiteUrl = mkOption { type = types.str; };
    graphiteApiKeyFile = mkOption { type = types.str; };
    intervalSeconds = mkOption {
      type = types.int;
      default = 60;
    };
    env = mkOption { type = types.str; };
    node = mkOption { type = types.str; };
    probeAll = mkOption {
      type = types.bool;
      default = false;
    };
    enableSsb = mkOption {
      type = types.bool;
      default = false;
    };
    enableGofer = mkOption {
      type = types.bool;
      default = false;
    };
    enableSpire = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    users.users."${cfg.user}" = {
      group = cfg.group;
      description = "Oracle Monitor User";
      isSystemUser = true;
      home = "/var/lib/${cfg.user}";
      createHome = true;
    };
    users.groups."${cfg.group}" = { };

    services.ssb-server = mkIf cfg.enableSsb {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      secret = "${ssb}";
      config = {
        caps = importJSON "${caps}";
        connections.incoming.net = [{
          scope = [ "public" "local" ];
          transform = "shs";
          port = node.ssb_port;
          external = node.ip;
        }];
        connections.incoming.ws = [{
          scope = [ "public" "local" ];
          transform = "shs";
          port = 8988;
          external = node.ip;
        }];
      };
    };

    systemd.services.monitor = {
      enable = true;
      description = "Oracle Monitor Service";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${monitor-bins}/bin/run-monitor";
        User = cfg.user;
        Group = cfg.group;
      };
      environment = {
        CONFIG_FILE = pkgs.writeText "oracle-monitor-config.json" (builtins.toJSON cfg);
        GOFER_CONFIG = gofer-config;
        SPIRE_CONFIG = spire-config;
      };
    };

    systemd.timers.monitor = {
      enable = true;
      description = "Oracle Monitor Timer";
      partOf = [ "monitor.service" ];
      wantedBy = [ "timers.target" ];
      after = [ "network.target" ];
      wants = [ "geth-testnet.service" ];
      timerConfig = {
        OnBootSec = cfg.intervalSeconds;
        OnUnitActiveSec = cfg.intervalSeconds;
        AccuracySec = 1;
        Unit = "monitor.service";
      };
    };

    systemd.services.gofer = mkIf cfg.enableGofer {
      enable = true;
      description = "Gofer Server";
      wantedBy = [ "monitor.service" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${oracle-suite}/bin/gofer --config ${gofer-config} agent";
      };
    };

    systemd.services.spire = mkIf cfg.enableSpire {
      enable = true;
      description = "Spire Server";
      wantedBy = [ "monitor.service" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${oracle-suite}/bin/spire --config ${spire-config} agent -v debug";
      };
      environment = {
        GOLOG_LOG_FMT = "nocolor";
        #        GOLOG_LOG_LEVEL = "debug";
      };
    };
  };

}
