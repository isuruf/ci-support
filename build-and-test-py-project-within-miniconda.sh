#! /bin/bash

set -e
set -x

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/ci-support.sh
source ci-support.sh

build_py_project_in_conda_env
test_py_project
