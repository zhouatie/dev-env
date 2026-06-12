# Docker Dev Environment for OrbStack

这套文件用于把当前 Mac 上的 CLI 开发环境复刻成 Docker 镜像，在新 Mac 安装 OrbStack 后可以直接拉镜像启动。

默认目标是 Apple Silicon Mac，对应 `linux/arm64` 镜像。

## 能复刻什么

- Shell、Git、常用 CLI 工具：zsh、git、gh、lazygit、delta、ripgrep、fd、fzf、bat、jq、eza、zoxide、starship、tmux、pipx、neovim、yazi、atuin 等。
- 语言运行时：Node、pnpm、yarn、bun、Python/uv、Go、Rust、Java 21。
- AI / 编码助手 CLI：codex、claude、opencode。
- SDD 工具：openspec。
- dotfiles：通过容器内的 `atie-chezmoi-sync` 手动同步白名单配置。
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

容器启动后，在容器内手动执行：

```bash
atie-chezmoi-sync
```

同步命令会读取以下可选变量：

```bash
CHEZMOI_REPO=git@github.com:zhouatie/dotfiles.git
CHEZMOI_BRANCH=main
CHEZMOI_TARGETS=".config/starship.toml .config/bat .config/lazygit/config.yml .config/openspec/config.yaml .config/atuin/config.toml .config/yazi .config/tmux/tmux.conf .config/nvim .config/git/ignore"
CHEZMOI_EXCLUDE_TARGETS=".config/nvim/.git .config/nvim/.claude"
```

默认启动不会自动同步 chezmoi。`atie-chezmoi-sync` 只同步 `CHEZMOI_TARGETS` 白名单中已被 chezmoi 管理的条目，并排除 chezmoi scripts、encrypted 条目和 `CHEZMOI_EXCLUDE_TARGETS`。AI CLI 配置不在默认同步范围内。

## 推送到镜像仓库

先给镜像打 tag：

```bash
docker tag atie-dev-env:2026-06-01 ghcr.io/zhouatie/atie-dev-env:2026-06-01
docker push ghcr.io/zhouatie/atie-dev-env:2026-06-01
```

新 Mac 安装 OrbStack 后：

```bash
docker pull ghcr.io/zhouatie/atie-dev-env:2026-06-01
docker run --rm -it \
  --net host \
  -e SSH_AUTH_SOCK=/agent.sock \
  -e CHEZMOI_REPO=git@github.com:zhouatie/dotfiles.git \
  -v "$PWD:/workspace" \
  -v /run/host-services/ssh-auth.sock:/agent.sock \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/zhouatie/atie-dev-env:2026-06-01
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
