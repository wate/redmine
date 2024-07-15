#!/usr/bin/env bash

if [ ! -e "${HOME}/.local/bin/ansible" ]; then
  pipx install ansible --include-deps
fi

if [ ! -e "${HOME}/.local/bin/ansible-lint" ]; then
  pipx install ansible-lint
fi

if [ -e "${PWD}/.devcontainer/post_create.yml" ]; then
  cd "${PWD}/.devcontainer" || exit 1
  ansible-playbook post_create.yml -i localhost, -c local
fi
