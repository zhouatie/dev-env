# Docker Dev Environment for OrbStack

这套文件用于把当前 Mac 上的 CLI 开发环境复刻成 Docker 镜像，在新 Mac 安装 OrbStack 后可以直接拉镜像启动。

默认目标是 Apple Silicon Mac，对应 `linux/arm64` 镜像。

## 能复刻什么

- Shell、Git、常用 CLI 工具：zsh、git、gh、lazygit、delta、ripgrep、fd、fzf、bat、jq、eza、zoxide、starship、tmux、pipx、neovim、yazi、atuin 等。
- 语言运行时：Node、pnpm、yarn、bun、Python/uv、Go、Rust、Java 21。
- AI / 编码助手 CLI：codex、claude、opencode。
- SDD 工具：openspec。
- dotfiles：容器启动时通过 `atie-chezmoi-sync` 同步白名单配置。
- Android / 文件监听：adb、watchman。
- 包管理缓存：通过 Docker volume 保留 npm、pnpm、cargo、Go module 等缓存。
- SSH：通过 OrbStack SSH agent 转发，不把宿主机私钥写入镜像或容器。
- 网络：使用 OrbStack host networking，容器内服务可直接通过 Mac 的 `localhost` 访问。
- Docker CLI 工作流：挂载宿主机 `/var/run/docker.sock`，容器里可以调用 OrbStack 的 Docker 和 Compose v2。

## 不能复刻什么

- macOS GUI 应用、Keychain、系统设置。
- Xcode、iOS Simulator、Android Emulator 图形界面。
- 只能在 macOS 上工作的 Homebrew formula 或本地私有二进制。
- token、SSH 私钥、公司内网凭据等敏感内容；这些应通过挂载或登录流程处理。

## 本机构建

镜像 tag、平台和工具版本集中维护在 `.env`。升级 Node、pnpm、Neovim、AI CLI 等版本时，先改 `.env`，再重新构建。

```bash
docker compose build
docker compose run --rm dev
```

默认工作目录会挂载到 `./workspace`。也可以指定真实项目目录：

```bash
WORKSPACE_DIR=/Users/zhoushitie/Desktop/work/my-project docker compose run --rm dev
```

## 版本管理

`.env` 是版本号的单一来源：

```text
IMAGE_REPOSITORY=ghcr.io/zhouatie/atie-dev-env
IMAGE_VERSION=2026-06-12.6
IMAGE_CHANNEL=dev
IMAGE_PLATFORM=linux/arm64
NODE_VERSION=25.8.2
PNPM_VERSION=10.33.0
...
```

`docker-compose.yml` 从 `.env` 读取 image tag 和 build args；`scripts/release-image` 也从同一个文件读取版本。`Dockerfile` 不再给这些工具版本写默认值，缺少 build args 时会直接失败，避免 compose、发布脚本和 Dockerfile 之间版本漂移。

## 构建缓存

`Dockerfile` 已按缓存粒度拆分：基础 apt 包、Node、Go、uv、Rust、Bun、Python、单个 GitHub release 工具、Neovim、npm 全局包分别在独立构建层中安装。常更新的 Neovim 和 AI CLI npm 包放在靠后位置，升级它们时不会牵动前面的运行时层。

构建时还使用 BuildKit cache mount 保留 apt、npm、uv、rustup 的下载缓存。这些缓存属于 Docker builder cache，不是 `docker-compose.yml` 里的运行时 volume；运行时 volume 只在容器启动后保存 npm、pnpm、cargo、Go module、Neovim 等状态。

pnpm 的 store 固定为 `/home/dev/.pnpm-store`，对应 `docker-compose.yml` 里的 `pnpm-store` volume。这样不会在每个 `/workspace` 项目目录下生成独立 `.pnpm-store`。

如果使用 `docker compose build --no-cache`、执行过 `docker builder prune`，或换到没有 builder cache 的新机器，下一次构建仍会全量下载。普通 `docker compose build` 会尽量复用本地构建缓存。

## GitHub SSH agent

容器通过宿主机 SSH agent 使用 GitHub SSH key，不复制 `~/.ssh/id_*` 私钥到镜像或容器。`docker-compose.yml` 和 `scripts/host-atiedev` 会把宿主机 agent socket 挂载到容器内的 `/agent.sock`，并设置：

```text
SSH_AUTH_SOCK=/agent.sock
GIT_SSH_COMMAND=ssh -o StrictHostKeyChecking=accept-new
```

宿主机先确认 agent 里有可用 key：

```bash
ssh-add -l
ssh -o StrictHostKeyChecking=accept-new -T git@github.com
```

如果 `ssh-add -l` 没有列出 key，在宿主机把 `Host github.com` 对应的 `IdentityFile` 加进 agent，例如：

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_github
```

进入容器后验证转发是否生效：

```bash
test -S "$SSH_AUTH_SOCK"
ssh-add -l
ssh -o StrictHostKeyChecking=accept-new -T git@github.com
git remote -v
```

只要项目 remote 是 `git@github.com:owner/repo.git` 这类 SSH 地址，`git push origin dev` 会通过宿主机 agent 完成认证。若容器内 `ssh-add -l` 报 `The agent has no identities`，问题在宿主机 agent 没加载 key；若 `test -S "$SSH_AUTH_SOCK"` 失败，问题在 agent socket 没有被挂载进容器。

## chezmoi 同步

容器默认启动时会自动执行一次：

```bash
CHEZMOI_PULL=0 atie-chezmoi-sync
```

如需临时关闭自动同步：

```bash
CHEZMOI_APPLY=0 docker compose run --rm dev
```

同步命令会读取以下可选变量：

```bash
CHEZMOI_REPO=git@github.com:zhouatie/dotfiles.git
CHEZMOI_BRANCH=main
CHEZMOI_STARTUP_PULL=0
CHEZMOI_TARGETS=".zshrc .config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git"
CHEZMOI_EXCLUDE_TARGETS=".config/nvim/.git .config/nvim/.claude"
```

启动时默认不执行 `git pull`，只使用 Docker volume 中已有的 chezmoi source apply 白名单配置。需要更新 dotfiles 时，在容器内手动执行：

```bash
atie-chezmoi-sync
```

`atie-chezmoi-sync` 手动执行时默认会拉取最新 chezmoi source，然后只同步 `CHEZMOI_TARGETS` 白名单中已被 chezmoi 管理的条目，并排除 chezmoi scripts、encrypted 条目和 `CHEZMOI_EXCLUDE_TARGETS`。AI CLI 配置不在默认同步范围内。

容器启动时会创建空的 local 覆盖文件，避免全量 `chezmoi apply` 或手动 shell 启动时因为本机 local 文件缺失而报错：

```text
~/.zshrc.local.pre
~/.zshrc.local
~/.config/git/config.local
~/.config/nvim/lua/plugins/local/
```

这些文件和目录只是容器内兜底，不来自 chezmoi 远程配置。

## Codex 登录状态

Codex CLI 登录缓存通过 Docker volume 持久化：

```text
codex-state:/home/dev/.codex
```

在其它 Mac 上使用裸 `docker run` 时，对应挂载为：

```text
atie-dev-codex:/home/dev/.codex
```

这个 volume 不进入镜像，不进入 chezmoi，也不和宿主机 `~/.codex` 绑定。第一次在容器内执行 `codex login` 后，后续删除并重建容器仍会复用该 volume 中的登录状态。

## AIterm Codex 推送通知

当容器从 AIterm 内置终端启动时，`docker-compose.yml` 和 `scripts/host-atiedev` 会把下面三个 AIterm 通知环境变量透传进容器：

```text
AITEM_TERMINAL_SESSION_ID
AITEM_NOTIFY_URL
AITEM_NOTIFY_TOKEN
```

容器使用 host networking，因此容器内的 Codex hook 可以通过 `AITEM_NOTIFY_URL` 回推到宿主机 AIterm。还需要在容器内安装 Codex hook 配置和通知脚本副本。安装步骤见 AIterm 仓库：

```text
docs/codex-hook-notifications.md
```

推荐把 `scripts/aiterm-notify.mjs` 复制到 `/home/dev/.codex/aiterm-notify.mjs`，因为 `/home/dev/.codex` 是持久化 volume，后续切换 workspace 时 hook 路径仍然有效。

## Neovim / LazyVim 状态

Neovim 配置来自 chezmoi 的 `.config/nvim`，LazyVim 运行时生成物通过 Docker volume 持久化：

```text
nvim-data:/home/dev/.local/share/nvim
nvim-state:/home/dev/.local/state/nvim
dev-cache:/home/dev/.cache
```

其中 `nvim-data` 保存 LazyVim 插件、Mason、Treesitter 等下载内容，`nvim-state` 保存 shada、日志等状态，`dev-cache` 已覆盖 `~/.cache/nvim`。这些目录不进入镜像，也不进入 chezmoi。

## atiedev 启动脚本

宿主机的 `atiedev` 长启动参数集中维护在：

```text
scripts/host-atiedev
```

安装到宿主机：

```bash
mkdir -p ~/.local/bin
cp scripts/host-atiedev ~/.local/bin/atiedev
chmod +x ~/.local/bin/atiedev
```

`~/.zshrc.local` 中只需要保留一个轻量 wrapper：

```zsh
atiedev() {
  "$HOME/.local/bin/atiedev" "$@"
}
```

默认直接使用本地已有的 `dev` 镜像；只有需要更新镜像时再显式拉取：

```bash
atiedev
atiedev --pull
```

## 推送到镜像仓库

先在 `.env` 中更新 `IMAGE_VERSION`，然后用发布脚本一次性构建并推送明确版本 tag 和日常使用的移动 tag：

```bash
scripts/release-image
```

脚本默认读取 `.env`，并推送：

```text
${IMAGE_REPOSITORY}:${IMAGE_VERSION}
${IMAGE_REPOSITORY}:${IMAGE_CHANNEL}
```

明确版本 tag 用于回滚和排查，`dev` tag 用于其它电脑的 `atiedev` 日常启动。只要每次发布时更新 `dev` tag，其它电脑的启动配置就不需要跟着改。

只想构建到本机 Docker engine 做验证时：

```bash
scripts/release-image --load
```

新 Mac 安装 OrbStack 后：

```bash
docker run --rm -it \
  --net host \
  --security-opt seccomp=unconfined \
  -e SSH_AUTH_SOCK=/agent.sock \
  -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
  -e CHEZMOI_APPLY=1 \
  -e CHEZMOI_STARTUP_PULL=0 \
  -e CHEZMOI_REPO=https://github.com/zhouatie/dotfiles.git \
  -e CHEZMOI_TARGETS=".zshrc .config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git" \
  -e CHEZMOI_EXCLUDE_TARGETS=".config/nvim/.git .config/nvim/.claude" \
  -v "$PWD:/workspace" \
  -v /run/host-services/ssh-auth.sock:/agent.sock \
  -v atie-dev-codex:/home/dev/.codex \
  -v atie-dev-chezmoi:/home/dev/.local/share/chezmoi \
  -v atie-dev-nvim-data:/home/dev/.local/share/nvim \
  -v atie-dev-nvim-state:/home/dev/.local/state/nvim \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/zhouatie/atie-dev-env:dev
```

使用 `--net host` 后，容器内启动的服务可以直接从 Mac 访问：

```bash
npm run dev -- --host 0.0.0.0
```

```text
http://127.0.0.1:5173
```

## 版本

当前可控版本以 `.env` 为准。apt 仓库安装的工具版本由 Ubuntu 24.04 源决定，例如 Docker Compose、adb、watchman、eza、zoxide、tmux、pipx 等。

如果某个版本在 Linux arm64 上没有对应发行包，构建会失败；那时需要把 `.env` 中对应版本改成可用版本。
