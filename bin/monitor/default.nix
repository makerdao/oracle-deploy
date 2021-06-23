{ pkgs, makerpkgs, ssb-server, oracle-suite }:
with pkgs;
stdenv.mkDerivation rec {
  name = "oracle-monitor-bin";
  src = ./.;

  buildInputs = [ coreutils bash jq curl gnused makerpkgs.seth ssb-server oracle-suite ];
  nativeBuildInputs = [ makeWrapper ];
  passthru.runtimeDeps = buildInputs;

  installPhase = let
    path = lib.makeBinPath passthru.runtimeDeps;
    locales =
      lib.optionalString (glibcLocales != null) ''--set LOCALE_ARCHIVE "${glibcLocales}"/lib/locale/locale-archive'';
  in ''
    echo "${oracle-suite}"
    mkdir -p $out/bin
    find . -type f -executable | while read -r x; do
      cp "$x" "$out/bin/$x"
      wrapProgram "$out/bin/$x" --prefix PATH : "$out/bin:${path}" ${locales}
    done
  '';
}
