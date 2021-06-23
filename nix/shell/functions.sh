#!/usr/bin/env bash

resetAll() {
	set -x

	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.boot_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.eth_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.feed_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.relay_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.bb_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.feed_lb_0.ip') systemctl restart spire
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.ghost_0.ip') systemctl restart ghost
	ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r '.nodes.spectre_0.ip') systemctl restart spectre

	set +x
}

function conn() {
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip")
	set +x
}

function rest() {
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip") systemctl restart "$2"
	set +x
}

function journal() {
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip") journalctl -f -u "$2"
	set +x
}

SSH_OPTS=(-o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)
_nixiform_input="$(nixiform input | jq -c)"
