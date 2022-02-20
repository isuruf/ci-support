#! /bin/bash

curl -L -O https://tiker.net/ci-support-v0
source ci-support-v0

print_status_message
clean_up_repo_and_working_env
create_and_set_up_virtualenv
install_and_run_flake8 "$@"
