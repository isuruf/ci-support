#! /bin/bash

set -e

curl -L -O https://tiker.net/ci-support-v0
source ci-support-v0

build_py_project
run_pylint "$@"
