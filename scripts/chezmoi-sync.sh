#!/usr/bin/env bash
set -euo pipefail

DEV_USER="${DEV_USER:-dev}"
DEFAULT_CHEZMOI_REPO="git@github.com:zhouatie/dotfiles.git"
DEFAULT_CHEZMOI_TARGETS=".zshrc .config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git/ignore"
DEFAULT_CHEZMOI_EXCLUDE_TARGETS=".config/nvim/.git .config/nvim/.claude"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pull)
      CHEZMOI_PULL=1
      ;;
    --no-pull)
      CHEZMOI_PULL=0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$(id -u)" -eq 0 ]; then
  DEV_HOME="$(getent passwd "$DEV_USER" | cut -d: -f6)"
  run_as_target() {
    sudo -E -H -u "$DEV_USER" env "PATH=$PATH" "$@"
  }
else
  DEV_HOME="${HOME:-$(getent passwd "$(id -un)" | cut -d: -f6)}"
  run_as_target() {
    "$@"
  }
fi

CHEZMOI_REPO="${CHEZMOI_REPO:-$DEFAULT_CHEZMOI_REPO}"
CHEZMOI_PULL="${CHEZMOI_PULL:-1}"
CHEZMOI_TARGETS="${CHEZMOI_TARGETS:-$DEFAULT_CHEZMOI_TARGETS}"
CHEZMOI_EXCLUDE_TARGETS="${CHEZMOI_EXCLUDE_TARGETS:-$DEFAULT_CHEZMOI_EXCLUDE_TARGETS}"

is_excluded_chezmoi_entry() {
  local entry="$1"
  local excluded
  for excluded in ${CHEZMOI_EXCLUDE_TARGETS:-}; do
    case "$entry" in
      "$excluded"|"$excluded"/*)
        return 0
        ;;
    esac
  done
  return 1
}

has_managed_children() {
  local candidate="$1"
  local entry
  while IFS= read -r entry; do
    case "$entry" in
      "$candidate"/*)
        return 0
        ;;
    esac
  done <<EOF
$managed_entries
EOF
  return 1
}

mkdir -p "$DEV_HOME/.config" "$DEV_HOME/.config/git" "$DEV_HOME/.local/share"

chezmoi_source="$DEV_HOME/.local/share/chezmoi"
if [ -d "$chezmoi_source/.git" ]; then
  if [ "$CHEZMOI_PULL" = "1" ]; then
    run_as_target chezmoi git -- pull --ff-only
  fi
elif [ -n "$CHEZMOI_REPO" ]; then
  run_as_target chezmoi init "$CHEZMOI_REPO"
else
  echo "CHEZMOI_REPO is required for first-time chezmoi init." >&2
  exit 1
fi

if [ -n "${CHEZMOI_BRANCH:-}" ]; then
  run_as_target chezmoi git -- checkout "$CHEZMOI_BRANCH"
  if [ "$CHEZMOI_PULL" = "1" ]; then
    run_as_target chezmoi git -- pull --ff-only
  fi
fi

managed_entries="$(run_as_target chezmoi managed --exclude=scripts,encrypted --path-style relative)"

selected_targets=()
for target in ${CHEZMOI_TARGETS:-}; do
  while IFS= read -r entry; do
    case "$entry" in
      "$target"|"$target"/*)
        if is_excluded_chezmoi_entry "$entry"; then
          continue
        fi
        if [ "$entry" = "$target" ] && has_managed_children "$entry"; then
          continue
        fi
        selected_targets+=("$DEV_HOME/$entry")
        ;;
    esac
  done <<EOF
$managed_entries
EOF
done

if [ "${#selected_targets[@]}" -eq 0 ]; then
  echo "No managed chezmoi targets selected."
  exit 0
fi

run_as_target chezmoi apply --parent-dirs --exclude=scripts,encrypted "${selected_targets[@]}"
