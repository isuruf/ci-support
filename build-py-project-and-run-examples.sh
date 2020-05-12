#! /bin/bash

set -e

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

if test "$USE_CONDA_BUILD" == "1"; then
  curl -L -O -k "${ci_support}/build-py-project-within-miniconda.sh"
  source build-py-project-within-miniconda.sh
else
  curl -L -O -k "${ci_support}/build-py-project.sh"
  source build-py-project.sh
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/run-examples.sh
source run-examples.sh
