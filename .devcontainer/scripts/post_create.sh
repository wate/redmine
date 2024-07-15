#!/usr/bin/env bash

# if [ ! -e ~/.my.cnf ]; then
#   cp "${PWD}/.devcontainer/files/mariadb/.my.cnf" ~/.my.cnf
# fi

# if [ ! -e "${PWD}/.bundle/config" ]; then
#   mkdir -p "${PWD}/.bundle"
#   cp "${PWD}/.devcontainer/files/bundler/config" "${PWD}/.bundle/config"
# fi

# if [ ! -e "${PWD}/config/configuration.yml" ]; then
#   cp "${PWD}/.devcontainer/files/redmine/config/configuration.yml" "${PWD}/config/configuration.yml"
# fi

# if [ ! -e "${PWD}/config/database.yml" ]; then
#   cp "${PWD}/.devcontainer/files/redmine/config/database.yml" "${PWD}/config/database.yml"
# fi

# if [ ! -e "${PWD}/Gemfile.local" ]; then
#   cp "${PWD}/.devcontainer/files/redmine/Gemfile.local" "${PWD}/Gemfile.local"
# fi

# if [ -e "${PWD}/.devcontainer/files/redmine/config/additional_environment.rb" ] && [ ! -e "${PWD}/config/additional_environment.rb" ]; then
#   cp "${PWD}/.devcontainer/files/redmine/config/additional_environment.rb" "${PWD}/config/additional_environment.rb"
# fi

# bundle install

# if [ ! -e "${PWD}/config/initializers/secret_token.rb" ]; then
#   bundle exec rake generate_secret_token
# fi

# bundle exec rake db:migrate 
# bundle exec rake redmine:plugins:migrate 

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
