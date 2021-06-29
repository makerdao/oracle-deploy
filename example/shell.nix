let inherit (import ./nix) pkgs nixiform oracle-bins monitor-bins shell oracle-suite shellScripts;
in shell {
  rootDir = toString ../.;
  terraform = pkgs.terraform_0_12.withPlugins (p: [ p.aws ]);

  extraShellHook = ''
    echo '
    Push configuration:

    $ nixiform push [--bundle] NAMES..
    '

    cd ${toString ./.}
  '';

  extraBuildInputs = [ nixiform oracle-bins monitor-bins oracle-suite ];
}
