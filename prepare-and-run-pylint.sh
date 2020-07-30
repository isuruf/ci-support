#! /bin/bash

set -e

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/ci-support.sh
source ci-support.sh

build_py_project

curl -L -O -k "${ci_support}/run-pylint.py"

if ! test -f .pylintrc.yml; then
  curl -o .pylintrc.yml "${ci_support}/.pylintrc-default.yml"
fi

# - pylint<2.6 version bound put in place out of an abundance of cautiousness, no
#   particular reason. -- 2020-07-15 AK
# - pytest is being installed since test_*.py modules may import pytest, which
#   pylint may inspect.
# - pytest<6 because https://github.com/pytest-dev/pytest/pull/7565 did not make
#   pytest-6.0.0.
$PY_EXE -m pip install "pylint<2.6" PyYAML "pytest<6"

PYLINT_RUNNER_ARGS="--yaml-rcfile=.pylintrc.yml"

if test -f .pylintrc-local.yml; then
  PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc-local.yml"
fi

$PY_EXE run-pylint.py $PYLINT_RUNNER_ARGS "$@"
