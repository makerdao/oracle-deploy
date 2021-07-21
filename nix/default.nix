let
  sources = import ./sources.nix;
  oracles-v2 = import sources.oracles-v2 { };
in rec {
  pkgs = import sources.nixpkgs { };
  makerpkgs = import sources.makerpkgs { };
  nixmaster = import sources.nixmaster { };
  nixiform = import sources.nixiform { inherit pkgs; };

  journald-cloudwatch-logs-module = "${sources.nixos-journald-cloudwatch-logs}";
  deploy-median = import ./median { };

  oracle-bins = pkgs.callPackage ../bin/oracle {
    inherit makerpkgs nixiform monitor-bins;
    inherit (oracles-v2) ssb-server;
  };

  oracle-suite = import sources.oracle-suite { buildGoModule = (import sources.nixmaster { }).buildGo116Module; };

  monitor-bins = pkgs.callPackage ../bin/monitor {
    inherit makerpkgs;
    inherit (oracles-v2) ssb-server;
    inherit oracle-suite;
  };

  shell = { terraform ? pkgs.terraform, extraShellHook ? "", extraBuildInputs ? [ ], nixos ? import sources.nixos { }
    , pkgs ? import sources.nixpkgs { }, rootDir ? toString ../., sshKeyName ? "ssh_key" }:
    pkgs.mkShell rec {
      name = "oracle-nixiform-shell";

      buildInputs = with pkgs; [ jq terraform niv git git-crypt ] ++ extraBuildInputs;

      ROOT_DIR = rootDir;
      SECRET_DIR = "${ROOT_DIR}/secret";
      SSH_KEY = "${SECRET_DIR}/${sshKeyName}";

      shellHook = ''
        export NIX_PATH="nixpkgs=${nixos.path}"

        cryptLock() {
          sed -i"" "/$$/d" "$ROOT_DIR"/.git/nix-shell-lock
          [ "$(cat "$ROOT_DIR"/.git/nix-shell-lock)" == "" ] && {
            echo Locking git-crypt
            ${pkgs.git}/bin/git crypt lock
          }
        }

        cryptUnlock() {
          [[ -f "$ROOT_DIR"/.git/git-crypt/keys/default ]] || {
            echo "Unlocking git-crypt"
            if [[ -n "$GIT_CRYPT_KEY" ]]; then
              ${pkgs.git}/bin/git crypt unlock <(base64 -d <<<"$GIT_CRYPT_KEY")
            elif [[ -f "$ROOT_DIR"/git-crypt-key ]]; then
              ${pkgs.git}/bin/git crypt unlock "$ROOT_DIR"/git-crypt-key
            elif ${pkgs.git}/bin/git crypt unlock; then
              true
            else
              echo "Failed to unlock with git-crypt"
              exit 1
            fi
          }
          echo $$ >> "$ROOT_DIR"/.git/nix-shell-lock
        }

        addKey() {
          test -f "$SSH_KEY" \
            || ${pkgs.openssh}/bin/ssh-keygen \
               -f "$SSH_KEY" -b 4096 -N "" \
               -C "nixiform_best_dev_oracles"
          chmod 600 "$SSH_KEY"
          if test "$SSH_AUTH_SOCK"; then
            echo "Adding key to manager"
            ${pkgs.openssh}/bin/ssh-add "$SSH_KEY"
          else
            NF_SSH_OPTS="-i
        $SSH_KEY''${NF_SSH_OPTS+$(printf \\n%s "$NF_SSH_OPTS")}"
            export NF_SSH_OPTS
            ssh() { ${pkgs.openssh}/bin/ssh $NF_SSH_OPTS "''${@}"; }
            export -f ssh
          fi
        }

        addKey

        echo '
        AWS API keys are setup automatically, to override run:

        $ AWS_ACCESS_KEY_ID=<your_aws_access_key_id>
        $ AWS_SECRET_ACCESS_KEY=<your_aws_secret_access_key>

        Provision infrastructure:

        $ terraform init
        $ terraform apply'

        export AWS_ACCESS_KEY_ID="$(jq -r .aws_access_key_id "$SECRET_DIR/aws.json")"
        export AWS_SECRET_ACCESS_KEY="$(jq -r .aws_secret_access_key "$SECRET_DIR/aws.json")"

      '' + extraShellHook + ''

        source ${./shell/functions.sh}
      '';
    };
}
