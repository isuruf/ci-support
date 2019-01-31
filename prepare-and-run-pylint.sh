#! /bin/bash

set -e

if [ "$py_version" == "" ]; then
  py_version=3
fi

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project.sh
source build-py-project.sh

$PY_EXE -m pip install pylint

if ! test -f .pylintrc; then
  curl -o .pylintrc https://gitlab.tiker.net/inducer/ci-support/raw/master/.pylintrc-default
fi

python -m pylint "$@"
