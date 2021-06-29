#!/usr/bin/env bash

SSH_OPTS=(-o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no)
_nixiform_input=""

function _getInput() {
	if [[ -z "$_nixiform_input" ]]; then
		if [[ ! -x .nixiform/input-hook ]]; then
			return
		fi
		_nixiform_input="$(nixiform input | jq -c)"
	fi
}

resetAll() {
	_getInput
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
	_getInput
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip")
	set +x
}

function rest() {
	_getInput
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip") systemctl restart "$2"
	set +x
}

function journal() {
	_getInput
	set -x
  ssh "${SSH_OPTS[@]}" root@$(jq <<<"$_nixiform_input" -r ".nodes.$1.ip") journalctl -f -u "$2"
	set +x
}

_getInput
