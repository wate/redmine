#!/usr/bin/env bash

# pipx upgrade-all
# bundle update

if [ -e "${PWD}/.envrc" ]; then
  direnv allow
fi

if [ -e "${PWD}/.devcontainer/scripts/post_start.yml" ]; then
  cd "${PWD}/.devcontainer/scripts" || exit 1
  ansible-playbook post_start.yml -i 127.0.0.1, -c local
fi

bundle exec rails server -p 3000 -b 0.0.0.0