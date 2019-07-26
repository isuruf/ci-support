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

    # Core dumps? Sure, we'll take them.
    ulimit -c unlimited

    # 10 GiB should be enough for just about anyone
    ulimit -m $(python -c 'print(1024*1024*10)')

    # Need to set both _TEST and _CTX because doctests do not use _TEST.
    ${PY_EXE} -m pytest -rw --durations=10 --tb=native  --junitxml=pytest.xml -rxsw $TESTABLES
  fi
fi
