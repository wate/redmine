#!/usr/bin/env bash

mkdir -p "${HOME}/.local/share/bash-completion/completions/"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-ruby -o "${HOME}/.local/share/bash-completion/completions/ruby"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-gem -o "${HOME}/.local/share/bash-completion/completions/gem"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-rake -o "${HOME}/.local/share/bash-completion/completions/rake"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-bundle -o "${HOME}/.local/share/bash-completion/completions/bundle"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-rake -o "${HOME}/.local/share/bash-completion/completions/rake"
curl -fsSL https://raw.githubusercontent.com/mernen/completion-ruby/main/completion-rails -o "${HOME}/.local/share/bash-completion/completions/rails"

if type "eza" >/dev/null 2>&1; then
  echo 'alias ls="eza --git --header"' >>~/.bashrc
fi

if [ ! -f "${HOME}/.inputrc" ]; then
  echo "set completion-ignore-case on">~/.inputrc
fi

if [ ! -e "${HOME}/.bash-git-prompt" ]; then
  git clone https://github.com/magicmonty/bash-git-prompt.git ~/.bash-git-prompt --depth=1
  cat << EOT >>~/.bashrc
if [ -f "\$HOME/.bash-git-prompt/gitprompt.sh" ]; then
    GIT_PROMPT_ONLY_IN_REPO=1
    source \$HOME/.bash-git-prompt/gitprompt.sh
fi
EOT
fi

source "${HOME}/.bashrc"

pipx install ansible --include-deps
pipx install mkdocs --include-deps
pipx inject mkdocs mkdocs-material mkdocs-glightbox mkdocs-git-revision-date-localized-plugin mkdocs-section-index mkdocs-literate-nav
pipx install mycli

if [ ! -e ~/.my.cnf ]; then
  cp "${PWD}/.devcontainer/files/mariadb/.my.cnf" ~/.my.cnf
fi

if [ ! -e ~/.myclirc ]; then
  cp "${PWD}/.devcontainer/files/mycli/.myclirc" ~/.myclirc
fi

if [ ! -e "${PWD}/.bundle/config" ]; then
  mkdir -p "${PWD}/.bundle"
  cp "${PWD}/.devcontainer/files/bundler/config" "${PWD}/.bundle/config"
fi

if [ ! -e "${PWD}/config/configuration.yml" ]; then
  cp "${PWD}/.devcontainer/files/redmine/configuration.yml" "${PWD}/config/configuration.yml"
fi

if [ ! -e "${PWD}/config/database.yml" ]; then
  cp "${PWD}/.devcontainer/files/redmine/database.yml" "${PWD}/config/database.yml"
fi

if [ ! -e "${PWD}/Gemfile.local" ]; then
  cp "${PWD}/.devcontainer/files/redmine/Gemfile.local" "${PWD}/Gemfile.local"
fi

bundle install

if [ ! -e "${PWD}/config/initializers/secret_token.rb" ]; then
  bundle exec rake generate_secret_token
fi

bundle exec rake db:migrate 
bundle exec rake redmine:plugins:migrate 

