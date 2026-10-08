# ~/.cayo/image/Dockerfile: my layer on cayo-base, for every guest: the shell and the tools the
# dotfiles expect, stow to link them, and a current nvim. What installs into the home (mise and
# its toolchains, nvim's plugins, the agent) is installed from inside the guest.
FROM cayo-base
USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      zsh less ripgrep fd-find build-essential stow \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -s /bin/zsh cayo \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd      # Debian's name for it

# nvim, a release: Debian stable's package lags behind. Downloaded at build time, outside any
# guest, so no allow-list needs GitHub for it.
ARG NVIM_VERSION=v0.12.5
RUN arch=$(uname -m | sed 's/aarch64/arm64/') \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$arch.tar.gz" \
      | tar -xz -C /usr/local --strip-components=1

# penyero's client and relay go here, system-wide, once they exist (github.com/nandilugio/penyero).

USER cayo
