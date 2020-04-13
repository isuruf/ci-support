#! /bin/bash

set -e

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project.sh
source build-py-project.sh

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/run-examples.sh
source run-examples.sh
