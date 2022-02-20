#! /bin/bash

curl -L -O https://gitlab.tiker.net/inducer/ci-support/raw/main/ci-support.sh
source ci-support.sh

build_py_project_in_venv
