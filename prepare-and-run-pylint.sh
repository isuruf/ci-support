#! /bin/bash

set -e

if [ "$py_version" == "" ]; then
  py_version=3
fi

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

ci_support="https://gitlab.tiker.net/inducer/ci-support/raw/master"

curl -L -O -k "${ci_support}/run-pylint.py"

if ! test -f .pylintrc.yml; then
  curl -o .pylintrc.yml "${ci_support}/.pylintrc-default.yml"
fi

if test "$USE_CONDA_BUILD" == "1"; then
  curl -L -O -k "${ci_support}/build-py-project-within-miniconda.sh"
  source build-py-project-within-miniconda.sh
else
  curl -L -O -k "${ci_support}/build-py-project.sh"
  source build-py-project.sh
fi

$PY_EXE -m pip install pylint PyYAML

PYLINT_RUNNER_ARGS="--yaml-rcfile=.pylintrc.yml"

if test -f .pylintrc-local.yml; then
  PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc-local.yml"
fi

$PY_EXE run-pylint.py $PYLINT_RUNNER_ARGS "$@"
