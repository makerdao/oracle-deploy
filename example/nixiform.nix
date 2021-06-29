let inherit (import ./nix) pkgs omnia-module nixiform oracle-suite monitor-bins ssb-server oracle-deploy;
in input:
let
  empty = { ... }: { };

  common = config:
    { ... }: {
      require = [ config "${oracle-deploy}/nixos/common.nix" ]
        ++ pkgs.lib.optional input.meta.cloudwatch "${oracle-deploy}/nixos/journald-cloudwatch-logs.nix";
    };

  eth = common {
    require = [
      (import "${oracle-deploy}/nixos/oracle-monitor.nix" { inherit monitor-bins ssb-server oracle-suite; })
      (import "${oracle-deploy}/nixos/testnet.nix" { inherit oracle-suite; })
    ];
  };

  feed = common {
    require = [
      (import "${oracle-deploy}/nixos/oracle-monitor.nix" { inherit monitor-bins ssb-server oracle-suite; })
      (import "${oracle-deploy}/nixos/omnia-feed.nix" { inherit omnia-module oracle-suite; })
    ];
  };

  feed_lb = common {
    require = [
      (import "${oracle-deploy}/nixos/oracle-monitor.nix" { inherit monitor-bins ssb-server oracle-suite; })
      (import "${oracle-deploy}/nixos/feed_lb.nix" { inherit omnia-module oracle-suite; })
    ];
  };

  relay = common {
    require = [
      (import "${oracle-deploy}/nixos/oracle-monitor.nix" { inherit monitor-bins ssb-server oracle-suite; })
      (import "${oracle-deploy}/nixos/omnia-relay.nix" { inherit omnia-module oracle-suite; })
    ];
  };

  bb = common { require = [ (import "${oracle-deploy}/nixos/bb.nix" { inherit oracle-suite monitor-bins; }) ]; };
  boot =
    common { require = [ (import "${oracle-deploy}/nixos/bootstrap.nix" { inherit oracle-suite monitor-bins; }) ]; };
  ghost = common { require = [ (import "${oracle-deploy}/nixos/ghost.nix" { inherit oracle-suite monitor-bins; }) ]; };
  spectre =
    common { require = [ (import "${oracle-deploy}/nixos/spectre.nix" { inherit oracle-suite monitor-bins; }) ]; };
in pkgs.lib.mapAttrs (k: v:
  if v.type == "eth" then
    eth
  else if v.type == "feed" then
    feed
  else if v.type == "feed_lb" then
    feed_lb
  else if v.type == "bb" then
    bb
  else if v.type == "relay" then
    relay
  else if v.type == "boot" then
    boot
  else if v.type == "ghost" then
    ghost
  else if v.type == "spectre" then
    spectre
  else
    empty) input.nodes
