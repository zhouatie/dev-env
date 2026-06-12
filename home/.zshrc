export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export TZ="${TZ:-Asia/Shanghai}"

export PATH="/opt/node/bin:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.local/bin:$PATH"
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

alias ll='ls -alF'
alias gs='git status --short'
alias gd='git diff'
alias dc='docker compose'

autoload -Uz compinit
compinit

if command -v fzf >/dev/null 2>&1; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh 2>/dev/null || true
  source /usr/share/doc/fzf/examples/completion.zsh 2>/dev/null || true
fi

echo "atie dev container ready: /workspace"
