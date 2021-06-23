{ pkgs, makerpkgs, nixiform, ssb-server, monitor-bins }:

with pkgs; stdenv.mkDerivation rec {
  name = "oracle-deploy-bin";
  src = ./.;

  buildInputs = [
    coreutils bash jq openssh go-ethereum
    nixiform makerpkgs.seth ssb-server
    monitor-bins
  ];
  nativeBuildInputs = [ makeWrapper ];
  passthru.runtimeDeps = buildInputs;

  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales = lib.optionalString (glibcLocales != null)
      ''--set LOCALE_ARCHIVE "${glibcLocales}"/lib/locale/locale-archive'';
  in ''
    mkdir -p $out/bin
    find . -type f -executable | while read -r x; do
      cp "$x" "$out/bin/$x"
      wrapProgram "$out/bin/$x" --prefix PATH : "$out/bin:${path}" ${locales}
    done
  '';
}
