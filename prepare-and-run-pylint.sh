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

# Version restrictions added 2019-09-25 by AK:
# https://github.com/PyCQA/pylint/issues/3139
# https://gitlab.tiker.net/inducer/pytential/merge_requests/182
# https://gitlab.tiker.net/inducer/leap/pipelines/19503 (?)
$PY_EXE -m pip install "pylint<2.4" "astroid<2.3" PyYAML

PYLINT_RUNNER_ARGS="--yaml-rcfile=.pylintrc.yml"

if test -f .pylintrc-local.yml; then
  PYLINT_RUNNER_ARGS="$PYLINT_RUNNER_ARGS --yaml-rcfile=.pylintrc-local.yml"
fi

$PY_EXE run-pylint.py $PYLINT_RUNNER_ARGS "$@"
