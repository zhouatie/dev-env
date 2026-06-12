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

```bash
docker compose build
docker compose run --rm dev
```

默认工作目录会挂载到 `./workspace`。也可以指定真实项目目录：

```bash
WORKSPACE_DIR=/Users/zhoushitie/Desktop/work/my-project docker compose run --rm dev
```

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
CHEZMOI_TARGETS=".zshrc .config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git/ignore"
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

先构建并推送明确版本 tag，再同步更新日常使用的移动 tag：

```bash
docker compose build
docker tag ghcr.io/zhouatie/atie-dev-env:2026-06-12.5 ghcr.io/zhouatie/atie-dev-env:dev
docker push ghcr.io/zhouatie/atie-dev-env:2026-06-12.5
docker push ghcr.io/zhouatie/atie-dev-env:dev
```

明确版本 tag 用于回滚和排查，`dev` tag 用于其它电脑的 `atiedev` 日常启动。只要每次发布时更新 `dev` tag，其它电脑的启动配置就不需要跟着改。

新 Mac 安装 OrbStack 后：

```bash
docker run --rm -it \
  --net host \
  -e SSH_AUTH_SOCK=/agent.sock \
  -e GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
  -e CHEZMOI_APPLY=1 \
  -e CHEZMOI_STARTUP_PULL=0 \
  -e CHEZMOI_REPO=https://github.com/zhouatie/dotfiles.git \
  -e CHEZMOI_TARGETS=".zshrc .config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git/ignore" \
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

当前配置尽量贴近这台机器：

- Node 25.8.2
- pnpm 10.33.0
- yarn 1.22.19
- bun 1.3.5
- uv 0.11.17
- Python 3.14.3 via uv
- Go 1.25.0
- Rust 1.94.1
- Java 21
- gh 2.87.3
- lazygit 0.60.0
- delta 0.19.2
- ast-grep 0.39.4
- starship 1.24.2
- atuin 18.10.0
- yazi 26.5.6
- neovim 0.12.0
- chezmoi 2.70.0
- codex 0.135.0
- claude 2.1.153
- opencode 1.0.175
- openspec 1.3.1
- Docker Compose 2.40.3
- adb 34.0.4
- watchman 4.9.0
- eza 0.18.2
- zoxide 0.9.3
- tmux 3.4
- pipx 1.4.3

如果某个版本在 Linux arm64 上没有对应发行包，构建会失败；那时需要把对应 `ARG` 改成可用版本。
