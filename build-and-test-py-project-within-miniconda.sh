#! /bin/bash

set -e
set -x

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project-within-miniconda.sh
source build-py-project-within-miniconda.sh

PY_EXE=python

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

  rm -Rf 
  if ! test -z "$TESTABLES"; then
    echo "TESTABLES: $TESTABLES"

    # Core dumps? Sure, we'll take them.
    ulimit -c unlimited

    # 10 GiB should be enough for just about anyone
    ulimit -m $(python -c 'print(1024*1024*10)')

    ${PY_EXE} -m pytest -rw --durations=10 --tb=native  --junitxml=pytest.xml -rxs $PYTEST_FLAGS $TESTABLES

    # Avoid https://github.com/pytest-dev/pytest/issues/754:
    # add --tb=native
  fi
fi
