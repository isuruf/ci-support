#! /bin/bash

curl -L -O https://tiker.net/ci-support-v0
source ci-support-v0

build_py_project_in_venv
test_py_project

