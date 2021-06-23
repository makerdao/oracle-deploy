{ node, ... }: let
  inherit (import ../nix) journald-cloudwatch-logs-module;
in {
  require = [ journald-cloudwatch-logs-module ];

  services.journald-cloudwatch-logs = {
    enable = true;
    inherit (node) log_group aws_access_key_id aws_secret_access_key;
    extraConfig = ''
      log_stream = "${node.log_stream}"
    '';
  };
}
