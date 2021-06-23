{ pkgs, ... }: {
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  services.openssh.passwordAuthentication = false;
  environment.systemPackages = [ pkgs.jq pkgs.tree ];

  nix.autoOptimiseStore = true;
  nix.binaryCaches = [ "https://dapp.cachix.org" "https://maker.cachix.org" ];
  nix.binaryCachePublicKeys = [
    "dapp.cachix.org-1:9GJt9Ja8IQwR7YW/aF0QvCa6OmjGmsKoZIist0dG+Rs="
    "maker.cachix.org-1:a0L/xndLEkdVesZup6BVOHYFIeIioGstRnBiviFOPpU="
  ];
  nix.gc.automatic = true;
}
