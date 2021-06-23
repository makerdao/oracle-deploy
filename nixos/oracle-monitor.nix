{ monitor-bins, ssb-server, oracle-suite }:
{ config, node, input, ... }: {
  require = [ (import ./monitor.nix { inherit monitor-bins ssb-server oracle-suite; }) ];

  services.monitor = {
    enable = true;
    ethRpcUrl = if node.name == "eth_0" then "http://localhost:${toString node.eth_rpc_port}" else "";
    graphiteUrl = "https://graphite-us-central1.grafana.net/metrics";
    graphiteApiKeyFile = config.nixiform.filesOut.graphiteApiKeyFile;
    env = node.env;
    node = node.name;
    probeAll = if node.name == "eth_0" then true else false;
    enableSsb = if node.name == "eth_0" then true else false;
    enableGofer = if node.name == "eth_0" then true else false;
    enableSpire = if node.name == "eth_0" then true else false;
    user = if node.name == "eth_0" then "monitor" else "omnia";
  };

  nixiform.filesIn.graphiteApiKeyFile = {
    path = toString /. + input.meta.rootPath + "/secret/graphite_api_key";
    user = config.services.monitor.user;
    group = config.services.monitor.group;
  };
}
