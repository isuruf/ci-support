#! /bin/bash

set -e

function get_proj_name()
{
  if [ -n "$CI_PROJECT_NAME" ]; then
    echo "$CI_PROJECT_NAME"
  else
    basename "$GITHUB_REPOSITORY"
  fi
}

AK_PROJ_NAME="$(get_proj_name)"

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

    mapfile -t DOCTEST_MODULES < <( git grep -l doctest -- ":(glob,top)$AK_PROJ_NAME/**/*.py" )
    TESTABLES="$TESTABLES ${DOCTEST_MODULES[@]}"
  fi

  if [[ -n "$TESTABLES" ]]; then
    echo "TESTABLES: $TESTABLES"

    # Core dumps? Sure, we'll take them.
    ulimit -c unlimited

    # 10 GiB should be enough for just about anyone
    ulimit -m $(python -c 'print(1024*1024*10)')

    ${PY_EXE} -m pytest \
      --durations=10 \
      --tb=native  \
      --junitxml=pytest.xml \
      --doctest-modules \
      -rxsw \
      $PYTEST_FLAGS $TESTABLES
  fi
fi
