#! /bin/bash

curl -L -O https://gitlab.tiker.net/inducer/ci-support/raw/main/ci-support.sh
source ci-support.sh

print_status_message
clean_up_repo_and_working_env
create_and_set_up_virtualenv
install_and_run_flake8 "$@"
