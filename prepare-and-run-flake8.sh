#! /bin/bash

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/ci-support.sh
source ci-support.sh

print_status_message
clean_up_repo_and_working_env
create_and_set_up_virtualenv

${PY_EXE} -m pip install flake8 pep8-naming
${PY_EXE} -m flake8 "$@"
