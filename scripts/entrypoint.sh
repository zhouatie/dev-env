#!/usr/bin/env bash
set -euo pipefail

DEV_USER="${DEV_USER:-dev}"
DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"

mkdir -p \
  "$DEV_HOME/.cache" \
  "$DEV_HOME/.codex" \
  "$DEV_HOME/.config" \
  "$DEV_HOME/.config/git" \
  "$DEV_HOME/.config/nvim/lua/plugins/local" \
  "$DEV_HOME/.local/share" \
  "$DEV_HOME/.npm" \
  "$DEV_HOME/.pnpm-store" \
  "$DEV_HOME/.ssh" \
  "$DEV_HOME/go/pkg/mod" \
  /workspace

touch \
  "$DEV_HOME/.zshrc.local.pre" \
  "$DEV_HOME/.zshrc.local" \
  "$DEV_HOME/.config/git/config.local"

chown -R "$DEV_USER:$DEV_USER" \
  "$DEV_HOME/.cache" \
  "$DEV_HOME/.codex" \
  "$DEV_HOME/.config" \
  "$DEV_HOME/.local" \
  "$DEV_HOME/.npm" \
  "$DEV_HOME/.pnpm-store" \
  "$DEV_HOME/.ssh" \
  "$DEV_HOME/go" 2>/dev/null || true

chmod 700 "$DEV_HOME/.ssh" 2>/dev/null || true

if [ -S /var/run/docker.sock ]; then
  docker_gid="$(stat -c '%g' /var/run/docker.sock)"
  docker_group="$(getent group "$docker_gid" | cut -d: -f1 || true)"
  if [ -z "$docker_group" ]; then
    docker_group="dockerhost"
    groupadd -g "$docker_gid" "$docker_group" 2>/dev/null || true
  fi
  usermod -aG "$docker_group" "$DEV_USER" 2>/dev/null || true
fi

if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  ssh_agent_gid="$(stat -c '%g' "$SSH_AUTH_SOCK")"
  ssh_agent_group="$(getent group "$ssh_agent_gid" | cut -d: -f1 || true)"
  if [ -z "$ssh_agent_group" ]; then
    ssh_agent_group="sshagent"
    groupadd -g "$ssh_agent_gid" "$ssh_agent_group" 2>/dev/null || true
  fi
  usermod -aG "$ssh_agent_group" "$DEV_USER" 2>/dev/null || true
fi

if [ "${CHEZMOI_APPLY:-0}" = "1" ]; then
  CHEZMOI_PULL="${CHEZMOI_STARTUP_PULL:-0}" atie-chezmoi-sync
fi

exec sudo -E -H -u "$DEV_USER" env "PATH=$PATH" "$@"
