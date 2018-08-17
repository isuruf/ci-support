#! /bin/bash

set -e

if [ "$PY_EXE" == "" ]; then
  PY_EXE=python${py_version}
fi

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project.sh
source build-py-project.sh

TESTABLES=""
if [ -d test ]; then
  cd test

  if ! [ -f .not-actually-ci-tests ]; then
    TESTABLES="$TESTABLES ."
  fi

  if [ -z "$NO_DOCTESTS" ]; then
    RST_FILES=(../doc/*.rst)

    if [ -e "${RST_FILES[0]}" ]; then
      TESTABLES="$TESTABLES ${RST_FILES[*]}"
    fi
  fi

  if ! test -z "$TESTABLES"; then
    echo "TESTABLES: $TESTABLES"
    ulimit -c unlimited

    # PY_EXTRA_FLAGS can be used to pass -m mpi4py.run
    # https://mpi4py.readthedocs.io/en/stable/mpi4py.run.html

    ${PY_EXE} ${PY_EXTRA_FLAGS} -m pytest -rw --durations=10 --tb=native  --junitxml=pytest.xml -rxsw $TESTABLES
  fi
fi
