{ lib, pkgs, oracle-suite, input }:
let
  nodes = input.nodes;
  mapNodes = f: m: nodes:
    builtins.filter (x: x != null) (lib.attrValues (builtins.mapAttrs (k: v: if (f v) then m v else null) nodes));

  mapFeeds = mapNodes (n: lib.strings.hasPrefix "feed_" n.name || lib.strings.hasPrefix "ghost_" n.name);
  mapRelays = mapNodes (n: lib.strings.hasPrefix "relay_" n.name || lib.strings.hasPrefix "spectre_" n.name);
  mapEths = mapNodes (n: lib.strings.hasPrefix "eth_" n.name);

  hd_seed = /. + input.meta.rootPath + "/secret/hd_seed";

  nodeRoles = {
    "eth" = 0;
    "boot" = 1;
    "feed" = 2;
    "feed_lb" = 3;
    "bb" = 4;
    "relay" = 5;
    "spectre" = 6;
    "ghost" = 7;
  };
  nodeRole = n: toString nodeRoles.${n.type};
in rec {
  nodeSecretPath = node: p: "${toString /. + input.meta.rootPath + "/secret"}/${node.name}/${p}";
  writeJSON = name: attrs: pkgs.writeText name (builtins.toJSON attrs);
  ethAddr = n:
    (lib.importJSON "${genKeys n}/keystore/${toString n.env_idx}-${nodeRole n}-${toString n.idx}.json").address;
  peerId = n: (lib.importJSON "${genPeer n}").id;
  peerSeed = n: (lib.importJSON "${genPeer n}").seed;
  ssbId = n: (lib.importJSON "${genSsb n}").id;

  feedIds = mapFeeds (n: {
    ssb = ssbId n;
    eth = "0x${ethAddr n}";
  });
  feedEthAddrs = mapFeeds (n: "0x${ethAddr n}");
  relayEthAddrs = mapRelays (n: "0x${ethAddr n}");

  ethToSsb = nodes:
    builtins.listToAttrs (map (a: {
      name = a.eth;
      value = a.ssb;
    }) (mapFeeds (n: {
      ssb = ssbId n;
      eth = "0x${ethAddr n}";
    }) nodes));

  genCaps = n:
    pkgs.stdenv.mkDerivation {
      name = "${toString n.env_idx}-caps.json";
      src = ./.;
      buildInputs = [ oracle-suite pkgs.jq ];
      installPhase = ''
        set -e
        cat ${hd_seed} | keeman derive --verbose --env ${toString n.env_idx} \
        | jq '.caps' -c > $out
      '';
      fixupPhase = "true";
    };

  genKeys = n:
    pkgs.stdenv.mkDerivation {
      name = "${toString n.env_idx}-${nodeRole n}-${toString n.idx}-ethereum";
      src = ./.;
      buildInputs = [ oracle-suite pkgs.jq ];
      installPhase = ''
        set -e
        mkdir -p $out/keystore
        echo "" > $out/password
        cat ${hd_seed} | keeman derive --verbose --env ${toString n.env_idx} --role ${nodeRole n} --node ${
          toString n.idx
        } \
        | jq '.eth.keystore' -c > "$out/keystore/${toString n.env_idx}-${nodeRole n}-${toString n.idx}.json"
      '';
      fixupPhase = "true";
    };

  genPeer = n:
    pkgs.stdenv.mkDerivation {
      name = "${toString n.env_idx}-${nodeRole n}-${toString n.idx}-p2p.json";
      src = ./.;
      buildInputs = [ oracle-suite pkgs.jq ];
      installPhase = ''
        set -e
        cat ${hd_seed} | keeman derive --verbose --env ${toString n.env_idx} --role ${nodeRole n} --node ${
          toString n.idx
        } \
        | jq '.p2p' -c > $out
      '';
      fixupPhase = "true";
    };

  genSsb = n:
    pkgs.stdenv.mkDerivation {
      name = "${toString n.env_idx}-${nodeRole n}-${toString n.idx}-ssb.json";
      src = ./.;
      buildInputs = [ oracle-suite pkgs.jq ];
      installPhase = ''
        set -e
        cat ${hd_seed} | keeman derive --verbose --env ${toString n.env_idx} --role ${nodeRole n} --node ${
          toString n.idx
        } \
        | jq '.ssb' -c > $out
      '';
      fixupPhase = "true";
    };
}
