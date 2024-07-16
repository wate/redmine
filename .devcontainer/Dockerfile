FROM k1low/tbls:latest AS tbls
FROM ghcr.io/k1low/runn:latest AS runn
FROM buildpack-deps:bookworm

RUN . /etc/os-release \
  && echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/backports.list \
  && apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends bash-completion build-essential gpg vim \
  && apt-get -y install --no-install-recommends ruby-dev ruby-rubygems bundler \
  && apt-get -y install --no-install-recommends fonts-ipaexfont fonts-morisawa-bizud-gothic fonts-morisawa-bizud-mincho fnt \
  && apt-get -y install --no-install-recommends pipx \
  && apt-get -y install --no-install-recommends direnv tig plantuml graphviz \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

## Install node.js
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x -o nodesource_setup.sh \
  && bash nodesource_setup.sh \
  && apt-get install -y nodejs \
  && rm nodesource_setup.sh

## Install Github CLI
RUN mkdir -p /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg /etc/apt/sources.list.d/github-cli.list \
  && apt update \
  && apt install -y gh

## Install eza
RUN mkdir -p /etc/apt/keyrings \
  && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | tee /etc/apt/sources.list.d/gierens.list \
  && chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list \
  && apt update \
  && apt install -y eza

## Install git-delta
RUN curl -fsSL https://github.com/dandavison/delta/releases/download/0.17.0/git-delta_0.17.0_amd64.deb -o git-delta_amd64.deb \
  && dpkg -i git-delta_amd64.deb \
  && rm -f git-delta_amd64.deb

## Install tbls
COPY --from=tbls /usr/bin/tbls /usr/local/bin/tbls

## Install runn
COPY --from=runn /usr/bin/runn /usr/local/bin/runn

## Install d2
RUN curl -fsSL https://d2lang.com/install.sh | sh -s --
