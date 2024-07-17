#!/usr/bin/env bash

# pipx upgrade-all
# bundle update

if [ -e "${PWD}/.devcontainer/post_start.yml" ]; then
  cd "${PWD}/.devcontainer" || exit 1
  ansible-playbook post_start.yml -i localhost, -c local
fi
