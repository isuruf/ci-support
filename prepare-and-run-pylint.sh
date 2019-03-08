#! /bin/bash

set -e

if [ "$py_version" == "" ]; then
  py_version=3
fi

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/pylint-flexible-config/build-py-project.sh
source build-py-project.sh

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/pylint-flexible-config/run-pylint.py

$PY_EXE -m pip install pylint PyYAML

PYLINT_RUNNER_ARGS=""

if ! test -f .pylintrc.yml; then
  curl -o .pylintrc.yml https://gitlab.tiker.net/inducer/ci-support/raw/pylint-flexible-config/.pylintrc-default.yml
  PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc.yml"
fi

if ! test -f .pylintrc-local.yml; then
  PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc-local.yml"
fi

python run-pylint.py $PYLINT_RUNNER_ARGS "$@"
