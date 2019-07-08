#! /bin/bash

set -e
set -x

curl -L -O -k https://gitlab.tiker.net/inducer/ci-support/raw/master/build-py-project-within-miniconda.sh
source build-py-project-within-miniconda.sh

PY_EXE=python

# Using pip instead of conda here avoids ridiculous uninstall chains
# like these:https://gitlab.tiker.net/inducer/pyopencl/-/jobs/61543

PYTHON_VER=$($PY_EXE -c 'import sys; print(".".join(str(s) for s in sys.version_info[:2]))')
if [[ "${PY_EXE}" == 2* ]]; then
  ${PY_EXE} -mpip install "pytest<5"
else
  ${PY_EXE} -mpip install pytest
fi

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

  rm -Rf 
  if ! test -z "$TESTABLES"; then
    echo "TESTABLES: $TESTABLES"
    ulimit -c unlimited

    ${PY_EXE} -m pytest -rw --durations=10 --tb=native  -rxs $TESTABLES

    # Avoid https://github.com/pytest-dev/pytest/issues/754:
    # add --tb=native

    # Avoid https://github.com/pytest-dev/pytest/issues/785:
    # omit --junitxml=pytest.xml
  fi
fi
