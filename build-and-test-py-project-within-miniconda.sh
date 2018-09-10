#! /bin/bash

set -e
set -x

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project-within-miniconda.sh
source build-py-project-within-miniconda.sh

PY_EXE=python

# Using pip instead of conda here avoids ridiculous uninstall chains
# like these:https://gitlab.tiker.net/inducer/pyopencl/-/jobs/61543
${PY_EXE} -mpip install pytest

conda list

TESTABLES=""
if [ -d test ]; then
  cd test

  if ! [ -f .not-actually-ci-tests ]; then
    TESTABLES="$TESTABLES ."
  fi

  if [ -z "$NO_DOCTESTS" ]; then
    vRST_SHS=(../doc/*.rst)

    if [ -e "${RST_SHS[0]}" ]; then
      TESTABLES="$TESTABLES ${RST_FILES[*]}"
    fi
  fi

  if ! test -z "$TESTABLES"; then
    echo "TESTABLES: $TESTABLES"
    ulimit -c unlimited

    # Need to set both _TEST and _CTX because doctests do not use _TEST.
    ${PY_EXE} -m pytest -rw --durations=10 --tb=native  -rxs $TESTABLES

    # Avoid https://github.com/pytest-dev/pytest/issues/754:
    # add --tb=native

    # Avoid https://github.com/pytest-dev/pytest/issues/785:
    # omit --junitxml=pytest.xml
  fi
fi
