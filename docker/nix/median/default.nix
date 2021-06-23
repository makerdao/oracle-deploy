{ makerpkgs
, srcRoot ? null
, ...
}:
with makerpkgs;
let
  inherit (builtins) mapAttrs attrValues;
  inherit (callPackage ./dapp2.nix { inherit srcRoot; }) specs packageSpecs;
  deps = packageSpecs (mapAttrs (_: spec:
    spec // {
      solc = solc-versions.solc_0_5_12;
    }
  ) specs.this.deps);
in
makerScriptPackage {
  name = "median-deploy";
  nativeBuildInputs = [ bash ];
  src = lib.sourceByRegex ./. [
    "bin" "bin/.*"
  ];
  solidityPackages = attrValues deps;
}
