# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04@sha256:c4a8d5503dfb2a3eb8ab5f807da5bc69a85730fb49b5cfca2330194ebcc41c7b

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG USERNAME=dev
ARG USER_UID=1001
ARG USER_GID=1001
ARG TZ=Asia/Shanghai

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=${TZ} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DEV_USER=${USERNAME} \
    PATH=/usr/local/go/bin:/home/${USERNAME}/.cargo/bin:/home/${USERNAME}/.bun/bin:/home/${USERNAME}/.local/bin:/opt/node/bin:$PATH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      adb \
      apt-transport-https \
      bat \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      docker.io \
      docker-compose-v2 \
      eza \
      fd-find \
      fzf \
      git \
      git-lfs \
      gnupg \
      htop \
      jq \
      less \
      locales \
      nano \
      openssh-client \
      pkg-config \
      procps \
      pipx \
      ripgrep \
      rsync \
      software-properties-common \
      sudo \
      tmux \
      tree \
      tzdata \
      unzip \
      vim \
      watchman \
      wget \
      xz-utils \
      zip \
      zoxide \
      zsh \
      openjdk-21-jdk; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
    echo "${TZ}" > /etc/timezone; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    ln -sf /usr/bin/batcat /usr/local/bin/bat; \
    ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose || true; \
    git lfs install --system

RUN groupadd --gid ${USER_GID} ${USERNAME} \
  && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /usr/bin/zsh ${USERNAME} \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
  && chmod 0440 /etc/sudoers.d/${USERNAME}

ARG NODE_VERSION=25.8.2
RUN set -eux; \
  node_arch="arm64"; \
  curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz; \
  mkdir -p /opt/node; \
  tar -xJf /tmp/node.tar.xz -C /opt/node --strip-components=1; \
  rm /tmp/node.tar.xz

ARG GO_VERSION=1.25.0
RUN set -eux; \
  go_arch="arm64"; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tar.gz; \
  rm -rf /usr/local/go; \
  tar -C /usr/local -xzf /tmp/go.tar.gz; \
  rm /tmp/go.tar.gz

ARG UV_VERSION=0.11.17
RUN set -eux; \
  curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-aarch64-unknown-linux-gnu.tar.gz" -o /tmp/uv.tar.gz; \
  tar -xzf /tmp/uv.tar.gz -C /tmp; \
  install -m 0755 /tmp/uv-aarch64-unknown-linux-gnu/uv /usr/local/bin/uv; \
  install -m 0755 /tmp/uv-aarch64-unknown-linux-gnu/uvx /usr/local/bin/uvx; \
  rm -rf /tmp/uv.tar.gz /tmp/uv-aarch64-unknown-linux-gnu

RUN mkdir -p /home/${USERNAME}/.cache /home/${USERNAME}/.cargo /home/${USERNAME}/.rustup \
  && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.cache /home/${USERNAME}/.cargo /home/${USERNAME}/.rustup

USER ${USERNAME}
WORKDIR /workspace

ARG RUST_VERSION=1.94.1
RUN --mount=type=cache,target=/home/dev/.rustup/downloads,uid=1001,gid=1001,sharing=locked \
    set -eux; \
  curl -fsSL --retry 8 --retry-all-errors --connect-timeout 20 --max-time 600 \
    "https://static.rust-lang.org/rustup/dist/aarch64-unknown-linux-gnu/rustup-init" \
    -o /tmp/rustup-init; \
  chmod +x /tmp/rustup-init; \
  /tmp/rustup-init -y --profile minimal --default-toolchain "${RUST_VERSION}"; \
  rm -f /tmp/rustup-init

ARG BUN_VERSION=1.3.5
RUN set -eux; \
  curl -fsSL https://bun.sh/install | bash -s "bun-v${BUN_VERSION}"

ARG PYTHON_VERSION=3.14.3
RUN --mount=type=cache,target=/home/dev/.cache/uv,uid=1001,gid=1001,sharing=locked \
    set -eux; \
  uv python install "${PYTHON_VERSION}"; \
  py="$(uv python find "${PYTHON_VERSION}")"; \
  ln -sf "$py" "$HOME/.local/bin/python"; \
  ln -sf "$py" "$HOME/.local/bin/python3"

USER root

ARG GH_VERSION=2.87.3
RUN set -eux; \
  curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_arm64.deb" -o /tmp/gh.deb; \
  dpkg -i /tmp/gh.deb; \
  rm /tmp/gh.deb

ARG LAZYGIT_VERSION=0.60.0
RUN set -eux; \
  curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_arm64.tar.gz" -o /tmp/lazygit.tar.gz; \
  tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit; \
  install -m 0755 /tmp/lazygit /usr/local/bin/lazygit; \
  rm -f /tmp/lazygit /tmp/lazygit.tar.gz

ARG DELTA_VERSION=0.19.2
RUN set -eux; \
  curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_arm64.deb" -o /tmp/git-delta.deb; \
  dpkg -i /tmp/git-delta.deb; \
  rm /tmp/git-delta.deb

ARG STARSHIP_VERSION=1.24.2
RUN set -eux; \
  curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-aarch64-unknown-linux-musl.tar.gz" -o /tmp/starship.tar.gz; \
  tar -xzf /tmp/starship.tar.gz -C /tmp starship; \
  install -m 0755 /tmp/starship /usr/local/bin/starship; \
  rm -f /tmp/starship /tmp/starship.tar.gz

ARG ATUIN_VERSION=18.10.0
RUN set -eux; \
  curl -fsSL "https://github.com/atuinsh/atuin/releases/download/v${ATUIN_VERSION}/atuin-aarch64-unknown-linux-gnu.tar.gz" -o /tmp/atuin.tar.gz; \
  tar -xzf /tmp/atuin.tar.gz -C /tmp; \
  install -m 0755 /tmp/atuin-aarch64-unknown-linux-gnu/atuin /usr/local/bin/atuin; \
  rm -rf /tmp/atuin.tar.gz /tmp/atuin-aarch64-unknown-linux-gnu

ARG YAZI_VERSION=26.1.22
RUN set -eux; \
  curl -fsSL "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-aarch64-unknown-linux-gnu.zip" -o /tmp/yazi.zip; \
  unzip -q /tmp/yazi.zip -d /tmp; \
  install -m 0755 /tmp/yazi-aarch64-unknown-linux-gnu/yazi /usr/local/bin/yazi; \
  install -m 0755 /tmp/yazi-aarch64-unknown-linux-gnu/ya /usr/local/bin/ya; \
  rm -rf /tmp/yazi.zip /tmp/yazi-aarch64-unknown-linux-gnu

ARG CHEZMOI_VERSION=2.70.0
RUN set -eux; \
  curl -fsSL "https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/chezmoi_${CHEZMOI_VERSION}_linux_arm64.tar.gz" -o /tmp/chezmoi.tar.gz; \
  tar -xzf /tmp/chezmoi.tar.gz -C /tmp chezmoi; \
  install -m 0755 /tmp/chezmoi /usr/local/bin/chezmoi; \
  rm -f /tmp/chezmoi /tmp/chezmoi.tar.gz

ARG NVIM_VERSION=0.12.0
RUN set -eux; \
  curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-arm64.tar.gz" -o /tmp/nvim.tar.gz; \
  rm -rf /opt/nvim; \
  mkdir -p /opt/nvim; \
  tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1; \
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim; \
  rm -f /tmp/nvim.tar.gz

ARG PNPM_VERSION=10.33.0
ARG YARN_VERSION=1.22.19
ARG OPENSPEC_VERSION=1.3.1
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    set -eux; \
  npm install -g \
    "pnpm@${PNPM_VERSION}" \
    "yarn@${YARN_VERSION}" \
    "@ast-grep/cli@0.39.4" \
    "@openai/codex@0.135.0" \
    "@anthropic-ai/claude-code@2.1.153" \
    "opencode-ai@1.0.175" \
    "@fission-ai/openspec@${OPENSPEC_VERSION}"

COPY --chown=${USERNAME}:${USERNAME} home/.zshrc /home/${USERNAME}/.zshrc
COPY --chown=${USERNAME}:${USERNAME} scripts/entrypoint.sh /usr/local/bin/dev-entrypoint
COPY --chown=${USERNAME}:${USERNAME} scripts/chezmoi-sync.sh /usr/local/bin/atie-chezmoi-sync

RUN chmod +x /usr/local/bin/dev-entrypoint /usr/local/bin/atie-chezmoi-sync
USER root

VOLUME ["/workspace", "/home/dev/.cache", "/home/dev/.npm", "/home/dev/.pnpm-store", "/home/dev/.cargo/registry", "/home/dev/go/pkg/mod"]

ENTRYPOINT ["dev-entrypoint"]
CMD ["zsh", "-l"]
